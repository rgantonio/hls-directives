#ifndef VADD_H
#define VADD_H

const int N = 16;
typedef int data_t;

void vadd_core(const data_t a[N], const data_t b[N], data_t y[N]);
void vadd(const data_t a[N], const data_t b[N], data_t y[N], data_t k);

#endif // VADD_H