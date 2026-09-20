# Solution: base
#
# No directives. Vitis HLS does not merge loops on its own, so ADD_LOOP and
# SUB_LOOP run one after the other, each with its own counter and exit test.
# common/part.tcl sets config_compile -pipeline_loops 0, so neither loop is
# pipelined.