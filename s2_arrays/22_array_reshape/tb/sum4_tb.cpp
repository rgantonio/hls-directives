// Testbench for lesson 2.2.
//
// Every case fills y with a poison value, calls sum4, and compares each
// element of y with a reference model. Directed cases come first; the
// "one_hot" case gives every element of x its own bit, so an output that
// took an element from the wrong word or the wrong slice of a word shows a
// wrong bit pattern. Fixed-seed random cases follow. Values stay small
// enough that no sum of four elements overflows.

#include <cstdio>
#include <random>
#include "sum4.h"

static const data_t POISON = 0x0BADF00D;

static void ref(const data_t x[N], data_t y[M]) {
    for (int i = 0; i < M; i++) {
        data_t s = 0;
        for (int j = 0; j < G; j++) s += x[G * i + j];
        y[i] = s;
    }
}

static int run_case(const char *name, const data_t x[N]) {
    data_t y[M], y_ref[M];
    for (int i = 0; i < M; i++) y[i] = POISON;

    sum4(x, y);
    ref(x, y_ref);

    int errors = 0;
    for (int i = 0; i < M; i++) {
        if (y[i] != y_ref[i]) {
            if (errors < 5)
                printf("  %s: y[%d] = 0x%08x, expected 0x%08x\n",
                       name, i, (unsigned)y[i], (unsigned)y_ref[i]);
            errors++;
        }
    }
    printf("%-14s %s (%d errors)\n", name, errors ? "FAIL" : "pass", errors);
    return errors;
}

int main() {
    data_t x[N];
    int errors = 0;

    // Directed: all zeros.
    for (int k = 0; k < N; k++) x[k] = 0;
    errors += run_case("zeros", x);

    // Directed: ramp, so y[i] = 16 * i + 6.
    for (int k = 0; k < N; k++) x[k] = k;
    errors += run_case("ramp", x);

    // Directed: one bit per element, so y[i] = 0xF << (4 * i). A read from
    // the wrong word or the wrong slice sets a wrong bit.
    for (int k = 0; k < N; k++) x[k] = 1 << k;
    errors += run_case("one_hot", x);

    // Directed: one bit per element in reverse order, which exercises the
    // packing with the high bits in the low slices.
    for (int k = 0; k < N; k++) x[k] = 1 << (N - 1 - k);
    errors += run_case("one_hot_rev", x);

    // Directed: negative values of different sizes, so a slice that is cut
    // at the wrong bit boundary loses its sign.
    for (int k = 0; k < N; k++) x[k] = -1000 * (k + 1);
    errors += run_case("negatives", x);

    // Directed: near the positive limit without overflowing the sum.
    for (int k = 0; k < N; k++) x[k] = 0x1FFFFFFF;
    errors += run_case("large", x);

    // Random: fixed seed, 20 vectors.
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(-(1 << 28), 1 << 28);
    for (int t = 0; t < 20; t++) {
        for (int k = 0; k < N; k++) x[k] = dist(rng);
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