# Solution: base
#
# No directives. Under the default config_rtl -reset control, ap_rst resets
# the FSM and the handshake registers only. cnt and hist receive their C
# initial values through the RTL initial block, which becomes the INIT value
# of the flip-flops and memory in the bitstream, and a later ap_rst leaves
# them unchanged.
#
# Predicted, not yet measured: function latency 1, interval 2; one FDSE cell
# (the first bit of the one-hot FSM); after a mid-run reset, ap_return
# continues at 104 and hits at 5.