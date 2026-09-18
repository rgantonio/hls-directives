# Solution: default
#
# No directives. The tool decides on its own whether to flatten the perfect
# nest ROW_LOOP/COL_LOOP. Vitis HLS 2023.2 flattens automatically only as part
# of pipelining, so with the loop unpipelined the nest stays nested and the RTL
# matches off after normalization.
# common/part.tcl sets config_compile -pipeline_loops 0, so the loop (nested
# or flattened) is not pipelined in any solution.
