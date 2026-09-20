#ifndef POLY_H
#define POLY_H

// Lesson 3.2 - LATENCY
//
// One 32 bit signed integer type for the sample, the three coefficients and
// the result. The width matters to this lesson only through the multiply: a
// 32 by 32 bit multiply does not fit in one clock period of 3.33 ns on this
// part, so it occupies S states. The critical path is two dependent multiplies
// plus one state for the additions and the port write, so the design needs
// 2S + 1 states and reports a latency of 2S. Measured on this part, S = 2, so
// 5 states and a latency of 4 cycles.

typedef int data_t;

void poly(data_t x, data_t a, data_t b, data_t c, data_t *y);

#endif // POLY_H