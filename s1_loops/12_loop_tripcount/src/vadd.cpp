#include "vadd.h"

// Element-wise vector addition over the first n elements. The caller must
// keep n between 1 and N_MAX. VADD_LOOP has a bound that is only known at
// run time, and it is the target of LOOP_TRIPCOUNT in the tc solution.
void vadd(const data_t a[N_MAX], const data_t b[N_MAX], data_t y[N_MAX], int n) {
VADD_LOOP:
    for (int i = 0; i < n; i++) {
        y[i] = a[i] + b[i];
    }
}