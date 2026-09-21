# Lesson 4.2 - ALLOCATION
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. Only the ALLOCATION limit on the
# multiplies of poly differs between them:
#
#   base    no directive; the tool builds three multiplier instances
#   limit2  -limit 2 -type operation poly mul   one instance is shared
#   limit1  -limit 1 -type operation poly mul   all three multiplies share one
#
# The shared solutions remove DSP slices and add an operand multiplexer on
# each input of the shared instance. Read the Instance and Multiplexer tables
# of poly_csynth.rpt, not only the DSP column.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset poly_proj
set_top poly

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/poly.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/poly_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base limit2 limit1} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # Sharing a multiplier changes which instance computes each product and
    # in which state, but never the product itself. The function cannot
    # compute anything different, so C simulation runs once, in base.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # No co-simulation, for the same reason. Uncomment the line below to see
    # the limit1 din0 multiplexer switch from x to b to the registered a * x
    # across states 1 to 3, and din1 switch from a to x.
    #
    # cosim_design -trace_level all
}

exit