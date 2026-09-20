# Lesson 3.1 - Vivado logic synthesis of every solution
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export_syn.log
#
# Run it after run_hls.tcl, from the lesson folder. It is optional here,
# because the result of this lesson is a cycle count and cycle counts are
# decided in C synthesis. It is still useful, because the lesson claims that
# LUT usage grows with the unroll factor, and lesson 2.2 showed that the C
# synthesis LUT estimate can be wrong by a large factor.
#
# The project and the solutions are opened WITHOUT -reset, because a reset
# would delete the C synthesis results that this step synthesizes.
# Results: vadd_proj/<solution>/impl/report/verilog/export_syn.rpt

open_project vadd_proj
set_top vadd

foreach sol {base factor2 factor4 factor4_cyclic4} {
    puts "=============================================================="
    puts "== export_syn $sol"
    puts "=============================================================="
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit