# Lesson 2.2 - ARRAY_RESHAPE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the ARRAY_RESHAPE directive on the
# argument x of the function sum4 differs between them. The kernel and the
# solution names match lesson 2.1, so the two lessons compare directly.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset sum4_proj
set_top sum4

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/sum4.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/sum4_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base cyclic4 block4 complete} {

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

    # Reshaping changes which word and which slice hold each element of x,
    # which only the RTL shows. Co-simulation checks that packing in every
    # solution.
    cosim_design
}

exit