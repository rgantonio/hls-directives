// Testbench for lesson 1.4.
//
// Every case fills both outputs with a poison value, calls two_loops, and
// compares each element of y and z with a reference model that keeps the two
// loops in their original order. Directed cases come first; the "unique"
// cases give every element a distinct value, so an index mix-up between the
// merged bodies would show as a mismatch. Fixed-seed random cases follow.
// Values stay small enough that no addition or subtraction overflows.

#include <cstdio>
#include <random>
#include "two_loops.h"

static const data_t POISON = 0x0BADF00D;

static void ref(const data_t a[N], const data_t b[N], data_t y[N], data_t z[N]) {
    for (int i = 0; i < N; i++) y[i] = a[i] + b[i];
    for (int i = 0; i < N; i++) z[i] = a[i] - b[i];
}

static int check(const char *case_name, const char *out_name,
                 const data_t got[N], const data_t exp[N], int shown) {
    int errors = 0;
    for (int i = 0; i < N; i++) {
        if (got[i] != exp[i]) {
            if (shown + errors < 5)
                printf("  %s: %s[%d] = %d, expected %d\n",
                       case_name, out_name, i, got[i], exp[i]);
            errors++;
        }
    }
    return errors;
}

static int run_case(const char *name, const data_t a[N], const data_t b[N]) {
    data_t y[N], z[N], y_ref[N], z_ref[N];
    for (int i = 0; i < N; i++) { y[i] = POISON; z[i] = POISON; }

    two_loops(a, b, y, z);
    ref(a, b, y_ref, z_ref);

    int errors = check(name, "y", y, y_ref, 0);
    errors += check(name, "z", z, z_ref, errors);
    printf("%-14s %s (%d errors)\n", name, errors ? "FAIL" : "pass", errors);
    return errors;
}

int main() {
    data_t a[N], b[N];
    int errors = 0;

    // Directed: all zeros.
    for (int i = 0; i < N; i++) { a[i] = 0; b[i] = 0; }
    errors += run_case("zeros", a, b);

    // Directed: ramp in a, zero in b, so y and z equal the index.
    for (int i = 0; i < N; i++) { a[i] = i; b[i] = 0; }
    errors += run_case("ramp_a", a, b);

    // Directed: zero in a, ramp in b, so y and z differ in sign.
    for (int i = 0; i < N; i++) { a[i] = 0; b[i] = i; }
    errors += run_case("ramp_b", a, b);

    // Directed: every sum and every difference is distinct.
    for (int i = 0; i < N; i++) { a[i] = 1000 * i; b[i] = i + 1; }
    errors += run_case("unique", a, b);

    // Directed: negative values and a large positive offset.
    for (int i = 0; i < N; i++) { a[i] = -i; b[i] = 1 << 20; }
    errors += run_case("negatives", a, b);

    // Directed: near the positive limit without overflowing either output.
    for (int i = 0; i < N; i++) { a[i] = 0x3FFFFFFF; b[i] = (i % 2) ? 0x3FFFFFFF : -0x3FFFFFFF; }
    errors += run_case("large", a, b);

    // Random: fixed seed, 20 vector pairs.
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(-(1 << 29), 1 << 29);
    for (int t = 0; t < 20; t++) {
        for (int i = 0; i < N; i++) { a[i] = dist(rng); b[i] = dist(rng); }
        char name[16];
        snprintf(name, sizeof(name), "random_%02d", t);
        errors += run_case(name, a, b);
    }

    if (errors) {
        printf("TEST FAILED: %d errors\n", errors);
        return 1;
    }
    printf("TEST PASSED\n");
    return 0;
}