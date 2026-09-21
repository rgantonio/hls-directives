#ifndef COUNTER_H
#define COUNTER_H

#include <ap_int.h>

typedef ap_uint<8> cnt_t;   // wraps from 255 to 0
typedef ap_uint<3> slot_t;  // selects one of H entries

const int H        = 8;
const int CNT_INIT = 100;   // non-zero, so a restart is visible

cnt_t counter(slot_t slot, cnt_t *hits);

#endif