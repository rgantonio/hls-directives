#include "vadd.h"

// Element-wise vector addition through a local buffer. COPY_LOOP stores a in
// a_buf, and ADD_LOOP reads a_buf back. Because a_buf is local, its memory is
// built inside the generated design, and BIND_STORAGE chooses what that
// memory is made of. The solutions change nothing else.
void vadd(const data_t a[N], const data_t b[N], data_t y[N]) {
    data_t a_buf[N];
COPY_LOOP:
    for (int i = 0; i < N; i++) {
        a_buf[i] = a[i];
    }
ADD_LOOP:
    for (int i = 0; i < N; i++) {
        y[i] = a_buf[i] + b[i];
    }
}