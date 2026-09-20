#ifndef ACC_H
#define ACC_H

// One 32-bit IEEE-754 single-precision type. The width and the type both
// matter to this lesson. A 32-bit integer addition fits in one clock period of
// 3.33 ns on this part, so an integer accumulator would have a recurrence
// bound of one cycle and every target in the lesson would be met without the
// tool having to choose anything. A floating-point addition is a multi-cycle
// operation here -- measured at eleven states for the DSP-based core the tool
// picks by default -- and the loop-carried dependence turns that latency into
// the floor on the initiation interval.
const int N = 16;

typedef float data_t;

void acc(const data_t x[N], data_t *s);

#endif // ACC_H
