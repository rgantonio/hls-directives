# Solution: block4
#
# Split x into four banks of consecutive elements: bank k holds x[4k] to
# x[4k+3]. The four reads of iteration i all go to bank i, which is known only
# at run time, so every read has to be presented to all four banks. The
# addresses inside a bank are then the constants 0 to 3, which makes all 16
# reads loop invariant: Vitis hoists them out of the loop and keeps the whole
# array in registers. Fast, but 512 flip-flops. See README section 7.
# Check run.log: a partitioning message for x should appear here.
set_directive_array_partition -type block -factor 4 -dim 1 "sum4" x
