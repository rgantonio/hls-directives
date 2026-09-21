# Solution: base
#
# No directives. In the Vivado flow every array argument of the top function
# defaults to ap_memory: the block drives address0 and ce0 (and we0 and d0
# for y) and receives q0 one cycle after the address.
#
# An explicit "set_directive_interface -mode ap_memory" with no options would
# produce the same RTL, which is why there is no separate ap_memory solution.
# The -latency and -storage_type options of ap_memory change the storage model,
# not the protocol; lesson 2.3 covers them.
#
# Expected from lesson 3.1, same kernel and same settings: iteration latency 2,
# function latency 33, interval 34, estimated clock 2.370 ns, 13 FF, 93 LUT.