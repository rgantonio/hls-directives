# Lesson 0.1 - TOP and the project harness
#
#   vitis_hls -f run_hls.tcl 2>&1 | tee run.log
#
# Three solutions live in one project. Only the choice of top function differs
# between them.

set lesson_dir [file normalize [file dirname [info script]]]
set common_dir [file normalize $lesson_dir/../../common]

open_project -reset vadd_proj

# Design files. Anything added with add_files is compiled AND can be synthesized.
add_files $lesson_dir/src/vadd.cpp -cflags "-I$lesson_dir/src"

# Testbench files. Anything added with add_files -tb is compiled for C simulation
# and for co-simulation, but is never turned into hardware.
add_files -tb $lesson_dir/tb/vadd_tb.cpp -cflags "-I$lesson_dir/src"

# solution name -> the name handed to set_top
foreach {sol top} {base vadd sub vadd_core rename vadd_ip} {

    puts "=============================================================="
    puts "== solution $sol   (top = $top)"
    puts "=============================================================="

    open_solution -reset $sol -flow_target vivado
    source $common_dir/part.tcl
    source $lesson_dir/directives_$sol.tcl

    # set_top is a project-level setting, so it is repeated for every solution.
    # It is placed after the directives file so that the alias created by
    # set_directive_top in the rename solution already exists when the name is
    # resolved. If your install rejects this order, move this line above
    # open_solution and see the troubleshooting note in README.md.
    set_top $top

    csim_design
    csynth_design
}

exit