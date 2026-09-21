#include "sum32.h"

// One integer sum of 32 scalars, written as the chain C's left-to-right
// grouping gives it. There is no loop and no float here: this kernel exists to
// make the chain long enough that balancing it changes the state count.
// See README.md section 3 for why the inputs are scalars and not an array.
void sum32(int a0, int a1, int a2, int a3, int a4, int a5, int a6, int a7,
           int a8, int a9, int a10, int a11, int a12, int a13, int a14,
           int a15, int a16, int a17, int a18, int a19, int a20, int a21,
           int a22, int a23, int a24, int a25, int a26, int a27, int a28,
           int a29, int a30, int a31, int *s) {
    *s = a0  + a1  + a2  + a3  + a4  + a5  + a6  + a7
       + a8  + a9  + a10 + a11 + a12 + a13 + a14 + a15
       + a16 + a17 + a18 + a19 + a20 + a21 + a22 + a23
       + a24 + a25 + a26 + a27 + a28 + a29 + a30 + a31;
}
