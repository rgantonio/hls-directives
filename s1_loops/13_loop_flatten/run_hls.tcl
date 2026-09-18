# Lesson 1.3 - LOOP_FLATTEN
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. Only the LOOP_FLATTEN directive on
# COL_LOOP differs between them: -off, absent (tool default), and on.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset madd_proj
set_top madd

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/madd.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/madd_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {off default on} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # Flattening changes the loop control, never the computation, so C
    # simulation runs once, in off, to prove the testbench passes.
    if {$sol eq "off"} {
        csim_design
    }

    csynth_design
}

exit