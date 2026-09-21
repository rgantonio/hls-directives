# Solution: aggregate_bit
#
# Both struct arrays are aggregated into one word per pixel with the fields
# packed back to back: r in bits 4..0, g in 10..5, b in 15..11, 16 bits in
# total and no padding.
#
# Predicted, not yet measured: one HLS 214-241 line per argument reporting
# compact=bit and 16 bits; RTL identical to base after normalising instance
# numbers; function latency 33.

set_directive_aggregate -compact bit "rgb" src
set_directive_aggregate -compact bit "rgb" dst