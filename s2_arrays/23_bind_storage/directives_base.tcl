# Solution: base
#
# No directives. The local array a_buf gets whatever storage type and
# implementation Vitis HLS picks on its own, which the Bind Storage Report and
# the ram_style attribute of the generated memory module show. Section 5 of
# the README asks which of the other solutions base will match.
# common/part.tcl sets config_compile -pipeline_loops 0, so neither loop is
# pipelined.