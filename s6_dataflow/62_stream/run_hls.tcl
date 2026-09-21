# Lesson 6.2 - STREAM
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. DATAFLOW is the helper directive and
# is in every solution, including base. Only STREAM on t differs:
#
#   base   DATAFLOW only; t becomes a FIFO of depth 16 on its own
#   pipo   STREAM -type pipo; t becomes a ping-pong buffer of two banks
#   d2     STREAM -type fifo -depth 2; t becomes a FIFO of depth 2
#
# STREAM changes when each process may run, which is behavior at the
# boundary, so every solution is co-simulated. The d2 co-simulation records
# the ports of every module (port_hier), so that the FIFO t_U can be dumped
# afterwards with dump_fifo_vcd.tcl.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset pipe2_proj
set_top pipe2

add_files     $lesson_dir/src/pipe2.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/pipe2_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {base pipo d2} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # The C code is identical in every solution, and C simulation has no
    # notion of channels, so C simulation runs once, in base.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # Only d2 needs a trace, because only d2 can fill its FIFO.
    if {$sol eq "d2"} {
        set trace port_hier
    } else {
        set trace none
    }

    # Co-simulation runs the testbench twice, so expect two TEST PASSED lines
    # per solution. The catch keeps a failure in one solution from hiding
    # the others.
    if {[catch {cosim_design -rtl verilog -trace_level $trace} err]} {
        puts "COSIM FAILED in $sol: $err"
    }
}

exit