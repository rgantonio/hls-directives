#ifndef SUM4_H
#define SUM4_H

const int N = 16;      // elements of x
const int G = 4;       // elements of x summed into one element of y
const int M = N / G;   // elements of y, and the trip count of SUM_LOOP
typedef int data_t;

void sum4(const data_t x[N], data_t y[M]);

#endif // SUM4_H