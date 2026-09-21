#include "poly.h"

// Lesson 4.2 ALLOCATION. The body is the poly kernel of lessons 3.2 and 4.1,
// unchanged, and it must stay that way: the three multiplies are what the
// allocation limit has to share.
//
// LLVM reassociates a * (x * x) into (a * x) * x, so the multiply named sq
// does not survive as written. The three multiplies the scheduler sees are
// mul_ln24 = x * a, then quad = mul_ln24 * x, with lin = b * x free to run
// beside quad. Only quad depends on another multiply.
//
// Do not rewrite this as quad = a * x * x. That form lets LLVM factor x out
// of a*x*x + b*x and emit Horner's rule, ((a*x + b)*x) + c, which is two
// chained multiplies instead of three. They can never overlap, so the tool
// shares one instance on its own and the allocation limit has nothing left
// to do.
//
// ALLOCATION changes how many multiplier cores exist, never what is
// computed, so this file is identical in every solution.

void poly(data_t x, data_t a, data_t b, data_t c, data_t *y) {
    data_t sq   = x * x;        // MUL_SQ, reassociated away
    data_t lin  = b * x;        // MUL_B,  independent
    data_t quad = a * sq;       // MUL_A,  waits for the reassociated a * x
    *y = quad + lin + c;        // ADD_QL and ADD_C, fused into one adder
}
