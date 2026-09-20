#ifndef VADD_H
#define VADD_H

const int N = 16;      // elements of a, b, y and a_buf, and the trip count of both loops
typedef int data_t;

void vadd(const data_t a[N], const data_t b[N], data_t y[N]);

#endif // VADD_H