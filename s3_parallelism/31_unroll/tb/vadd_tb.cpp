// Testbench for lesson 3.1.
//
// Every case fills y with a poison value, calls vadd, and compares each
// element of y with a reference model. Directed cases come first, then
// fixed-seed random cases, and any mismatch makes main return 1.
//
// The solutions unroll VADD_LOOP, so several elements are handled by separate
// hardware in the same cycle, and the failure mode to catch is a lane that
// takes the wrong element. Two directed cases aim at that: "index" gives every
// element a value that encodes its own position, so a lane reading its
// neighbour's element shows up immediately, and "lanes" gives the four
// positions within a group of four clearly different magnitudes, so a lane
// that is served by the wrong memory bank is visible in the result.

#include <cstdio>
#include <random>
#include "vadd.h"

static const data_t POISON = (data_t)0xDEADBEEF;

// Reference model: shares no code with the kernel under test.
static void ref_vadd(const data_t a[N], const data_t b[N], data_t y[N]) {
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}

static int run_case(const char *name, const data_t a[N], const data_t b[N]) {
    data_t y[N], y_ref[N];
    for (int i = 0; i < N; i++) y[i] = POISON;

    vadd(a, b, y);
    ref_vadd(a, b, y_ref);

    int errors = 0;
    for (int i = 0; i < N; i++) {
        if (y[i] != y_ref[i]) {
            if (errors < 5)
                printf("  %s: y[%d] = 0x%08x, expected 0x%08x%s\n",
                       name, i, (unsigned)y[i], (unsigned)y_ref[i],
                       (y[i] == POISON) ? " (still poison)" : "");
            errors++;
        }
    }
    printf("%-14s %s (%d errors)\n", name, errors ? "FAIL" : "pass", errors);
    return errors;
}

int main() {
    data_t a[N], b[N];
    int errors = 0;

    // Directed: all zeros.
    for (int i = 0; i < N; i++) { a[i] = 0; b[i] = 0; }
    errors += run_case("zeros", a, b);

    // Directed: a[i] holds its own index in both halves and b[i] holds the
    // index counted from the end, so every element of y is different and a
    // lane that reads the wrong element gives a wrong index.
    for (int i = 0; i < N; i++) { a[i] = (i << 16) | i; b[i] = N - i; }
    errors += run_case("index", a, b);

    // Directed: the four positions within a group of four get magnitudes that
    // are orders of magnitude apart, so a copy of the body that is wired to
    // the wrong bank of a cyclic partition is obvious in the output.
    for (int i = 0; i < N; i++) {
        static const data_t lane[4] = {1, 1000, 1000000, -1000000};
        a[i] = lane[i % 4];
        b[i] = i;
    }
    errors += run_case("lanes", a, b);

    // Directed: alternating signs and large magnitudes.
    for (int i = 0; i < N; i++) { a[i] = (i % 2) ? 1000000 : -1000000; b[i] = -i; }
    errors += run_case("signs", a, b);

    // Random: fixed seed, 12 vectors. Values stay small enough that no sum
    // overflows.
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(-(1 << 29), 1 << 29);
    for (int t = 0; t < 12; t++) {
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