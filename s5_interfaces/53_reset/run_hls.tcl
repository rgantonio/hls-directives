# Lesson 5.3 - RESET
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. Every solution uses the default
# config_rtl -reset control from common/part.tcl, in which no static variable
# is reset. Only the RESET directive differs between them:
#
#   base        no directive; cnt and hist get their C values at power-up only
#   reset_cnt   RESET on the static scalar cnt
#   reset_hist  RESET on the static array hist
#
# A C testbench cannot drive ap_rst, and co-simulation resets once at time
# zero, where power-up and reset values coincide. Every solution is still
# co-simulated, because reset_hist may delay its first call. The reset in the
# middle of a run is exercised by sim_reset.sh on the generated RTL.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset counter_proj
set_top counter

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/counter.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/counter_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {base reset_cnt reset_hist} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # The C code is identical in every solution and C simulation knows
    # nothing about ap_rst, so C simulation runs once, in base.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # Co-simulation runs the testbench twice, so expect two TEST PASSED lines
    # per solution. The catch keeps a failure in one solution from hiding
    # the others.
    if {[catch {cosim_design -rtl verilog} err]} {
        puts "COSIM FAILED in $sol: $err"
    }
}

exit