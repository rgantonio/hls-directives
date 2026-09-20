#include "poly.h"

// Second order polynomial on a single sample, a*x*x + b*x + c, written with
// the three multiplies visible so that two of them are independent of each
// other and the third depends on one of them. There is no loop in this kernel
// on purpose: the whole function is a handful of cycles long, so a LATENCY
// constraint on it is visible in one small schedule table, and the padding
// that -min adds is not buried inside a loop body that runs many times.
//
// The scalar arguments become ap_none input ports, which are bare buses with
// no handshake, and the pointer argument becomes an ap_vld output port, which
// is a bus plus one valid signal. The block keeps the default ap_ctrl_hs
// protocol, and it is ap_done of that protocol that a minimum latency delays.
//
// One thing to know before reading the schedule report: LLVM reassociates
// a * (x * x) into (a * x) * x, so the tool never builds the x * x named
// MUL_SQ below. The multiplies it schedules are mul_ln17 = a * x, then
// quad = mul_ln17 * x, with lin = b * x free to run beside the second one.
// The depth of the critical path is two multiplies either way, but the pair
// that shares states is not the pair the source suggests.
void poly(data_t x, data_t a, data_t b, data_t c, data_t *y) {
    data_t sq   = x * x;        // MUL_SQ, independent
    data_t lin  = b * x;        // MUL_B,  independent, can run beside MUL_SQ
    data_t quad = a * sq;       // MUL_A,  waits for MUL_SQ
    *y = quad + lin + c;        // ADD_QL and ADD_C
}