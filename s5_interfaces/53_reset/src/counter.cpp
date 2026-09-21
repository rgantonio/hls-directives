#include "counter.h"

// Lesson 5.3 RESET. Two pieces of state survive between calls: a scalar call
// counter and a small table of per-slot counters. Both start from their C
// initial values at power-up in every solution; only the RESET directive
// decides whether ap_rst also returns them there. This file never changes.
cnt_t counter(slot_t slot, cnt_t *hits) {
    static cnt_t cnt     = CNT_INIT;
    static cnt_t hist[H] = {1, 2, 3, 4, 5, 6, 7, 8};

    cnt = cnt + 1;
    cnt_t h = hist[slot] + 1;
    hist[slot] = h;
    *hits = h;
    return cnt;
}