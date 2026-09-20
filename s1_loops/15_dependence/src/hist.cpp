#include "hist.h"

// Histogram of N samples into BINS bins.
//
// The counts are accumulated in the local array acc, not directly in the
// argument h, for two reasons. The memory that holds acc is part of the
// generated design, so co-simulation exercises the real RAM instead of a
// model supplied by the testbench; and a local array can be pinned to a
// particular storage type with BIND_STORAGE, which every solution does.
//
// HIST_LOOP is the loop of this lesson. Iteration i reads acc[x[i]] and
// writes it back. Nothing in the code says whether x[i+1] equals x[i], so
// the tool must assume that consecutive iterations can touch the same
// element. That assumption is what DEPENDENCE overrules.
void hist(const bin_t x[N], cnt_t h[BINS]) {
    cnt_t acc[BINS];

IN_LOOP:
    for (int b = 0; b < BINS; b++) {
        acc[b] = h[b];
    }

HIST_LOOP:
    for (int i = 0; i < N; i++) {
        bin_t b = x[i];
        acc[b] = acc[b] + 1;
    }

OUT_LOOP:
    for (int b = 0; b < BINS; b++) {
        h[b] = acc[b];
    }
}
