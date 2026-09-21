# Lesson 4.3 - INLINE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. Only the INLINE setting of the two
# helper functions sum2 and bias differs between them:
#
#   off      set_directive_inline -off on both helpers; each stays a submodule
#   default  no directive; the tool decides on its own
#   on       set_directive_inline on both helpers; each is inlined into calls
#
# INLINE changes where the adders live and how they are scheduled, never what
# is computed. Read the Instance table of calls_csynth.rpt and list the files
# in syn/verilog, not only the latency.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset calls_proj
set_top calls

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/calls.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/calls_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {off default on} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # Inlining moves operations across a function boundary but cannot change
    # any result, so C simulation runs once, in default, which is the source
    # as written with no directive.
    if {$sol eq "default"} {
        csim_design
    }

    csynth_design

    # No co-simulation, for the same reason. Uncomment the line below to see
    # the off solution drive calls_sum2 in state 3 and calls_bias in state 4
    # of every iteration. Both submodules are combinational (latency 0), so
    # there is no ap_start to watch: look at the p/q and s/k inputs and at
    # tmp_reg_175, the register that carries the sum between the two states.
    #
    # cosim_design -trace_level all
}

exit