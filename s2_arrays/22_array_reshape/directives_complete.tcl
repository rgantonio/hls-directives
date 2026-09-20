# Solution: complete
#
# Pack all 16 elements of x into one word of 512 bits. Because x is a
# top-level argument, it is expected to become a single 512-bit input port;
# check the interface table for its protocol. Every term of the sum then
# lives at a bit offset that depends on i, so this solution asks the same
# question as block4, over a word four times as wide.
# Check run.log: a reshape message for x should appear here.
set_directive_array_reshape -type complete -dim 1 "sum4" x
