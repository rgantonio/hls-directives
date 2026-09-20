// Testbench for lesson 1.5.
//
// Usage: hist_tb unique | repeat   (no argument runs both sets)
//
// h is both an input and an output of hist, so it cannot simply be filled with
// a poison value and overwritten. Instead every bin starts at POISON + b. The
// kernel only adds to the bins it names, so an untouched bin must still hold
// its poison value, and a bin that the hardware overwrites with garbage or
// zero shows up immediately. Counts are printed relative to the start value.
//
// "unique" cases name every bin exactly once per call: directed permutations
// first, then fixed-seed random permutations. These inputs never trigger the
// dependence, so they pass even when the dependence was wrongly declared false.
//
// "repeat" cases name the same bin more than once: all samples equal, two bins
// alternating, then fixed-seed random draws that may repeat anywhere.

#include <cstdio>
#include <cstring>
#include "hist.h"

static const cnt_t POISON = 0x5A5A0000;

// Reference model: the obvious sequential histogram.
static void ref(const bin_t x[N], cnt_t h[BINS]) {
    for (int i = 0; i < N; i++) {
        h[x[i]] += 1;
    }
}

// Small linear congruential generator, so the vectors are identical on every
// machine and in both C simulation and co-simulation.
static unsigned lcg_state;
static unsigned lcg() {
    lcg_state = lcg_state * 1103515245u + 12345u;
    return (lcg_state >> 16) & 0x7fffu;
}

static int run_case(const char *name, const bin_t x[N]) {
    cnt_t h_dut[BINS], h_ref[BINS];
    for (int b = 0; b < BINS; b++) {
        h_dut[b] = POISON + b;
        h_ref[b] = POISON + b;
    }

    ref(x, h_ref);
    hist(x, h_dut);

    int errors = 0;
    for (int b = 0; b < BINS; b++) {
        if (h_dut[b] != h_ref[b]) {
            if (errors < 4) {
                printf("  %-14s bin %2d: got %d, expected %d\n", name, b,
                       (int)(h_dut[b] - (POISON + b)),
                       (int)(h_ref[b] - (POISON + b)));
            }
            errors++;
        }
    }
    printf("%-16s %s\n", name, errors ? "FAIL" : "pass");
    return errors ? 1 : 0;
}

static int run_unique() {
    bin_t x[N];
    int failed = 0;

    for (int i = 0; i < N; i++) x[i] = i;               // 0, 1, ..., 15
    failed += run_case("unique_up", x);

    for (int i = 0; i < N; i++) x[i] = N - 1 - i;       // 15, 14, ..., 0
    failed += run_case("unique_down", x);

    lcg_state = 1u;
    for (int t = 0; t < 8; t++) {                       // Fisher-Yates shuffles
        for (int i = 0; i < N; i++) x[i] = i;
        for (int i = N - 1; i > 0; i--) {
            int j = lcg() % (i + 1);
            bin_t tmp = x[i]; x[i] = x[j]; x[j] = tmp;
        }
        char name[32];
        snprintf(name, sizeof name, "unique_rand%d", t);
        failed += run_case(name, x);
    }
    return failed;
}

static int run_repeat() {
    bin_t x[N];
    int failed = 0;

    for (int i = 0; i < N; i++) x[i] = 5;               // 5, 5, 5, ...
    failed += run_case("repeat_same", x);

    for (int i = 0; i < N; i++) x[i] = (i % 2) ? 7 : 3; // 3, 7, 3, 7, ...
    failed += run_case("repeat_alt", x);

    lcg_state = 2u;
    for (int t = 0; t < 8; t++) {                       // random, repeats allowed
        for (int i = 0; i < N; i++) x[i] = lcg() % BINS;
        char name[32];
        snprintf(name, sizeof name, "repeat_rand%d", t);
        failed += run_case(name, x);
    }
    return failed;
}

int main(int argc, char **argv) {
    const char *mode = (argc > 1) ? argv[1] : "both";
    int failed = 0;

    if (!strcmp(mode, "unique") || !strcmp(mode, "both")) failed += run_unique();
    if (!strcmp(mode, "repeat") || !strcmp(mode, "both")) failed += run_repeat();

    if (failed) {
        printf("hist_tb %s: %d case(s) FAILED\n", mode, failed);
        return 1;
    }
    printf("hist_tb %s: all cases passed\n", mode);
    return 0;
}