# Lesson 3.1 - UNROLL
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the UNROLL directive on VADD_LOOP
# differs between the first three:
#
#   base             rolled loop, one adder
#   factor2          two copies of the body, two adders
#   factor4          four copies of the body, four adders
#   factor4_cyclic4  the same four copies, plus a cyclic partition of a, b and
#                    y into four banks each, so that the four copies can
#                    actually be fed. This is the one solution that carries a
#                    second directive; README.md section 4 says why.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset vadd_proj
set_top vadd

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/vadd.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/vadd_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base factor2 factor4 factor4_cyclic4} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # Unrolling by a factor that divides the trip count cannot change what the
    # C code computes, so C simulation only needs to run once. It runs in base
    # to prove the testbench passes.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # The unrolled solutions drive a second port on interfaces that base never
    # uses, and factor4_cyclic4 changes the port list completely.
    # Co-simulation checks that those ports are driven legally and that no lane
    # uses data before the memory has produced it, and it measures the latency
    # the RTL actually takes.
    cosim_design
}

exit