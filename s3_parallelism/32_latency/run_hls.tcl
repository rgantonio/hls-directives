# Lesson 3.2 - LATENCY
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the LATENCY directive on the
# function poly differs between them:
#
#   base    no directive, the natural schedule
#   max1    -min 1 -max 1, a latency the clock period cannot support
#   min4    -min 4, a minimum that is not above the natural latency
#   min16   -min 16, a minimum above the natural latency
#
# base and min4 generate the same hardware. That is the result of the lesson,
# not an accident, and README.md section 7 checks it with diff rather than
# taking it on trust -- modulo the auto-generated name suffixes, which the
# directive shifts without changing any logic.
#
# max1 does NOT. Vitis honours the latency constraint by re-binding a multiply
# into fabric and breaking the target clock period, and it reports that as a
# warning rather than an error, so this script still exits 0. Read the
# estimated clock period and the slack, not just the latency table.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset poly_proj
set_top poly

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/poly.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/poly_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base max1 min4 min16} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # A latency constraint cannot change what the function computes. It moves
    # ap_done, and when it cannot be met at the target clock it changes the
    # schedule and the clock, but in no case does any operand reach any
    # operator that it did not reach before. So C simulation runs once, in
    # base, to show that the testbench passes.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # No co-simulation in this lesson, for the same reason: the directive
    # cannot change behaviour, and both the broken clock of max1 and the
    # padding of min16 are reported by C synthesis. Uncomment the line below
    # only if you want to see the padded handshake as a waveform: y_ap_vld
    # rises in state 5 and ap_done follows twelve cycles later, in state 17.
    #
    # cosim_design -trace_level all
}

exit