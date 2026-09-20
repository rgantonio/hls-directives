#include "acc.h"

// Sum of N floating-point numbers into one running accumulator. The single
// loop carries a real dependence through sum: every iteration needs the total
// the previous iteration produced. Unlike the histogram of lesson 1.5, this
// dependence is not false and no directive removes it, so it sets the floor on
// how fast the loop can run. Measured on this part, that floor is an initiation
// interval of 9, which is the adder's latency plus the cycles the schedule
// spends writing the result back into the accumulator.
//
// sum = 0.0f is not folded away. Adding positive zero to negative zero yields
// positive zero rather than negative zero, so the initialisation is a real
// addition of a real constant and the loop performs sixteen additions rather
// than fifteen. The testbench has a directed case that fails if a tool folds it.
void acc(const data_t x[N], data_t *s) {
    data_t sum = 0.0f;
ACC_LOOP:
    for (int i = 0; i < N; i++) {
        sum += x[i];            // FADD, loop-carried through sum
    }
    *s = sum;
}