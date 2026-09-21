#ifndef POLY_H
#define POLY_H

// 32-bit signed data, so every multiply binds to poly_mul_32s_32s_32_*.
typedef int data_t;

void poly(data_t x, data_t a, data_t b, data_t c, data_t *y);

#endif