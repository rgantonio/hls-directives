#include "fsum8.h"

// One float sum of 8 scalars, the same shape as the integer chain in sum32.
// Whether Vitis is allowed to regroup this expression is the question this
// kernel answers, and the answer differs from the integer case because IEEE
// 754 addition is not associative. See README.md section 1.
void fsum8(float f0, float f1, float f2, float f3,
           float f4, float f5, float f6, float f7,
           float *sf) {
    *sf = f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7;
}
