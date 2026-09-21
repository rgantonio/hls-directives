// Lesson 4.3 INLINE testbench.
//
// ref() computes a + b + c directly, with no helper functions, so it cannot
// share a mistake with the kernel's call structure. Every output is preset to
// POISON before each call, so an element the kernel never writes is caught.
// All inputs stay within [-2^28, 2^28 - 1], so no sum overflows, and no
// correct output can equal POISON, since |a + b + c| <= 3 * 2^28 < 0x5A5A5A5A.
//
// Directed vectors come first, then fixed-seed random ones. The program
// returns 1 on any mismatch and 0 otherwise.

#include <cstdio>
#include "calls.h"

static const data_t POISON      = 0x5A5A5A5A;
static const data_t LIM         = 1 << 28;
static const int    RANDOM_SETS = 60;

static void ref(const data_t a[N], const data_t b[N], const data_t c[N],
                data_t y[N]) {
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i] + c[i];
    }
}

// Fixed-seed linear congruential generator, so every run sees the same
// vectors on every platform. Returns a value in [-2^28, 2^28 - 1].
static unsigned lcg_state = 43u;
static data_t rnd() {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    return (data_t)((lcg_state >> 3) % (2u * (unsigned)LIM)) - LIM;
}

static int run_case(const char *name, const data_t a[N], const data_t b[N],
                    const data_t c[N]) {
    data_t y[N], y_ref[N];
    for (int i = 0; i < N; i++) {
        y[i] = POISON;
    }
    ref(a, b, c, y_ref);
    calls(a, b, c, y);

    int errors = 0;
    for (int i = 0; i < N; i++) {
        if (y[i] != y_ref[i]) {
            if (errors < 4) {
                printf("MISMATCH %s i=%d: a=%d b=%d c=%d got %d expected %d%s\n",
                       name, i, a[i], b[i], c[i], y[i], y_ref[i],
                       y[i] == POISON ? " (never written)" : "");
            }
            errors++;
        }
    }
    return errors;
}

int main() {
    data_t a[N], b[N], c[N];
    int errors  = 0;
    int vectors = 0;

    // Directed 1: all zero.
    for (int i = 0; i < N; i++) { a[i] = 0; b[i] = 0; c[i] = 0; }
    errors += run_case("zeros", a, b, c); vectors++;

    // Directed 2: each operand in its own digit group (a in the ones, b in the
    // hundreds, c in the ten-thousands), so a dropped or doubled operand shows
    // up as a wrong digit group in the printed value.
    for (int i = 0; i < N; i++) { a[i] = i; b[i] = 100 * i; c[i] = 10000 * i; }
    errors += run_case("digits", a, b, c); vectors++;

    // Directed 3: a and b cancel, so y must equal c exactly.
    for (int i = 0; i < N; i++) {
        a[i] = 1000 * i + 7; b[i] = -(1000 * i + 7); c[i] = -i;
    }
    errors += run_case("cancel", a, b, c); vectors++;

    // Directed 4: the largest allowed magnitudes, alternating sign.
    for (int i = 0; i < N; i++) {
        data_t v = (i & 1) ? LIM - 1 : -LIM;
        a[i] = v; b[i] = v; c[i] = v;
    }
    errors += run_case("extremes", a, b, c); vectors++;

    // Fixed-seed random vectors.
    for (int s = 0; s < RANDOM_SETS; s++) {
        for (int i = 0; i < N; i++) { a[i] = rnd(); b[i] = rnd(); c[i] = rnd(); }
        errors += run_case("random", a, b, c); vectors++;
    }

    if (errors != 0) {
        printf("TEST FAILED: %d mismatches in %d vectors\n", errors, vectors);
        return 1;
    }
    printf("TEST PASSED: %d vectors of %d elements\n", vectors, N);
    return 0;
}