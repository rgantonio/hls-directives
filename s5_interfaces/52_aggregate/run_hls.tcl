# Lesson 5.2 - AGGREGATE and DISAGGREGATE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the struct handling of the two
# array arguments src and dst differs between them:
#
#   base            no directive; structs on the top-level interface are
#                   aggregated by default, with the default alignment
#   disaggregate    disaggregate on src and dst: one memory per field
#   aggregate_bit   aggregate -compact bit on src and dst: 16-bit word
#   aggregate_byte  aggregate -compact byte on src and dst: 24-bit word
#
# These directives change the port layout, so every solution is
# co-simulated, not only synthesized. Read the Interface section of
# syn/report/rgb_csynth.rpt, not only the latency.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset rgb_proj
set_top rgb

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/rgb.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/rgb_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {base disaggregate aggregate_bit aggregate_byte} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # The C code is identical in every solution and the C testbench never
    # sees a bit position, so C simulation runs once, in base.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # Co-simulation is the only step that exercises the new port layout. It
    # runs the testbench twice, so expect two TEST PASSED lines per solution.
    # The catch keeps a failure in one solution from hiding the others.
    if {[catch {cosim_design -rtl verilog} err]} {
        puts "COSIM FAILED in $sol: $err"
    }
}

exit