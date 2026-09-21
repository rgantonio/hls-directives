#include <cstdio>
#include <cstdlib>
#include "pipe2.h"

// Lesson 6.1 DATAFLOW testbench.
// One call cannot show two calls overlapping, so the testbench makes CALLS
// consecutive calls. Co-simulation records each call as one transaction and
// reports the interval between them.

const int CALLS  = 16;
const int POISON = (int)0xDEADBEEF;

// Reference model: the same arithmetic without the intermediate array.
static void ref(const int a[N], const int b[N], int y[N]) {
    for (int i = 0; i < N; i++)
        y[i] = a[i] * SCALE + b[i];
}

// Random values stay within +-2^20, so a*SCALE+b never overflows an int.
static int rnd() {
    return (rand() % (1 << 21)) - (1 << 20);
}

int main() {
    int a[N], b[N], y[N], y_ref[N];
    int errors = 0;

    srand(2026);

    for (int c = 0; c < CALLS; c++) {
        for (int i = 0; i < N; i++) {
            switch (c) {
            case 0:  a[i] = 0;              b[i] = 0;           break; // zeros
            case 1:  a[i] = i;              b[i] = 1000 * i;    break; // order-revealing ramp
            case 2:  a[i] = -i;             b[i] = 7;           break; // negative values
            case 3:  a[i] = (1 << 20) - 1;  b[i] = -(1 << 20);  break; // range limits
            default: a[i] = rnd();          b[i] = rnd();       break; // fixed-seed random
            }
            y[i] = POISON; // a poison value that survives reveals a missing write
        }

        pipe2(a, b, y);
        ref(a, b, y_ref);

        for (int i = 0; i < N; i++) {
            if (y[i] != y_ref[i]) {
                if (errors < 10)
                    printf("call %2d, y[%2d] = %d, expected %d\n",
                           c, i, y[i], y_ref[i]);
                errors++;
            }
        }
    }

    if (errors) {
        printf("TEST FAILED: %d mismatches over %d calls\n", errors, CALLS);
        return 1;
    }
    printf("TEST PASSED: %d calls\n", CALLS);
    return 0;
}