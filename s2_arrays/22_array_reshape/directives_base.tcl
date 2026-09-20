# Solution: base
#
# No directives. The argument x stays one ap_memory port of 16 words of 32
# bits. Every iteration of SUM_LOOP reads four elements, so the tool gives x
# a second read port and still needs two cycles to issue the four reads.
# This solution should reproduce the base of lesson 2.1 exactly.
# common/part.tcl sets config_compile -pipeline_loops 0, so SUM_LOOP is not
# pipelined. Check run.log: no reshape message should appear here.