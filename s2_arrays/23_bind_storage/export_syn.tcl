# Lesson 2.3 - Vivado logic synthesis of every solution
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export_syn.log
#
# Run it after run_hls.tcl, from the lesson folder. It shows what Vivado
# actually builds for a_buf, which matters most in base, where the
# generated memory may carry ram_style "auto", which leaves the choice to
# Vivado.
#
# The project and the solutions are opened WITHOUT -reset, because a reset
# would delete the C synthesis results that this step synthesizes.
# Results: vadd_proj/<solution>/impl/report/verilog/export_syn.rpt

open_project vadd_proj
set_top vadd

foreach sol {base bram lutram bram_lat2} {
    puts "=============================================================="
    puts "== export_syn $sol"
    puts "=============================================================="
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit