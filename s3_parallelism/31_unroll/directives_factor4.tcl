# Solution: factor4
#
# Unroll VADD_LOOP by 4. The body is copied four times and the trip count
# falls to 4, so the design gets four adders. The arguments still have one
# ap_memory interface each, and an ap_memory interface carries at most two
# accesses per cycle, so only two of the four copies can be fed at a time and
# the body needs an extra state. Four adders, two ports: this is the memory
# port starvation that the lesson is about. See README.md sections 5 and 7.
set_directive_unroll -factor 4 "vadd/VADD_LOOP"