# Lesson 6.1 - DATAFLOW
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Two solutions live in one project. Both use common/part.tcl unchanged, so
# the stage loops stay unpipelined and config_dataflow keeps its defaults.
# Only the DATAFLOW directive differs between them:
#
#   base       no directive; one FSM runs LOAD_LOOP, then STORE_LOOP
#   dataflow   DATAFLOW on pipe2; each loop becomes a process, t a channel
#
# DATAFLOW changes when each stage may run and when the top level accepts the
# next call, which is behavior at the boundary, so every solution is
# co-simulated. The testbench makes 16 calls so that the latency of a call and
# the interval between calls can both be measured.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset pipe2_proj
set_top pipe2

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/pipe2.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/pipe2_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {base dataflow} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # The C code is identical in every solution, and C simulation has no
    # notion of overlapping calls, so C simulation runs once, in base.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # Co-simulation runs the testbench twice, so expect two TEST PASSED lines
    # per solution. The catch keeps a failure in one solution from hiding
    # the other.
    if {[catch {cosim_design -rtl verilog} err]} {
        puts "COSIM FAILED in $sol: $err"
    }
}

exit