# Solution: cyclic4
#
# Pack x into 4 words of 128 bits by placing neighbouring elements side by
# side: word i holds x[4i] to x[4i+3], with x[4i+j] in slice j. The four
# reads of iteration i become one read of word i, and because j is a
# compile-time constant, each slice is a fixed group of wires.
# Check run.log: a reshape message for x should appear here.
set_directive_array_reshape -type cyclic -factor 4 -dim 1 "sum4" x
