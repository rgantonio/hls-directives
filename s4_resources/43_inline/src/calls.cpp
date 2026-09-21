#include "calls.h"

// Lesson 4.3 INLINE. Two one-line helpers, each called once per iteration.
// sum2 adds a and b, and bias adds c to that sum. Written out, the loop body
// is y[i] = a[i] + b[i] + c[i]; the function boundaries are the only thing
// that separates the two additions. Do not merge the helpers into one: two
// adds split across two functions are what inlining has to put back together.
//
// INLINE decides whether those boundaries survive into the RTL, never what
// is computed, so this file is identical in every solution.
static data_t sum2(data_t p, data_t q) { return p + q; }    // line 11
static data_t bias(data_t s, data_t k) { return s + k; }    // line 12

void calls(const data_t a[N], const data_t b[N], const data_t c[N],
           data_t y[N]) {
CALLS_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = bias(sum2(a[i], b[i]), c[i]);
    }
}