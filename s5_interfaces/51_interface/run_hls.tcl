# Lesson 5.1 - INTERFACE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the port protocol of the three
# array arguments a, b and y differs between them:
#
#   base     no directive; arrays default to ap_memory in the Vivado flow
#   fifo     ap_fifo on a, b and y
#   axilite  s_axilite on a, b and y, bundle control
#   maxi     m_axi on a, b and y, bundle gmem, offset direct, depth 16
#
# INTERFACE changes the wires and the timing at the boundary, so every
# solution is co-simulated, not only synthesized. Read the Interface section
# of syn/report/vadd_csynth.rpt and sim/report/vadd_cosim.rpt, not only the
# latency.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset vadd_proj
set_top vadd

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/vadd.cpp   -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/vadd_tb.cpp -cflags "-I$lesson_dir/src"

foreach sol {base fifo axilite maxi} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # The C code is identical in every solution and the C testbench never
    # sees a port protocol, so C simulation runs once, in base.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # Co-simulation is the only step that exercises the new ports. It runs the
    # testbench twice, so expect two TEST PASSED lines per solution. The catch
    # keeps a failure in one solution from hiding the others.
    #
    # To see the waveforms of section 5, add -trace_level port and open
    # vadd_proj/<sol>/sim/verilog/vadd.wdb in the Vivado simulator.
    if {[catch {cosim_design -rtl verilog} err]} {
        puts "COSIM FAILED in $sol: $err"
    }
}

exit