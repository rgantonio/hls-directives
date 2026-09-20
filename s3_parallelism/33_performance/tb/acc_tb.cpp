// Testbench for lesson 3.3.
//
// Every case fills the output with a poison value, calls acc, and compares the
// result with a reference model. Directed cases come first, then fixed-seed
// random cases, and any mismatch makes main return 1.
//
// This testbench differs from the other lessons' in one respect that matters.
// PERFORMANCE does not name a transformation, so unlike LATENCY or UNROLL it
// carries no guarantee that the tool will leave the arithmetic alone. The
// transformation that would reach the tightest target in this lesson is
// splitting the accumulation into independent partial sums, and that changes
// the result, because floating-point addition is not associative. So:
//
//   * the comparison is BIT FOR BIT, with no tolerance. A tolerance would hide
//     exactly the regrouping that co-simulation is here to detect.
//   * the reference model sums in the same order, in the same precision,
//     starting from the same 0.0f. It is not a more accurate model; it is the
//     same computation written separately, which is what a bit-exact
//     comparison requires.
//   * one directed case, "regroup_bait", is constructed so that a four-way
//     split gives a different answer from a sequential sum, and one,
//     "neg_zeros", is constructed so that folding the initial 0.0f away gives
//     a different answer.
//
// Note that __RTL_SIMULATION__ is not defined for the testbench during
// co-simulation, so nothing here may depend on it. Co-simulation runs this
// testbench twice per solution, which is why a full run of run_hls.tcl prints
// TEST PASSED twelve times.

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <random>
#include "acc.h"

// A poison value written into the output before every call, so that a kernel
// that never writes its output fails rather than passing on a stale value. The
// bit pattern 0xDEADBEEF is a perfectly ordinary negative float of about
// -6.26e18, not a NaN, which keeps the bit comparison meaningful.
static data_t poison_value() {
    const uint32_t bits = 0xDEADBEEFu;
    data_t v;
    std::memcpy(&v, &bits, sizeof(v));
    return v;
}

// Bit-exact comparison. Comparing with == would treat +0.0 and -0.0 as equal,
// which is precisely the distinction the neg_zeros case is testing, and it
// would treat two NaNs as unequal.
static bool bit_equal(data_t a, data_t b) {
    uint32_t ua, ub;
    std::memcpy(&ua, &a, sizeof(ua));
    std::memcpy(&ub, &b, sizeof(ub));
    return ua == ub;
}

static uint32_t bits_of(data_t a) {
    uint32_t u;
    std::memcpy(&u, &a, sizeof(u));
    return u;
}

// Reference model: shares no code with the kernel, but deliberately performs
// the same additions in the same order in the same precision. Any deviation in
// the order of accumulation shows up as a difference in the low bits.
static data_t ref_acc(const data_t x[N]) {
    data_t sum = 0.0f;
    for (int i = 0; i < N; i++) {
        sum += x[i];
    }
    return sum;
}

static int run_case(const char *name, const data_t x[N]) {
    data_t s = poison_value();

    acc(x, &s);
    data_t s_ref = ref_acc(x);

    int errors = 0;
    if (!bit_equal(s, s_ref)) {
        printf("  %s: s = %.9g (0x%08X), expected %.9g (0x%08X)%s\n",
               name, (double)s, bits_of(s), (double)s_ref, bits_of(s_ref),
               bit_equal(s, poison_value()) ? " (still poison)" : "");
        errors++;
    }
    printf("%-14s %s  s=%.9g (0x%08X)\n",
           name, errors ? "FAIL" : "pass", (double)s, bits_of(s));
    return errors;
}

// Helpers that fill a vector, so that each directed case reads as one line.
static void fill_const(data_t x[N], data_t v) {
    for (int i = 0; i < N; i++) x[i] = v;
}

static void fill_ramp(data_t x[N], data_t first, data_t step) {
    for (int i = 0; i < N; i++) x[i] = first + step * (data_t)i;
}

int main() {
    int errors = 0;
    data_t x[N];

    // Directed: everything zero. The sum is zero, which is not the poison
    // value, so a kernel that never writes its output still fails.
    fill_const(x, 0.0f);
    errors += run_case("zeros", x);

    // Directed: all ones, so the expected sum is exactly 16 and any lost or
    // duplicated iteration is visible as an integer off by one.
    fill_const(x, 1.0f);
    errors += run_case("ones", x);

    // Directed: a ramp, so that the sum depends on every element individually
    // rather than only on how many there are.
    fill_ramp(x, 1.0f, 1.0f);
    errors += run_case("ramp", x);

    // Directed: alternating signs summing to zero, which exercises the sign
    // handling of the adder and catches a kernel that accumulates magnitudes.
    for (int i = 0; i < N; i++) x[i] = (i & 1) ? -3.5f : 3.5f;
    errors += run_case("alternating", x);

    // Directed: negative zeros. A compiler that folded the initial
    // "0.0f + x[0]" into "x[0]" would return -0.0 here, while the sequential
    // computation returns +0.0, and the bit comparison separates the two. This
    // is the case that justifies the claim in README.md section 3 that the
    // loop performs sixteen additions and not fifteen.
    fill_const(x, -0.0f);
    errors += run_case("neg_zeros", x);

    // Directed: one large value followed by fifteen small ones, each of which
    // is below the unit in the last place of the running total and therefore
    // vanishes when added sequentially. Grouped into four partial sums the
    // small values add up first and survive, so a regrouped accumulation
    // returns a visibly different number. This is the case that would catch
    // the tool reassociating the sum in order to meet a performance target.
    x[0] = 1.0e7f;
    for (int i = 1; i < N; i++) x[i] = 0.5f;
    errors += run_case("regroup_bait", x);

    // Directed: the same trap in the opposite order, small values first, where
    // sequential and regrouped accumulation agree. Having both means a
    // mismatch on regroup_bait alone points at the order of accumulation
    // rather than at the adder.
    for (int i = 0; i < N - 1; i++) x[i] = 0.5f;
    x[N - 1] = 1.0e7f;
    errors += run_case("small_first", x);

    // Directed: large magnitudes of both signs, which keeps every partial sum
    // well inside the range of a single-precision float while making the
    // result depend on cancellation.
    for (int i = 0; i < N; i++) x[i] = (i & 1) ? -1.25e6f : 1.5e6f;
    errors += run_case("large_mixed", x);

    // Random: fixed seed, 12 vectors. The exponent is drawn separately from
    // the significand so that the vectors mix magnitudes across several orders
    // of magnitude, which is the condition under which the order of
    // accumulation changes the answer. Exponents are bounded so that no
    // partial sum can overflow or become subnormal.
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> mant(-2.0f, 2.0f);
    std::uniform_int_distribution<int>    expo(-12, 12);
    for (int t = 0; t < 12; t++) {
        for (int i = 0; i < N; i++) {
            x[i] = std::ldexp(mant(rng), expo(rng));
        }
        char name[16];
        snprintf(name, sizeof(name), "random_%02d", t);
        errors += run_case(name, x);
    }

    if (errors) {
        printf("TEST FAILED: %d errors\n", errors);
        return 1;
    }
    printf("TEST PASSED\n");
    return 0;
}