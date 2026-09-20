# Lesson 2.3 - BIND_STORAGE
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Four solutions live in one project. Only the BIND_STORAGE directive on the
# local array a_buf of the function vadd differs between them:
#
#   base       no directive; the tool chooses the storage
#   bram       RAM_1P in block RAM, default latency
#   lutram     RAM_1P in look-up tables, default latency
#   bram_lat2  RAM_1P in block RAM, read latency 2

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset vadd_proj
set_top vadd

# Design files are compiled and synthesized. Testbench files are only compiled
# for simulation and never become hardware.
add_files     $lesson_dir/src/vadd.cpp    -cflags "-I$lesson_dir/src"
add_files -tb $lesson_dir/tb/vadd_tb.cpp  -cflags "-I$lesson_dir/src"

foreach sol {base bram lutram bram_lat2} {

    puts "=============================================================="
    puts "== solution $sol"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # C simulation runs the unchanged C code, so it gives the same answer for
    # every solution. It runs once, in base, to prove the testbench passes.
    if {$sol eq "base"} {
        csim_design
    }

    csynth_design

    # a_buf is a memory inside the design, and the solutions change when
    # its read data arrives. Co-simulation drives the real memory module and
    # checks that the schedule waits for the data, and it measures the
    # latency the RTL actually takes.
    cosim_design
}

exit