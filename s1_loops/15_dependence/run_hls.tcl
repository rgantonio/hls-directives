# Lesson 1.5 - DEPENDENCE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. All three pipeline HIST_LOOP and pin
# the local array acc to a two-port block RAM. Only the DEPENDENCE directive
# differs:
#
#   base       no DEPENDENCE directive; the tool honours the dependence
#   false_dep  -dependent false; the dependence is denied
#   dist2      -dependent true -distance 2; the dependence is misdescribed
#
# The testbench takes one argument that selects its vector set:
#   unique  every bin appears at most once per call, so no dependence occurs
#   repeat  bins repeat, including back to back, so the dependence is real

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset hist_proj
set_top hist

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/hist.cpp     -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/hist_tb.cpp   -cflags "-I$lesson_dir/src"

set summary {}

foreach sol {base false_dep dist2} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # C simulation runs the unchanged, sequential C code, so it passes both
    # vector sets in every solution. It runs once, in base, to prove that the
    # testbench and the reference model agree.
    if {$sol eq "base"} {
        csim_design -argv unique
        csim_design -argv repeat
    }

    csynth_design

    # DEPENDENCE changes behaviour, so both vector sets go through RTL
    # co-simulation. A failing testbench makes cosim_design raise a Tcl error;
    # catch keeps the script running so that every result is collected.
    foreach vec {unique repeat} {
        if {[catch {cosim_design -argv $vec} err]} {
            lappend summary "== cosim $sol $vec FAIL"
        } else {
            lappend summary "== cosim $sol $vec PASS"
        }
    }
}

puts "=============================================================="
foreach line $summary {
    puts $line
}
puts "=============================================================="

exit
