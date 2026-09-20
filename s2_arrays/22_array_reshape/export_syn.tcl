# Lesson 2.2 - Vivado logic synthesis of every solution
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export_syn.log
#
# Run it after run_hls.tcl, from the lesson folder. Lesson 2.1 uses the same
# project name, so the same script works there:
#
#   cd ../21_array_partition && vitis_hls -f ../22_array_reshape/export_syn.tcl
#
# The project and the solutions are opened WITHOUT -reset, because a reset
# would delete the C synthesis results that this step synthesizes.
# Results: sum4_proj/<solution>/impl/report/verilog/export_syn.rpt

open_project sum4_proj
set_top sum4

foreach sol {base cyclic4 block4 complete} {
    puts "=============================================================="
    puts "== export_syn $sol"
    puts "=============================================================="
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit