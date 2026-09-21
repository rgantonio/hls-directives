# Lesson 4.1 - BIND_OP
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the BIND_OP directives on the three
# multiplies of poly differ between them:
#
#   base    no directive; the tool binds every multiply to dsp, latency 1
#   fabric  -op mul -impl fabric              the multiplies leave the DSPs
#   lat0    -op mul -impl dsp -latency 0      no register inside each core
#   lat3    -op mul -impl dsp -latency 3      three registers inside each core
#
# lat0 is expected to break the target clock and still exit 0, as max1 did in
# lesson 3.2. Read the estimated clock and the slack, not only the latency.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset poly_proj
set_top poly

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/poly.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/poly_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base fabric lat0 lat3} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # A binding changes which core computes each product and how many cycles
    # it takes, but every core returns the same low 32 bits of the same
    # product. The function cannot compute anything different, so C simulation
    # runs once, in base, to show that the testbench passes.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # No co-simulation, for the same reason. Uncomment the line below to see
    # the lat3 handshake as a waveform: y_ap_vld and ap_done in state 9.
    #
    # cosim_design -trace_level all
}

exit