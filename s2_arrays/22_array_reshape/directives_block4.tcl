# Solution: block4
#
# Pack x into 4 words of 128 bits by placing elements one block apart side
# by side: word j holds x[j], x[j+4], x[j+8] and x[j+12]. The four reads of
# iteration i take slice i of four different words, so one read cannot
# deliver them, and the slice number is the run-time value i. What the tool
# builds to pick that slice is question one of section 5 of the README.
# Check run.log: a reshape message for x should appear here.
set_directive_array_reshape -type block -factor 4 -dim 1 "sum4" x
