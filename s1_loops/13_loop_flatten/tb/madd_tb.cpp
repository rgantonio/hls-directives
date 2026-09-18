// Testbench for lesson 1.3.
//
// Every case fills the output with a poison value, calls madd, and compares
// each element with a reference model. Directed cases come first; the
// "unique" cases give every element a distinct value, so a row and column
// mix-up in the loop control would show as a mismatch. Fixed-seed random
// cases follow. Values stay small enough that no addition overflows.

#include <cstdio>
#include <random>
#include "madd.h"

static const data_t POISON = 0x0BADF00D;

static void ref(const data_t a[R][C], const data_t b[R][C], data_t y[R][C]) {
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++)
            y[i][j] = a[i][j] + b[i][j];
}

static int run_case(const char *name, const data_t a[R][C], const data_t b[R][C]) {
    data_t y[R][C], y_ref[R][C];
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++)
            y[i][j] = POISON;

    madd(a, b, y);
    ref(a, b, y_ref);

    int errors = 0;
    for (int i = 0; i < R; i++) {
        for (int j = 0; j < C; j++) {
            if (y[i][j] != y_ref[i][j]) {
                if (errors < 5)
                    printf("  %s: y[%d][%d] = %d, expected %d\n",
                           name, i, j, y[i][j], y_ref[i][j]);
                errors++;
            }
        }
    }
    printf("%-14s %s (%d errors)\n", name, errors ? "FAIL" : "pass", errors);
    return errors;
}

int main() {
    data_t a[R][C], b[R][C];
    int errors = 0;

    // Directed: all zeros.
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) { a[i][j] = 0; b[i][j] = 0; }
    errors += run_case("zeros", a, b);

    // Directed: unique flat index in a, zero in b.
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) { a[i][j] = i * C + j; b[i][j] = 0; }
    errors += run_case("unique_a", a, b);

    // Directed: row in a, column scaled in b, so every sum is distinct.
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) { a[i][j] = i; b[i][j] = 1000 * j; }
    errors += run_case("unique_rowcol", a, b);

    // Directed: negative values and a large positive offset.
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) { a[i][j] = -(i * C + j); b[i][j] = 1 << 20; }
    errors += run_case("negatives", a, b);

    // Directed: near the positive limit without overflowing.
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) { a[i][j] = 0x3FFFFFFF; b[i][j] = 0x3FFFFFFF; }
    errors += run_case("large", a, b);

    // Random: fixed seed, 20 matrices.
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(-(1 << 29), 1 << 29);
    for (int t = 0; t < 20; t++) {
        for (int i = 0; i < R; i++)
            for (int j = 0; j < C; j++) { a[i][j] = dist(rng); b[i][j] = dist(rng); }
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