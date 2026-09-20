# Lesson 2.2 - clock sweep of the complete solution
#
#   vitis_hls -f clk_sweep.tcl 2>&1 | tee clk_sweep.log
#
# Synthesizes the complete reshape at three clock periods in a separate
# project and changes nothing else. If the function latency falls as the
# period grows while the LUT estimate stays the same, the extra state at
# 3.33 ns comes from the delay the scheduler assumes for the shifter.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset clk_proj
set_top sum4
add_files $lesson_dir/src/sum4.cpp -cflags "-I$lesson_dir/src"

foreach per {3.33 5.0 8.0} {

    puts "=============================================================="
    puts "== clock period $per ns"
    puts "=============================================================="

    open_solution -reset "c$per" -flow_target vivado
    source $common_dir/part.tcl
    # part.tcl sets the repository clock of 3.33 ns; this line overrides it.
    create_clock -period $per -name default
    source $lesson_dir/directives_complete.tcl

    csynth_design
}

exit