# Lesson 6.2 - dump the channel FIFO t_U of the d2 co-simulation to a VCD
#
# Run from pipe2_proj/d2/sim/verilog after run_hls.tcl:
#   xsim pipe2 -tclbatch ../../../../dump_fifo_vcd.tcl
#
# The snapshot must have been built with -trace_level port_hier, which
# run_hls.tcl does for d2 only. If get_objects returns nothing, list the
# hierarchy with:  get_scopes -r /apatb_pipe2_top/*

open_vcd fifo_t.vcd
log_vcd [get_objects /apatb_pipe2_top/AESL_inst_pipe2/t_U/*]
run all
close_vcd
quit