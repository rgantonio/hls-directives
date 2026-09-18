#ifndef MADD_H
#define MADD_H

const int R = 8;   // rows
const int C = 8;   // columns
typedef int data_t;

void madd(const data_t a[R][C], const data_t b[R][C], data_t y[R][C]);

#endif // MADD_H