#include "vadd.h"

// Inner function: element-wise vector addition.
void vadd_core(const data_t a[N], const data_t b[N], data_t y[N]) {
CORE_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}

// Outer function: calls the inner one, then adds a scalar offset.
void vadd(const data_t a[N], const data_t b[N], data_t y[N], data_t k) {
    data_t t[N];
    vadd_core(a, b, t);
SCALE_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = t[i] + k;
    }
}