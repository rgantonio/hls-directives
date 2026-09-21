#include <cstdio>
#include <cstdlib>
#include "counter.h"

// Lesson 5.3 testbench. The kernel keeps state between calls, so the
// reference model keeps its own copy of the same state and every call is
// checked against it. A C testbench cannot assert ap_rst, so this file checks
// that the state persists and wraps correctly; sim_reset.sh checks the reset.

static int ref_cnt     = CNT_INIT;
static int ref_hist[H] = {1, 2, 3, 4, 5, 6, 7, 8};

static void ref(int slot, int *total, int *hits) {
    ref_cnt        = (ref_cnt + 1) & 0xFF;
    ref_hist[slot] = (ref_hist[slot] + 1) & 0xFF;
    *total = ref_cnt;
    *hits  = ref_hist[slot];
}

// 8 bits leave no value that can never occur, so a missed write of hits can
// hide only on a call whose expected value is exactly 0xEE.
const int POISON   = 0xEE;
const int N_RANDOM = 300;   // enough calls to wrap cnt past 255

static int errors = 0;
static int calls  = 0;

static void check(int slot) {
    cnt_t hits  = POISON;
    cnt_t total = counter(slot, &hits);
    int exp_total, exp_hits;
    ref(slot, &exp_total, &exp_hits);
    if (total.to_int() != exp_total || hits.to_int() != exp_hits) {
        if (errors < 10) {
            printf("call %d slot %d: total %d (expected %d), hits %d (expected %d)\n",
                   calls, slot, total.to_int(), exp_total, hits.to_int(), exp_hits);
        }
        errors++;
    }
    calls++;
}

int main() {
    // Directed: three calls on slot 0, then one call on every slot in order.
    for (int k = 0; k < 3; k++) check(0);
    for (int s = 0; s < H; s++) check(s);

    // Fixed-seed random slots.
    srand(53);
    for (int k = 0; k < N_RANDOM; k++) check(rand() % H);

    if (errors) {
        printf("TEST FAILED: %d of %d calls wrong\n", errors, calls);
        return 1;
    }
    printf("TEST PASSED: %d calls\n", calls);
    return 0;
}