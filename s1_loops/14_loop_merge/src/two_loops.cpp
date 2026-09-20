#include "two_loops.h"

// Two independent loops over the same inputs. ADD_LOOP writes only y and
// SUB_LOOP writes only z, so neither loop needs a result of the other.
// Solution merge places LOOP_MERGE on the function, the region that holds
// both loops.
void two_loops(const data_t a[N], const data_t b[N], data_t y[N], data_t z[N]) {
ADD_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a[i] + b[i];
    }
SUB_LOOP:
    for (int i = 0; i < N; i++) {
        z[i] = a[i] - b[i];
    }
}