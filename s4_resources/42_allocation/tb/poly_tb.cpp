#include <cstdio>
#include <cstdint>
#include <random>
#include "poly.h"

// Lesson 4.2 ALLOCATION testbench.
//
// Input ranges are kept small enough that a * x * x + b * x + c fits in a
// 32-bit int, so the C model never relies on signed overflow:
//   |x|, |a|, |b| <= 1000 and |c| <= 1000000 give |y| <= 1002000000.
// POISON is 0x7EADBEEF = 2125315823, outside that range, so a call that
// never writes y can never pass by accident.
//
// The vector {3, 2, 5, -7} has a != b and x != 1. If a shared instance ever
// received b where it should get a, the result would be 44 instead of 26.
// That only matters under co-simulation, which run_hls.tcl leaves off.

static const data_t POISON = 0x7EADBEEF;

static data_t ref(data_t x, data_t a, data_t b, data_t c) {
    int64_t r = (int64_t)a * x * x + (int64_t)b * x + (int64_t)c;
    return (data_t)r;
}

static int check(data_t x, data_t a, data_t b, data_t c, const char *tag) {
    data_t y = POISON;
    poly(x, a, b, c, &y);
    data_t expected = ref(x, a, b, c);
    if (y != expected) {
        printf("FAIL %s: x=%d a=%d b=%d c=%d got %d expected %d%s\n",
               tag, x, a, b, c, y, expected,
               (y == POISON) ? " (y never written)" : "");
        return 1;
    }
    return 0;
}

int main() {
    int errors = 0;

    // Directed vectors first: {x, a, b, c}.
    static const data_t directed[][4] = {
        {    0,     0,     0,        0},   // everything zero
        {    0,     5,     7,        9},   // x = 0 leaves only c
        {    1,     1,     1,        1},   // 1 + 1 + 1
        {   -1,     1,     1,        1},   // 1 - 1 + 1
        {    3,     2,     0,        0},   // quad only: 18
        {    3,     0,     5,        0},   // lin only: 15
        {    3,     0,     0,       -7},   // c only
        {    3,     2,     5,       -7},   // a != b: 26, swapped would be 44
        {   -4,     3,    -2,       11},   // mixed signs
        { 1000,  1000,  1000,  1000000},   // largest positive
        {-1000, -1000, -1000, -1000000},   // largest negative quad
        { 1000, -1000,  1000, -1000000},   // opposite signs at the edge
    };
    const int n_directed = sizeof(directed) / sizeof(directed[0]);

    DIRECTED_LOOP:
    for (int i = 0; i < n_directed; i++) {
        errors += check(directed[i][0], directed[i][1],
                        directed[i][2], directed[i][3], "directed");
    }

    // Fixed-seed random vectors next.
    std::mt19937 rng(4242);
    std::uniform_int_distribution<int> dist_small(-1000, 1000);
    std::uniform_int_distribution<int> dist_c(-1000000, 1000000);
    const int n_random = 1000;

    RANDOM_LOOP:
    for (int i = 0; i < n_random; i++) {
        data_t x = dist_small(rng);
        data_t a = dist_small(rng);
        data_t b = dist_small(rng);
        data_t c = dist_c(rng);
        errors += check(x, a, b, c, "random");
    }

    if (errors != 0) {
        printf("TEST FAILED: %d of %d vectors wrong\n",
               errors, n_directed + n_random);
        return 1;
    }
    printf("TEST PASSED: %d vectors\n", n_directed + n_random);
    return 0;
}