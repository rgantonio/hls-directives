#include "pipe2.h"

// Lesson 6.1 DATAFLOW. Two stages joined by the local array t.
// LOAD_LOOP scales a into t, and STORE_LOOP adds b and writes y.
// This file never changes; only the DATAFLOW directive differs.
void pipe2(const int a[N], const int b[N], int y[N]) {
    int t[N];

LOAD_LOOP:
    for (int i = 0; i < N; i++)
        t[i] = a[i] * SCALE;

STORE_LOOP:
    for (int i = 0; i < N; i++)
        y[i] = t[i] + b[i];
}