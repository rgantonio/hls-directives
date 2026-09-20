#include "sum4.h"

// Each output is the sum of G = 4 neighbouring inputs. Every iteration reads
// four elements of x, which is more than the two ports of one memory can
// deliver in one cycle. The solutions reshape x and change nothing else.
void sum4(const data_t x[N], data_t y[M]) {
SUM_LOOP:
    for (int i = 0; i < M; i++) {
        y[i] = x[G * i] + x[G * i + 1] + x[G * i + 2] + x[G * i + 3];
    }
}