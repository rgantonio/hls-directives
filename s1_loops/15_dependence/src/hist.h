#ifndef HIST_H
#define HIST_H

#include <ap_int.h>

const int N    = 16;    // number of samples, trip count of HIST_LOOP
const int BINS = 16;    // number of histogram bins

typedef ap_uint<4> bin_t;   // 4 bits hold 0 to 15, so every sample names a legal bin
typedef int        cnt_t;   // one count per bin

void hist(const bin_t x[N], cnt_t h[BINS]);

#endif // HIST_H