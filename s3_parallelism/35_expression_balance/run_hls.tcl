# Lesson 3.5 - EXPRESSION_BALANCE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Two kernels, each built in its own project with the same three solutions.
# Only the EXPRESSION_BALANCE directive differs between the solutions:
#
#   off       set_directive_expression_balance -off <top>
#   default   no directive, the tool's own behaviour
#   on        set_directive_expression_balance <top>
#
# EXPRESSION_BALANCE is a directive Vitis applies on its own, so each kernel
# needs all three: off against default shows what the default does, and
# default against on shows whether the explicit directive adds anything.
#
# The two kernels split the two halves of the lesson, which an earlier version
# of this lesson tried to carry in one function and could not:
#
#   sum32  an integer chain of 32 scalars. Long enough that the balanced tree
#          needs fewer states than the chain, which is the latency saving the
#          directive exists for. An 8-operand chain is not: Vitis fuses pairs
#          of chained additions into three-input ternary adders, which halves
#          the chain's delay path, and at 8 operands both shapes fit in the
#          same 2 states.
#
#   fsum8  a float chain of 8 scalars. Measures whether the directive reaches
#          floating-point expressions at all. Nothing else in the design may
#          set the latency, or the answer is hidden, which is the second
#          reason the two kernels are separate.
#
# Read run.log for "XFORM 203-11", the balancing message, with its count of
# balanced expressions. Results are in README.md section 7.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
foreach top {sum32 fsum8} {

    puts "=============================================================="
    puts "== kernel $top"
    puts "=============================================================="

    open_project -reset ${top}_proj
    set_top $top

    add_files     $lesson_dir/src/$top.cpp       -cflags "-I$lesson_dir/src"
    add_files -tb $lesson_dir/tb/${top}_tb.cpp   -cflags "-I$lesson_dir/src"

    foreach sol {off default on} {

        puts "--------------------------------------------------------------"
        puts "== solution $top/$sol"
        puts "--------------------------------------------------------------"

        open_solution -reset $sol -flow_target vivado
        source $common_dir/part.tcl
        source $lesson_dir/directives_${top}_${sol}.tcl

        csynth_design

        # Co-simulation runs on every solution, because this directive can
        # change behaviour. Regrouping an int sum cannot change its bits, since
        # two's-complement addition is associative even when it wraps, so for
        # sum32 cosim is a plain correctness check. Regrouping a float sum can
        # change its bits, since every addition rounds, and fsum8/on is exactly
        # the solution where the tool might regroup one. The fsum8 testbench
        # compares bit for bit and its regroup_bait cases return different
        # values for a chain and a tree, so a regrouped float sum fails here
        # rather than passing within an epsilon.
        #
        # cosim_design raises a Tcl error when the testbench returns non-zero.
        # The catch keeps that from ending the run, so a reassociating solution
        # is reported and the remaining ones still finish.
        #
        # There is no separate csim_design call. cosim_design compiles and runs
        # the same testbench, twice per solution, so a clean run prints
        # TEST PASSED exactly twelve times: 2 per solution, 6 per kernel.
        if {[catch {cosim_design} err]} {
            puts "COSIM FAILED in $top/$sol: $err"
        }
    }
}

exit
