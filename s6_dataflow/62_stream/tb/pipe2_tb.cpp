#include <cstdio>
#include <cstdlib>
#include "pipe2.h"

// Testbench for lesson 6.2. It makes 16 calls so that co-simulation can
// measure both the latency of a call and the interval between calls.
// Inputs stay within +-RANGE, so SCALE * RANGE * RANGE = 3,000,000 never
// overflows a 32-bit int and never equals POISON.

static const int POISON = (int)0xDEADBEEF;
static const int CALLS  = 16;
static const int RANGE  = 1000;

static void ref(const int a[N], const int b[N], int y[N]) {
    for (int i = 0; i < N; i++)
        y[i] = (a[i] * SCALE) * b[i];
}

static int run_call(int call, const int a[N], const int b[N]) {
    int y[N], expect[N];
    for (int i = 0; i < N; i++)
        y[i] = POISON;

    pipe2(a, b, y);
    ref(a, b, expect);

    int errors = 0;
    for (int i = 0; i < N; i++) {
        if (y[i] != expect[i]) {
            if (errors < 4)
                printf("call %2d: y[%2d] = %d, expected %d\n",
                       call, i, y[i], expect[i]);
            errors++;
        }
    }
    return errors;
}

static int rnd() {
    return rand() % (2 * RANGE + 1) - RANGE;
}

int main() {
    int a[N], b[N];
    int errors = 0;
    int call = 0;

    // Directed 1: order-revealing ramps. y[i] = 3 i (i + 1) is different
    // for every i, so any reordering of t shows up as a mismatch.
    for (int i = 0; i < N; i++) { a[i] = i; b[i] = i + 1; }
    errors += run_call(call++, a, b);

    // Directed 2: reversed ramp in a, negative ramp in b.
    for (int i = 0; i < N; i++) { a[i] = N - 1 - i; b[i] = -(i + 1); }
    errors += run_call(call++, a, b);

    // Directed 3: all zeros in a, so every output must be overwritten to 0.
    for (int i = 0; i < N; i++) { a[i] = 0; b[i] = RANGE; }
    errors += run_call(call++, a, b);

    // Directed 4: alternating extremes of the allowed range.
    for (int i = 0; i < N; i++) {
        a[i] = (i % 2) ? RANGE : -RANGE;
        b[i] = (i % 2) ? -RANGE : RANGE;
    }
    errors += run_call(call++, a, b);

    // Random vectors with a fixed seed for the remaining calls.
    srand(2026);
    while (call < CALLS) {
        for (int i = 0; i < N; i++) { a[i] = rnd(); b[i] = rnd(); }
        errors += run_call(call++, a, b);
    }

    if (errors) {
        printf("TEST FAILED: %d mismatches in %d calls\n", errors, CALLS);
        return 1;
    }
    printf("TEST PASSED: %d calls\n", CALLS);
    return 0;
}