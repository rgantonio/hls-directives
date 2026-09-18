// Testbench for lesson 1.2. It follows the shape used across the repository:
//   1. a reference model written independently of the kernel,
//   2. a poison value written into the outputs before the call,
//   3. directed vectors first, then fixed-seed random vectors,
//   4. an error count and a non-zero return value on any failure.
// Because the loop bound is n, the poison value also checks that the kernel
// leaves every element from index n onward untouched.

#include <cstdio>
#include <cstdlib>
#include "vadd.h"

static const data_t POISON = (data_t)0xDEADBEEF;

// Reference model: shares no code with the kernel under test. It writes only
// the first n elements, so the rest of its output keeps the poison value.
static void ref_vadd(const data_t a[N_MAX], const data_t b[N_MAX],
                     data_t y[N_MAX], int n) {
    for (int k = 0; k < n; k++) {
        y[k] = a[k] + b[k];
    }
}

static int check(const char *name, const data_t a[N_MAX],
                 const data_t b[N_MAX], int n) {
    data_t y[N_MAX];
    data_t y_ref[N_MAX];

    // Poison both outputs. An element the kernel forgets to write stays
    // poison in y, and an element it writes beyond n stops being poison.
    for (int i = 0; i < N_MAX; i++) {
        y[i] = POISON;
        y_ref[i] = POISON;
    }

    ref_vadd(a, b, y_ref, n);
    vadd(a, b, y, n);

    int errors = 0;
    for (int i = 0; i < N_MAX; i++) {
        if (y[i] != y_ref[i]) {
            const char *note = "";
            if (y[i] == POISON) {
                note = "  (still poison: element never written)";
            } else if (i >= n) {
                note = "  (written although i >= n)";
            }
            printf("FAIL [%s, n = %2d] y[%2d] = %d, expected %d%s\n",
                   name, n, i, (int)y[i], (int)y_ref[i], note);
            errors++;
        }
    }
    return errors;
}

int main() {
    data_t a[N_MAX];
    data_t b[N_MAX];
    int errors = 0;

    // Directed vector 1: the smallest legal trip count. Only y[0] may change.
    for (int i = 0; i < N_MAX; i++) { a[i] = i; b[i] = 100; }
    errors += check("n min", a, b, 1);

    // Directed vector 2: the largest legal trip count, the only case where
    // every element of y must be written.
    errors += check("n max", a, b, N_MAX);

    // Directed vector 3: a trip count in the middle, with alternating signs
    // and large magnitudes, so both halves of y are checked.
    for (int i = 0; i < N_MAX; i++) { a[i] = (i % 2) ? 1000000 : -1000000; b[i] = -i; }
    errors += check("n mid", a, b, 7);

    // Random vectors with a fixed seed, so every run sees the same stimulus.
    // The trip count is random too, always inside the legal range 1 to N_MAX.
    srand(1234);
    for (int t = 0; t < 8; t++) {
        int n = 1 + rand() % N_MAX;
        for (int i = 0; i < N_MAX; i++) {
            a[i] = (rand() % 2001) - 1000;
            b[i] = (rand() % 2001) - 1000;
        }
        errors += check("random", a, b, n);
    }

    if (errors == 0) {
        printf("PASS: all vectors match the reference model\n");
        return 0;
    }
    printf("FAIL: %d mismatching elements\n", errors);
    return 1;
}