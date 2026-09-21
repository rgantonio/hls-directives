#include <climits>
#include <cstdint>
#include <cstdio>
#include "poly.h"

// Lesson 4.1 BIND_OP testbench.
//
// BIND_OP cannot change what poly computes, so this testbench is the same kind
// of check as in 3.2: a reference model, a poison value in the output, directed
// vectors first and fixed-seed random vectors after, and a non-zero return on
// any failure.
//
// The directed vectors include operands that straddle the 17-bit split a DSP
// core uses to build a 32-bit product from three 27 by 18 multipliers. C
// simulation does not exercise the core, but the same vectors are what
// co-simulation would need if you enable it in run_hls.tcl.
//
// The kernel multiplies int values, and signed overflow is undefined in C++.
// Both GCC in C simulation and the generated hardware keep the low 32 bits,
// and the reference below computes exactly that with unsigned arithmetic,
// where wrap-around is defined.

static const data_t POISON = (data_t)0xDEADBEEF;

static data_t ref(data_t x, data_t a, data_t b, data_t c) {
    uint32_t ux = (uint32_t)x, ua = (uint32_t)a, ub = (uint32_t)b, uc = (uint32_t)c;
    return (data_t)(ua * ux * ux + ub * ux + uc);
}

// xorshift32 with a fixed seed, so every run sees the same random vectors.
static uint32_t rng_state = 0x2545F491u;
static uint32_t next_rand() {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

static int errors = 0;
static int checks = 0;

static void check(data_t x, data_t a, data_t b, data_t c, const char *group) {
    data_t y = POISON;
    poly(x, a, b, c, &y);
    data_t expect = ref(x, a, b, c);
    checks++;
    if (y != expect) {
        if (errors < 10) {
            printf("MISMATCH %-8s x=%d a=%d b=%d c=%d got=%d (0x%08x) expected=%d%s\n",
                   group, x, a, b, c, y, (uint32_t)y, expect,
                   y == POISON ? "  [output never written]" : "");
        }
        errors++;
    }
}

int main() {
    struct { data_t x, a, b, c; } directed[] = {
        {0, 0, 0, 0},                        // all zero
        {1, 1, 1, 1},                        // 1 + 1 + 1
        {2, 3, 4, 5},                        // 12 + 8 + 5 = 25
        {-1, 1, 1, 1},                       // 1 - 1 + 1
        {-3, 2, -5, 7},                      // 18 + 15 + 7
        {(1 << 17) - 1, 1, 0, 0},            // x fills the low 17 bits exactly
        {(1 << 17), 1, 0, 0},                // x has only the lowest high-part bit
        {46341, 1, 0, 0},                    // x*x just above 2^31, wraps negative
        {65536, 1, 0, 0},                    // x*x = 2^32, wraps to 0
        {INT_MAX, 1, 1, 0},                  // largest positive operand
        {INT_MIN, 1, 1, 0},                  // most negative operand
        {INT_MIN, INT_MIN, INT_MIN, INT_MIN},
        {-1, INT_MAX, INT_MAX, INT_MAX},
    };
    const int n_directed = sizeof(directed) / sizeof(directed[0]);
    for (int i = 0; i < n_directed; i++) {
        check(directed[i].x, directed[i].a, directed[i].b, directed[i].c, "directed");
    }

    // Small operands: no product wraps, so a failure here is easy to read.
    for (int i = 0; i < 500; i++) {
        data_t x = (data_t)(next_rand() % 2001) - 1000;
        data_t a = (data_t)(next_rand() % 2001) - 1000;
        data_t b = (data_t)(next_rand() % 2001) - 1000;
        data_t c = (data_t)(next_rand() % 2001) - 1000;
        check(x, a, b, c, "small");
    }

    // Full-range operands: every partial product of the DSP split is exercised.
    for (int i = 0; i < 2000; i++) {
        check((data_t)next_rand(), (data_t)next_rand(),
              (data_t)next_rand(), (data_t)next_rand(), "full");
    }

    if (errors != 0) {
        printf("TEST FAILED: %d of %d vectors mismatched\n", errors, checks);
        return 1;
    }
    printf("TEST PASSED: %d vectors\n", checks);
    return 0;
}