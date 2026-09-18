#include "madd.h"

// Element-wise addition of two R by C matrices. ROW_LOOP and COL_LOOP form a
// perfect loop nest: all work sits in the inner body and both bounds are
// constants. COL_LOOP carries the LOOP_FLATTEN directive in off and on.
void madd(const data_t a[R][C], const data_t b[R][C], data_t y[R][C]) {
ROW_LOOP:
    for (int i = 0; i < R; i++) {
    COL_LOOP:
        for (int j = 0; j < C; j++) {
            y[i][j] = a[i][j] + b[i][j];
        }
    }
}