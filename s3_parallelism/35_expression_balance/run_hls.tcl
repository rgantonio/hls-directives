# Lesson 3.5 - EXPRESSION_BALANCE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. Only the EXPRESSION_BALANCE directive
# on the function sum8 differs between them:
#
#   off       set_directive_expression_balance -off sum8
#   default   no directive, the tool's own behaviour
#   on        set_directive_expression_balance sum8
#
# EXPRESSION_BALANCE is a directive Vitis applies on its own, so the lesson
# needs all three: off against default shows what the default does, and
# default against on shows whether the explicit directive adds anything.
#
# The kernel holds two sums of the same shape, one int and one float, so one
# directive location governs both and any difference between them comes from
# their type. Measured, and reported in full in README.md section 7:
#
#   * the int sum is a chain in off and a tree in default and on, but both
#     shapes fit in two states, so si is written in state 2 in all three:
#     Vitis fuses chained additions into three-input ternary adders, which
#     shortens the chain's delay path before the scheduler ever sees it;
#   * the float sum stays a chain in all three, so the function latency is 76
#     cycles and the interval 77 everywhere, because neither the default nor
#     the explicit directive balances floats;
#   * default and on produce byte-identical RTL, and off differs from them
#     only by 14 LUT in the Expression table.
#
# Read run.log for "XFORM 203-11" (the balancing message, with its count of
# balanced expressions). It is absent in off and reports "7 expression(s)
# balanced" at src/sum8.cpp:5 in the other two, the 7 being the integer
# additions on line 10.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset sum8_proj
set_top sum8

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/sum8.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/sum8_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {off default on} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    csynth_design

    # Co-simulation runs on every solution, because this directive can change
    # behaviour. Regrouping an int sum cannot change its bits, since
    # two's-complement addition is associative even when it wraps. Regrouping
    # a float sum can, since every addition rounds, and "on" is exactly the
    # solution where the tool might regroup one.
    #
    # The testbench compares bit for bit, and its regroup_bait cases return
    # different values for a chain and a tree, so a regrouped float sum fails
    # here rather than passing within an epsilon.
    #
    # cosim_design raises a Tcl error when the testbench returns non-zero. The
    # catch keeps that from ending the run, so a reassociating "on" is
    # reported and the remaining solutions still finish.
    #
    # There is no separate csim_design call. cosim_design compiles and runs
    # the same testbench, twice per solution, so a clean run prints
    # TEST PASSED exactly six times.
    if {[catch {cosim_design} err]} {
        puts "COSIM FAILED in solution $sol: $err"
    }
}

exit