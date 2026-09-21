# Kernel sum32, solution: on
#
# Explicitly enables expression balancing for the whole of sum32. For an
# integer expression this restates the default, so the prediction is that this
# solution matches default exactly, as it did on sum8.

# Measured: byte-identical to default, raw diff 0 lines, and it prints the same
# "31 expression(s) balanced" message. For an integer expression the directive
# without -off restates the default exactly. See README.md section 7.3.

set_directive_expression_balance "sum32"
