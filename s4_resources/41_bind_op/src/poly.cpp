#include "poly.h"

// Lesson 4.1 BIND_OP. The body is the poly kernel of lesson 3.2, unchanged.
// Each multiply is assigned to a named variable, because BIND_OP selects the
// operation it binds through the variable that receives the result.
// LLVM reassociates a * (x * x) into (a * x) * x, so the multiply named sq
// does not survive as written. README section 7 checks what happens to it.
void poly(data_t x, data_t a, data_t b, data_t c, data_t *y) {
    data_t sq   = x * x;        // MUL_SQ
    data_t lin  = b * x;        // MUL_B
    data_t quad = a * sq;       // MUL_A
    *y = quad + lin + c;        // ADD_QL and ADD_C
}