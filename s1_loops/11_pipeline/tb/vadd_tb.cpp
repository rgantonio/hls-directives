// Testbench for lesson 1.1. It follows the shape used across the repository:
//   1. a reference model written independently of the kernel,
//   2. a poison value written into the outputs before the call,
//   3. directed vectors first, then fixed-seed random vectors,
//   4. an error count and a non-zero return value on any failure.

#include <cstdio>
#include <cstdlib>
#include "vadd.h"

static const data_t POISON = (data_t)0xDEADBEEF;

// Reference model: shares no code with the kernel under test.
static void ref_vadd(const data_t a[N], const data_t b[N], data_t y[N]) {
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}

static int check(const char *name, const data_t a[N], const data_t b[N]) {
    data_t y[N];
    data_t y_ref[N];

    // Poison the output so that an element the kernel never writes fails
    // the comparison instead of passing on stale data.
    for (int i = 0; i < N; i++) {
        y[i] = POISON;
    }

    ref_vadd(a, b, y_ref);
    vadd(a, b, y);

    int errors = 0;
    for (int i = 0; i < N; i++) {
        if (y[i] != y_ref[i]) {
            printf("FAIL [%s] y[%2d] = %d, expected %d%s\n",
                   name, i, (int)y[i], (int)y_ref[i],
                   (y[i] == POISON) ? "  (still poison: element never written)" : "");
            errors++;
        }
    }
    return errors;
}

int main() {
    data_t a[N];
    data_t b[N];
    int errors = 0;

    // Directed vector 1: everything zero.
    for (int i = 0; i < N; i++) { a[i] = 0; b[i] = 0; }
    errors += check("zeros", a, b);

    // Directed vector 2: a ramp against a constant. Every output differs, so
    // an iteration that writes to the wrong index is caught.
    for (int i = 0; i < N; i++) { a[i] = i; b[i] = 100; }
    errors += check("ramp", a, b);

    // Directed vector 3: alternating signs and large magnitudes.
    for (int i = 0; i < N; i++) { a[i] = (i % 2) ? 1000000 : -1000000; b[i] = -i; }
    errors += check("signs", a, b);

    // Random vectors with a fixed seed, so every run sees the same stimulus.
    srand(1234);
    for (int t = 0; t < 8; t++) {
        for (int i = 0; i < N; i++) {
            a[i] = (rand() % 2001) - 1000;
            b[i] = (rand() % 2001) - 1000;
        }
        errors += check("random", a, b);
    }

    if (errors == 0) {
        printf("PASS: all vectors match the reference model\n");
        return 0;
    }
    printf("FAIL: %d mismatching elements\n", errors);
    return 1;
}