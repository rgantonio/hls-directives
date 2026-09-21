# Solution: aggregate_byte
#
# Both struct arrays are aggregated into one word per pixel with every field
# starting on a byte boundary: r in bits 4..0, g in 13..8, b in 20..16, and
# padding in bits 7..5, 15..14 and 23..21. The word is 24 bits, a third of
# which carries no data.
#
# Predicted, not yet measured: one HLS 214-241 line per argument reporting
# compact=byte and 24 bits; constant zeros in the padding bits of dst_d0;
# function latency 33. If the tool rejects compact=byte on an ap_memory port,
# the log line that rejects it is the result of this solution.

set_directive_aggregate -compact byte "rgb" src
set_directive_aggregate -compact byte "rgb" dst