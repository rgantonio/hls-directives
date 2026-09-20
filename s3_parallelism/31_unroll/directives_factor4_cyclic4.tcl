# Solution: factor4_cyclic4
#
# The same unroll factor as factor4, with the port bound removed. Splitting
# a, b and y cyclically into four banks gives every copy of the body a memory
# of its own: copy k of pass i touches element i+k, i is a multiple of 4, and
# a cyclic partition with factor 4 puts element i+k in bank k. No bank is
# touched twice in a cycle, so all four reads and all four writes fit in one.
#
# This is the only solution in the repository that carries a directive from
# another lesson. It has to, because the claim that factor4 is limited by
# memory ports cannot be measured without one solution in which it is not.
# A cyclic partition is used rather than a complete one because the index i+k
# is a run-time value under a partial unroll, and a complete partition would
# answer it with a sixteen-to-one multiplexer per copy.
set_directive_unroll -factor 4 "vadd/VADD_LOOP"
set_directive_array_partition -type cyclic -factor 4 -dim 1 "vadd" a
set_directive_array_partition -type cyclic -factor 4 -dim 1 "vadd" b
set_directive_array_partition -type cyclic -factor 4 -dim 1 "vadd" y