#include "sum8.h"

// Two sums with the same shape, one per type. There is no loop, so there is
// nothing to label; the directive's location is the function itself.
void sum8(int   a0, int   a1, int   a2, int   a3,
          int   a4, int   a5, int   a6, int   a7,
          float f0, float f1, float f2, float f3,
          float f4, float f5, float f6, float f7,
          int *si, float *sf) {
    *si = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
    *sf = f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7;
}