// Lesson 3.5 - EXPRESSION_BALANCE, integer testbench.
//
// Checks sum32 against a reference model that adds in the same left-to-right
// order as the kernel source. Unlike the float testbench, this one cannot
// detect reassociation: two's-complement addition is associative even when it
// wraps, so every grouping of the same 32 operands returns the same bits. That
// is exactly why the tool is free to balance this expression, and why the only
// evidence of balancing is in the schedule and the RTL, not in the results.
//
// What this testbench is still for: proving that the balanced tree computes
// the sum, that the output is written at all, and that nothing the directive
// does breaks the function.
//
// Order: directed vectors first, then NRAND random vectors from a fixed seed.
// Returns the error count, so any failure makes csim and cosim fail.

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <random>
#include "sum32.h"

static const uint32_t POISON_I = 0xDEADBEEFu;  // never a plausible sum here
static const int      NRAND    = 1000;
static const uint32_t SEED     = 32;
static const int      N        = 32;

// Reference model. Accumulated in uint32_t, where wrap-around is defined,
// although the input ranges below never overflow.
static int32_t ref_i(const int a[N]) {
    uint32_t s = 0;
    for (int k = 0; k < N; k++) s += (uint32_t)a[k];
    int32_t r; std::memcpy(&r, &s, 4); return r;
}

static int run_case(const char *name, const int a[N]) {
    int si;
    std::memcpy(&si, &POISON_I, 4);

    sum32(a[0],  a[1],  a[2],  a[3],  a[4],  a[5],  a[6],  a[7],
          a[8],  a[9],  a[10], a[11], a[12], a[13], a[14], a[15],
          a[16], a[17], a[18], a[19], a[20], a[21], a[22], a[23],
          a[24], a[25], a[26], a[27], a[28], a[29], a[30], a[31], &si);

    const int32_t ei = ref_i(a);
    int errs = 0;

    if ((uint32_t)si == POISON_I) {
        std::printf("FAIL %-18s s was never written (poison 0x%08X)\n", name, POISON_I);
        errs++;
    } else if ((uint32_t)si != (uint32_t)ei) {
        std::printf("FAIL %-18s s = %d, expected %d\n", name, si, ei);
        errs++;
    }
    return errs;
}

int main() {
    int errs = 0;

    // ---- Directed vectors -------------------------------------------------
    {   int a[N] = {0};
        errs += run_case("zeros", a); }

    {   // Largest magnitude the random range below can produce, in every slot.
        const int M = (1 << 25) - 1;
        int a[N];
        for (int k = 0; k < N; k++) a[k] = M;
        errs += run_case("max_pos", a); }

    {   const int M = -(1 << 25);
        int a[N];
        for (int k = 0; k < N; k++) a[k] = M;
        errs += run_case("max_neg", a); }

    {   // Alternating signs sum to zero, and do so at every grouping.
        int a[N];
        for (int k = 0; k < N; k++) a[k] = (k % 2 == 0) ? (k + 1) : -(k);
        errs += run_case("signs", a); }

    {   int a[N];
        for (int k = 0; k < N; k++) a[k] = k + 1;          // 1 .. 32, sum 528
        errs += run_case("ascending", a); }

    {   int a[N];
        for (int k = 0; k < N; k++) a[k] = N - k;          // 32 .. 1, sum 528
        errs += run_case("descending", a); }

    const int directed_errs = errs;

    // ---- Random vectors ---------------------------------------------------
    // Values are built from raw mt19937 words rather than std distributions,
    // whose output the C++ standard does not fix, so every compiler sees the
    // same vectors.
    //   (r & 0x03FFFFFF) - 2^25, in [-2^25, 2^25), so 32 of them sum to at
    //   most 2^30 in magnitude and cannot overflow a signed int, whose
    //   overflow is undefined behavior in C.
    std::mt19937 rng(SEED);
    for (int n = 0; n < NRAND; n++) {
        int a[N];
        for (int k = 0; k < N; k++)
            a[k] = (int)(rng() & 0x03FFFFFFu) - (1 << 25);
        char name[32];
        std::snprintf(name, sizeof name, "random_%d", n);
        errs += run_case(name, a);
    }

    std::printf("directed errors: %d, random errors: %d\n", directed_errs, errs - directed_errs);
    if (errs == 0) std::printf("TEST PASSED\n");
    else           std::printf("TEST FAILED with %d errors\n", errs);
    return errs;
}
