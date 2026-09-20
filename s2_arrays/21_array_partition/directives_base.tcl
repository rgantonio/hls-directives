# Solution: base
#
# No directives. The argument x stays one ap_memory port of 16 words. Every
# iteration of SUM_LOOP reads four elements, so the tool is expected to give
# x a second read port and still needs two cycles to issue the four reads.
# common/part.tcl sets config_compile -pipeline_loops 0, so SUM_LOOP is not
# pipelined. Check run.log: no partitioning message should appear here.