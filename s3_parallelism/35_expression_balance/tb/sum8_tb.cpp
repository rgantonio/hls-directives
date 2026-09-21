// Lesson 3.5 - EXPRESSION_BALANCE, testbench.
//
// Compares both outputs of sum8 bit for bit against a reference model that
// adds in the same left-to-right order as the kernel source. There is no
// tolerance: a float sum the tool has regrouped into a tree returns different
// bits on the regroup_bait cases and fails here, which is the point.
//
// Order: directed vectors first, then NRAND random vectors from a fixed seed.
// Returns the error count, so any failure makes csim and cosim fail.

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <random>
#include "sum8.h"

static const uint32_t POISON_I = 0xDEADBEEFu;  // never a plausible sum here
static const uint32_t POISON_F = 0x7FC0DEADu;  // a quiet NaN with a payload
static const int      NRAND    = 1000;
static const uint32_t SEED     = 35;

// The adjacent-pair tree result of both bait cases, used only to name what
// went wrong when a bait case fails. See README section 3.
static const float TREE_BAIT = 16777222.0f;

static uint32_t fbits(float f)    { uint32_t u; std::memcpy(&u, &f, 4); return u; }
static float    bitsf(uint32_t u) { float f;    std::memcpy(&f, &u, 4); return f; }

// Reference model. Written out rather than looped so the grouping is visibly
// the same as lines 10 and 11 of src/sum8.cpp. The int sum is formed in
// uint32_t, where wrap-around is defined, although the input ranges below
// never overflow.
static int32_t ref_i(const int a[8]) {
    uint32_t s = (uint32_t)a[0];
    s += (uint32_t)a[1]; s += (uint32_t)a[2]; s += (uint32_t)a[3];
    s += (uint32_t)a[4]; s += (uint32_t)a[5]; s += (uint32_t)a[6];
    s += (uint32_t)a[7];
    int32_t r; std::memcpy(&r, &s, 4); return r;
}

static float ref_f(const float f[8]) {
    return ((((((f[0] + f[1]) + f[2]) + f[3]) + f[4]) + f[5]) + f[6]) + f[7];
}

static int run_case(const char *name, const int a[8], const float f[8]) {
    int   si;
    float sf;
    std::memcpy(&si, &POISON_I, 4);
    sf = bitsf(POISON_F);

    sum8(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7],
         f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], &si, &sf);

    const int32_t ei = ref_i(a);
    const float   ef = ref_f(f);
    int errs = 0;

    if ((uint32_t)si == POISON_I) {
        std::printf("FAIL %-18s si was never written (poison 0x%08X)\n", name, POISON_I);
        errs++;
    } else if ((uint32_t)si != (uint32_t)ei) {
        std::printf("FAIL %-18s si = %d, expected %d\n", name, si, ei);
        errs++;
    }

    if (fbits(sf) == POISON_F) {
        std::printf("FAIL %-18s sf was never written (poison 0x%08X)\n", name, POISON_F);
        errs++;
    } else if (fbits(sf) != fbits(ef)) {
        std::printf("FAIL %-18s sf = 0x%08X (%.9g), expected 0x%08X (%.9g)\n",
                    name, fbits(sf), sf, fbits(ef), ef);
        if (fbits(sf) == fbits(TREE_BAIT))
            std::printf("     %-18s sf equals the adjacent-pair tree: the float sum was reassociated\n", name);
        errs++;
    }
    return errs;
}

int main() {
    int errs = 0;

    // ---- Directed vectors -------------------------------------------------
    const float P24 = 16777216.0f;  // 2^24, where the float spacing is 2

    {   const int   a[8] = {0, 0, 0, 0, 0, 0, 0, 0};
        const float f[8] = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
        errs += run_case("zeros", a, f); }

    {   // A sum of negative zeros is -0.0. A tool that starts the sum from a
        // +0.0 constant would return +0.0 and fail on the sign bit.
        const int   a[8] = {0, 0, 0, 0, 0, 0, 0, 0};
        const float f[8] = {-0.0f, -0.0f, -0.0f, -0.0f, -0.0f, -0.0f, -0.0f, -0.0f};
        errs += run_case("neg_zeros", a, f); }

    {   const int M = (1 << 27) - 1;
        const int   a[8] = {M, M, M, M, M, M, M, M};
        const float f[8] = {1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f};
        errs += run_case("extremes", a, f); }

    {   const int   a[8] = {1, -1, 2, -2, 3, -3, 4, -4};
        const float f[8] = {1.0f, -1.0f, 2.0f, -2.0f, 4.0f, -4.0f, 8.0f, -8.0f};
        errs += run_case("signs", a, f); }

    {   // Chain gives 16777216, the adjacent-pair tree gives 16777222.
        const int   a[8] = {1, 2, 3, 4, 5, 6, 7, 8};
        const float f[8] = {P24, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f};
        errs += run_case("regroup_bait", a, f); }

    {   // Chain gives 16777224, the adjacent-pair tree gives 16777222.
        const int   a[8] = {8, 7, 6, 5, 4, 3, 2, 1};
        const float f[8] = {1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, P24};
        errs += run_case("regroup_bait_rev", a, f); }

    const int directed_errs = errs;

    // ---- Random vectors ---------------------------------------------------
    // Values are built from raw mt19937 words rather than std distributions,
    // whose output the C++ standard does not fix, so every compiler sees the
    // same vectors.
    //   int:   (r & 0x0FFFFFFF) - 2^27, in [-2^27, 2^27), so eight of them
    //          cannot overflow a signed int.
    //   float: random sign, exponent in [-20, 19], random 23-bit mantissa,
    //          so magnitudes lie in [2^-20, 2^20) and no value is subnormal.
    std::mt19937 rng(SEED);
    for (int n = 0; n < NRAND; n++) {
        int a[8];
        float f[8];
        for (int k = 0; k < 8; k++) {
            a[k] = (int)(rng() & 0x0FFFFFFFu) - (1 << 27);
            const uint32_t r    = rng();
            const uint32_t sign = r >> 31;
            const uint32_t exp  = 127u + (rng() % 40u) - 20u;
            const uint32_t man  = r & 0x007FFFFFu;
            f[k] = bitsf((sign << 31) | (exp << 23) | man);
        }
        char name[32];
        std::snprintf(name, sizeof name, "random_%d", n);
        errs += run_case(name, a, f);
    }

    std::printf("directed errors: %d, random errors: %d\n", directed_errs, errs - directed_errs);
    if (errs == 0) std::printf("TEST PASSED\n");
    else           std::printf("TEST FAILED with %d errors\n", errs);
    return errs;
}