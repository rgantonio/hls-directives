# Lesson 1.2 - LOOP_TRIPCOUNT
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Two solutions live in one project. Only the LOOP_TRIPCOUNT directive on
# VADD_LOOP differs between them.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset vadd_proj
set_top vadd

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/vadd.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/vadd_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base tc} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # The directive changes only the report, never the computation, so C
    # simulation runs once, in base, to prove the testbench passes.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design
}

exit