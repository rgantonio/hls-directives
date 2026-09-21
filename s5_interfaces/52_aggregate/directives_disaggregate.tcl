# Solution: disaggregate
#
# Both struct arrays are split into one array per field. src becomes three
# read memories of 5, 6 and 5 bits, and dst becomes three write memories of
# the same widths, each with its own address0 and ce0 (and we0 and d0 for
# dst). The directive goes on both arguments so that the whole interface
# changes in one step, as in lesson 5.1.
#
# Predicted, not yet measured: function latency 33, because each memory still
# receives one access per iteration and all six are addressed by the same
# counter. dst_r_d0 is driven directly by src_b_q0, with no part-select.

set_directive_disaggregate "rgb" src
set_directive_disaggregate "rgb" dst