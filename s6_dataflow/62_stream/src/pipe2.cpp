#include "pipe2.h"

// Lesson 6.2 STREAM. Two stages joined by the local array t.
// LOAD_LOOP scales a into t, and STORE_LOOP multiplies t by b into y.
// Against 6.1 only the operator in STORE_LOOP changed (add became multiply),
// so that the consumer is slower than the producer and the channel can fill.
// This file never changes between solutions; only STREAM on t differs.
void pipe2(const int a[N], const int b[N], int y[N]) {
    int t[N];

LOAD_LOOP:
    for (int i = 0; i < N; i++)
        t[i] = a[i] * SCALE;

STORE_LOOP:
    for (int i = 0; i < N; i++)
        y[i] = t[i] * b[i];
}