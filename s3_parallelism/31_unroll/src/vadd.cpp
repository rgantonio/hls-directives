#include "vadd.h"

// Element-wise vector addition. VADD_LOOP is the only loop and the target of
// the UNROLL directive. The iterations are independent, so nothing but the
// number of memory accesses available per cycle limits how many of them can
// run at the same time. The solutions change nothing else.
void vadd(const data_t a[N], const data_t b[N], data_t y[N]) {
VADD_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}