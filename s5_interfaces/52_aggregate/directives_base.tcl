# Solution: base
#
# No directives. In the Vivado flow a struct argument of the top function is
# aggregated by default: all fields of one pixel travel in one ap_memory word,
# with the first declared field (r) in the least significant bits.
#
# The default alignment is what this solution measures. The UG1399 alignment
# table lists compact=bit for non-AXI protocols, which predicts a 16-bit word
# identical to aggregate_bit. The 2022.1 "Structs on the Interface" page
# describes padded, byte-aligned structs in the Vivado flow, which would give
# a 24-bit word identical to aggregate_byte. Read the width in the Interface
# table of syn/report/rgb_csynth.rpt; no HLS 214-241 line is expected here.
#
# Predicted, not yet measured: function latency 33, interval 34.