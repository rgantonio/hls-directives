#include "vadd.h"

// Element-wise vector addition. The only loop is VADD_LOOP, and it is the
// target of the PIPELINE directive in the ii1 and ii2 solutions.
void vadd(const data_t a[N], const data_t b[N], data_t y[N]) {
VADD_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}