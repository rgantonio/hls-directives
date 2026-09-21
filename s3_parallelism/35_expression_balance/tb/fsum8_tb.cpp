// Lesson 3.5 - EXPRESSION_BALANCE, float testbench.
//
// Compares the output of fsum8 bit for bit against a reference model that adds
// in the same left-to-right order as the kernel source. There is no tolerance:
// a float sum the tool has regrouped into a tree returns different bits on the
// regroup_bait cases and fails here, which is the point.
//
// Order: directed vectors first, then NRAND random vectors from a fixed seed.
// Returns the error count, so any failure makes csim and cosim fail.

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <random>
#include "fsum8.h"

static const uint32_t POISON_F = 0x7FC0DEADu;  // a quiet NaN with a payload
static const int      NRAND    = 1000;
static const uint32_t SEED     = 35;

// The adjacent-pair tree result of both bait cases, used only to name what
// went wrong when a bait case fails. See README section 3.
static const float TREE_BAIT = 16777222.0f;

static uint32_t fbits(float f)    { uint32_t u; std::memcpy(&u, &f, 4); return u; }
static float    bitsf(uint32_t u) { float f;    std::memcpy(&f, &u, 4); return f; }

// Reference model. Written out rather than looped so the grouping is visibly
// the same as line 10 of src/fsum8.cpp.
static float ref_f(const float f[8]) {
    return ((((((f[0] + f[1]) + f[2]) + f[3]) + f[4]) + f[5]) + f[6]) + f[7];
}

static int run_case(const char *name, const float f[8]) {
    float sf = bitsf(POISON_F);

    fsum8(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], &sf);

    const float ef = ref_f(f);
    int errs = 0;

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

    {   const float f[8] = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
        errs += run_case("zeros", f); }

    {   // A sum of negative zeros is -0.0. A tool that starts the sum from a
        // +0.0 constant would return +0.0 and fail on the sign bit.
        const float f[8] = {-0.0f, -0.0f, -0.0f, -0.0f, -0.0f, -0.0f, -0.0f, -0.0f};
        errs += run_case("neg_zeros", f); }

    {   const float f[8] = {1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f};
        errs += run_case("extremes", f); }

    {   const float f[8] = {1.0f, -1.0f, 2.0f, -2.0f, 4.0f, -4.0f, 8.0f, -8.0f};
        errs += run_case("signs", f); }

    {   // Chain gives 16777216, the adjacent-pair tree gives 16777222.
        const float f[8] = {P24, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f};
        errs += run_case("regroup_bait", f); }

    {   // Chain gives 16777224, the adjacent-pair tree gives 16777222.
        const float f[8] = {1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, P24};
        errs += run_case("regroup_bait_rev", f); }

    const int directed_errs = errs;

    // ---- Random vectors ---------------------------------------------------
    // Values are built from raw mt19937 words rather than std distributions,
    // whose output the C++ standard does not fix, so every compiler sees the
    // same vectors.
    //   random sign, exponent in [-20, 19], random 23-bit mantissa, so
    //   magnitudes lie in [2^-20, 2^20) and no value is subnormal.
    std::mt19937 rng(SEED);
    for (int n = 0; n < NRAND; n++) {
        float f[8];
        for (int k = 0; k < 8; k++) {
            const uint32_t r    = rng();
            const uint32_t sign = r >> 31;
            const uint32_t exp  = 127u + (rng() % 40u) - 20u;
            const uint32_t man  = r & 0x007FFFFFu;
            f[k] = bitsf((sign << 31) | (exp << 23) | man);
        }
        char name[32];
        std::snprintf(name, sizeof name, "random_%d", n);
        errs += run_case(name, f);
    }

    std::printf("directed errors: %d, random errors: %d\n", directed_errs, errs - directed_errs);
    if (errs == 0) std::printf("TEST PASSED\n");
    else           std::printf("TEST FAILED with %d errors\n", errs);
    return errs;
}
