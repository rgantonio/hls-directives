#ifndef POLY_H
#define POLY_H

// 32-bit signed data, as in lesson 3.2. Every multiply in poly is therefore a
// signed 32 by 32 multiply truncated to 32 bits, which Vitis names
// mul_32s_32s_32_<states>_<n>.
typedef int data_t;

void poly(data_t x, data_t a, data_t b, data_t c, data_t *y);

#endif