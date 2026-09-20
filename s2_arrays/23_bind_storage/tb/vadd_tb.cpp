// Testbench for lesson 2.3.
//
// Every case fills y with a poison value, calls vadd, and compares each
// element of y with a reference model. Directed cases come first, then
// fixed-seed random cases, and any mismatch makes main return 1.
//
// The kernel stores a in the local memory a_buf and reads it back, and the
// solutions change only when that read data arrives. Two directed cases aim
// at that: "index" gives every element of a a value that encodes its own
// index, so a read that returns the neighbouring word shows up at once, and
// "stale" follows it with different data, so a read that returns what the
// previous call left in a_buf fails.

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

    // Directed: a[i] holds its own index in both halves, so y[i] = 0x10001 * i
    // and a read of the wrong word of a_buf gives the wrong index.
    for (int i = 0; i < N; i++) { a[i] = (i << 16) | i; b[i] = 0; }
    errors += run_case("index", a, b);

    // Directed: the bitwise inverse of the previous a, straight after it, so a
    // value left over in a_buf from that call gives a wrong result.
    for (int i = 0; i < N; i++) { a[i] = ~((i << 16) | i); b[i] = 1; }
    errors += run_case("stale", a, b);

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