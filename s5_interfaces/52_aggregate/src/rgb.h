#ifndef RGB_H
#define RGB_H

#include <ap_int.h>

// One RGB565 pixel. The first declared field lands in the least significant
// bits of an aggregated word, so r occupies the low bits, which is the
// opposite of the usual RGB565 convention (see section 9 of the README).
struct pix_t {
    ap_uint<5> r;
    ap_uint<6> g;
    ap_uint<5> b;
};

const int N = 16;

void rgb(const pix_t src[N], pix_t dst[N]);

#endif