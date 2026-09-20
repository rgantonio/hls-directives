// Testbench for lesson 3.2.
//
// Every case fills the output with a poison value, calls poly, and compares
// the result with a reference model. Directed cases come first, then
// fixed-seed random cases, and any mismatch makes main return 1.
//
// The directive under test cannot change what the function computes, so this
// testbench is not trying to catch a scheduling bug. It is here to show that
// the kernel is correct once, in the base solution, and to give the lesson the
// same shape as every other lesson in the repository.
//
// The failure mode that the directed cases do aim at is a swapped or dropped
// coefficient, which is the plausible way to mistype a polynomial: "ab_swap"
// gives a and b values that make a*x*x + b*x + c differ from b*x*x + a*x + c,
// and "drop_c" and "drop_b" use coefficients that are zero in one term only,
// so a term that has been lost shows up on its own.
//
// The reference model computes in long long and the test vectors are kept
// small, so that no intermediate value of the kernel can overflow a 32 bit
// signed integer. Overflow of a signed int is undefined behaviour in C++, and
// a testbench that relies on it would be comparing one undefined result with
// another.

#include <cstdio>
#include <cstdlib>
#include <random>
#include "poly.h"

static const data_t POISON = (data_t)0xDEADBEEF;

// Reference model: shares no code with the kernel under test, associates the
// terms differently, and works in a wider type so that an overflow in the
// kernel would show up as a mismatch rather than being reproduced.
static data_t ref_poly(data_t x, data_t a, data_t b, data_t c) {
    long long xx = (long long)x * (long long)x;
    long long r  = (long long)a * xx + (long long)b * (long long)x + (long long)c;
    return (data_t)r;
}

static int run_case(const char *name, data_t x, data_t a, data_t b, data_t c) {
    data_t y = POISON;

    poly(x, a, b, c, &y);
    data_t y_ref = ref_poly(x, a, b, c);

    int errors = 0;
    if (y != y_ref) {
        printf("  %s: y = %d, expected %d%s\n",
               name, (int)y, (int)y_ref,
               (y == POISON) ? " (still poison)" : "");
        errors++;
    }
    printf("%-14s %s  x=%-7d a=%-7d b=%-7d c=%-9d y=%d\n",
           name, errors ? "FAIL" : "pass", (int)x, (int)a, (int)b, (int)c, (int)y);
    return errors;
}

int main() {
    int errors = 0;

    // Directed: everything zero, so the result is zero and a stuck output is
    // indistinguishable from poison only if the poison value were zero, which
    // it is not.
    errors += run_case("zeros",    0,    0,    0,       0);

    // Directed: constant term alone, so both multiplies contribute nothing.
    errors += run_case("const",    7,    0,    0,  123456);

    // Directed: the quadratic term alone, then the linear term alone. A kernel
    // that has lost one of the three terms fails exactly one of these two.
    errors += run_case("drop_b",   5,    3,    0,       1);
    errors += run_case("drop_c",   5,    3,    4,       0);

    // Directed: a and b chosen so that swapping them changes the answer, which
    // catches a polynomial written with its coefficients exchanged.
    errors += run_case("ab_swap",  9,    2,   50,      -7);

    // Directed: a negative sample, which exercises the sign handling of both
    // multiplies, and a case where x*x and b*x have opposite signs.
    errors += run_case("neg_x",  -11,    6,    9,    -250);
    errors += run_case("mixed",  -40,   17,  -23,   99999);

    // Directed: the largest magnitudes this testbench uses, which keep every
    // intermediate value inside a 32 bit signed integer.
    errors += run_case("large",  1000, 1000, 1000, 1000000);

    // Random: fixed seed, 12 vectors. The ranges are chosen so that the worst
    // case, |a * x * x| + |b * x| + |c|, stays below 2^31 - 1.
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist_x(-1000, 1000);
    std::uniform_int_distribution<int> dist_a(-1000, 1000);
    std::uniform_int_distribution<int> dist_b(-100000, 100000);
    std::uniform_int_distribution<int> dist_c(-1000000, 1000000);
    for (int t = 0; t < 12; t++) {
        char name[16];
        snprintf(name, sizeof(name), "random_%02d", t);
        errors += run_case(name, dist_x(rng), dist_a(rng), dist_b(rng), dist_c(rng));
    }

    if (errors) {
        printf("TEST FAILED: %d errors\n", errors);
        return 1;
    }
    printf("TEST PASSED\n");
    return 0;
}