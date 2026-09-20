# Solution: cyclic4
#
# Split x into four banks by dealing the elements out in turn: bank j holds
# x[j], x[j+4], x[j+8] and x[j+12]. The four reads of iteration i go to four
# different banks at the same address i, so no port conflict is left and no
# address arithmetic is needed. The measured schedule still spreads the reads
# over two states, but the iteration costs 3 cycles instead of 4.
# Check run.log: a partitioning message for x should appear here.
set_directive_array_partition -type cyclic -factor 4 -dim 1 "sum4" x
