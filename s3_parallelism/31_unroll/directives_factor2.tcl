# Solution: factor2
#
# Unroll VADD_LOOP by 2. The body is duplicated, the trip count falls from 16
# to 8, and the design gets two adders. Each pass then reads two elements of a
# and two of b and writes two of y, which is exactly what the two ports of an
# ap_memory interface can carry in one cycle, so this factor is expected to
# halve the cycle count. Look for address1, ce1 and q1 in the generated
# Verilog: they are the second port that Vitis adds on demand.
set_directive_unroll -factor 2 "vadd/VADD_LOOP"