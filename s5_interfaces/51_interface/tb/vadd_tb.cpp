// Lesson 5.1 INTERFACE testbench.
//
// 16 calls: 4 directed vector sets, then 12 fixed-seed random ones. Every
// call starts with y filled with POISON, so an element the design never
// writes is caught even in solutions where y passes through an adapter.
// The ramp vector puts a distinct value in every element, which catches a
// FIFO or a burst that delivers words in the wrong order.
//
// Co-simulation runs this program twice per solution, so expect two
// TEST PASSED lines per cosim.

#include <cstdio>
#include <climits>
#include <stdint.h>
#include "vadd.h"

static const data_t POISON = (data_t)0x5EADBEEF;
static const int DIRECTED = 4;
static const int RANDOM   = 12;
static const int CALLS    = DIRECTED + RANDOM;

static void ref(const data_t a[N], const data_t b[N], data_t y[N]) {
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}

// Fixed-seed linear congruential generator, identical on every platform.
static uint32_t lcg_state = 12345u;
static data_t next_rand() {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    // Range [-2^29, 2^29), so a + b can never overflow a 32-bit int.
    return (data_t)(lcg_state >> 2) - (1 << 29);
}

static void fill_directed(int k, data_t a[N], data_t b[N]) {
    for (int i = 0; i < N; i++) {
        switch (k) {
        case 0:  a[i] = 0;         b[i] = 0;              break; // all zero
        case 1:  a[i] = i;         b[i] = 100 * i;        break; // ramp, order check
        case 2:  a[i] = i + 1;     b[i] = -(i + 1);       break; // cancels to zero
        default: // extremes without overflow: even i gives INT_MAX - 1, odd i gives INT_MIN
            a[i] = (i % 2) ? INT_MIN / 2 : INT_MAX / 2;
            b[i] = (i % 2) ? INT_MIN / 2 : INT_MAX / 2;
            break;
        }
    }
}

int main() {
    data_t a[N], b[N], y[N], y_ref[N];
    int errors = 0;

    for (int call = 0; call < CALLS; call++) {
        if (call < DIRECTED) {
            fill_directed(call, a, b);
        } else {
            for (int i = 0; i < N; i++) {
                a[i] = next_rand();
                b[i] = next_rand();
            }
        }
        for (int i = 0; i < N; i++) {
            y[i] = POISON;
        }

        ref(a, b, y_ref);
        vadd(a, b, y);

        for (int i = 0; i < N; i++) {
            if (y[i] != y_ref[i]) {
                if (errors < 10) {
                    printf("MISMATCH call %d element %d: got %d, expected %d%s\n",
                           call, i, (int)y[i], (int)y_ref[i],
                           y[i] == POISON ? " (never written)" : "");
                }
                errors++;
            }
        }
    }

    if (errors) {
        printf("TEST FAILED: %d mismatches\n", errors);
        return 1;
    }
    printf("TEST PASSED: %d calls, %d elements\n", CALLS, CALLS * N);
    return 0;
}