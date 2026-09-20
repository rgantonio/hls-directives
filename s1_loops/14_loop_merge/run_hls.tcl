# Lesson 1.4 - LOOP_MERGE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Two solutions live in one project. Only the LOOP_MERGE directive on the
# function two_loops differs between them.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset two_loops_proj
set_top two_loops

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/two_loops.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/two_loops_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base merge} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # C simulation runs the unchanged C code, so it gives the same answer for
    # every solution. It runs once, in base, to prove the testbench passes.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # Merging reorders memory accesses between the two loops, which only the
    # RTL shows. Co-simulation checks that order in every solution.
    cosim_design
}

exit