# Solution: complete
#
# Split x into its 16 elements. Because x is a top-level argument, each
# element is expected to become its own 32-bit input port, x_0 to x_15, and
# the memory interface of x disappears.
# Check run.log: a partitioning message for x should appear here.
set_directive_array_partition -type complete -dim 1 "sum4" x