// Testbench for lesson 5.2. Five directed vectors, then eleven fixed-seed
// random ones, 16 calls in total. Each directed vector exercises one field on
// its own, so a swap, a lost field or a shifted field fails on a specific
// channel. Returns non-zero on any mismatch.
#include <cstdio>
#include "rgb.h"

static const int NCALLS    = 16;
static const int NDIRECTED = 5;

// Written into dst before every call; an element the kernel fails to write
// keeps this value. No directed vector produces it.
static const unsigned POISON_R = 21, POISON_G = 42, POISON_B = 10;

// Reference model on plain integers, independent of pix_t assignment.
static void ref(const unsigned sr[N], const unsigned sg[N], const unsigned sb[N],
                unsigned dr[N], unsigned dg[N], unsigned db[N]) {
    for (int i = 0; i < N; i++) {
        dr[i] = sb[i];
        dg[i] = sg[i];
        db[i] = sr[i];
    }
}

// Small linear congruential generator so the random vectors are the same on
// every host and in every cosim run.
static unsigned lcg_state = 52u;
static unsigned lcg() {
    lcg_state = lcg_state * 1103515245u + 12345u;
    return (lcg_state >> 8) & 0xFFFFu;
}

static void make_vector(int call, unsigned r[N], unsigned g[N], unsigned b[N]) {
    for (int i = 0; i < N; i++) {
        switch (call) {
        case 0:  r[i] = 0;      g[i] = 0;         b[i] = 0;      break; // all zero
        case 1:  r[i] = 31;     g[i] = 63;        b[i] = 31;     break; // all ones
        case 2:  r[i] = i;      g[i] = 0;         b[i] = 0;      break; // red only
        case 3:  r[i] = 0;      g[i] = 4 * i + 3; b[i] = 0;      break; // green only
        case 4:  r[i] = 0;      g[i] = 0;         b[i] = 31 - i; break; // blue only
        default: r[i] = lcg() & 31; g[i] = lcg() & 63; b[i] = lcg() & 31; break;
        }
    }
}

int main() {
    int errors = 0;

    for (int call = 0; call < NCALLS; call++) {
        unsigned sr[N], sg[N], sb[N], er[N], eg[N], eb[N];
        make_vector(call, sr, sg, sb);
        ref(sr, sg, sb, er, eg, eb);

        pix_t src[N], dst[N];
        for (int i = 0; i < N; i++) {
            src[i].r = sr[i]; src[i].g = sg[i]; src[i].b = sb[i];
            dst[i].r = POISON_R; dst[i].g = POISON_G; dst[i].b = POISON_B;
        }

        rgb(src, dst);

        for (int i = 0; i < N; i++) {
            unsigned r = dst[i].r, g = dst[i].g, b = dst[i].b;
            if (r != er[i] || g != eg[i] || b != eb[i]) {
                if (errors < 10) {
                    printf("call %2d (%s) i=%2d: got r=%2u g=%2u b=%2u, expected r=%2u g=%2u b=%2u\n",
                           call, call < NDIRECTED ? "directed" : "random", i,
                           r, g, b, er[i], eg[i], eb[i]);
                }
                errors++;
            }
        }
    }

    if (errors) {
        printf("TEST FAILED: %d mismatches\n", errors);
        return 1;
    }
    printf("TEST PASSED\n");
    return 0;
}