#include "vadd.h"

// Lesson 5.1 INTERFACE. The same vadd as 1.1 and 3.1. Every element of a
// and b is read exactly once and every element of y is written exactly once,
// in index order, which is what makes ap_fifo legal. Only the port protocol
// of a, b and y changes between solutions; this file never does.
void vadd(const data_t a[N], const data_t b[N], data_t y[N]) {
VADD_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
}