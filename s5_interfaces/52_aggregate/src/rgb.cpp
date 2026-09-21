#include "rgb.h"

// Lesson 5.2 AGGREGATE and DISAGGREGATE. Converts 16 RGB565 pixels to BGR565
// by exchanging the red and blue fields. The loop has no arithmetic, so the
// datapath is wiring and any area difference between solutions comes from the
// ports. Only the struct handling of src and dst changes; this file never does.
void rgb(const pix_t src[N], pix_t dst[N]) {
RGB_LOOP:
    for (int i = 0; i < N; i++) {
        pix_t p = src[i];
        pix_t q;
        q.r = p.b;
        q.g = p.g;
        q.b = p.r;
        dst[i] = q;
    }
}