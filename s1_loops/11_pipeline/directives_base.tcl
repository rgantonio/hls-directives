# Solution: base
#
# No directives. VADD_LOOP runs its iterations one after the other.
# common/part.tcl sets config_compile -pipeline_loops 0, which stops Vitis
# from pipelining this short loop on its own.