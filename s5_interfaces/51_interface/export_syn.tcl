# Lesson 5.1 - INTERFACE, Vivado synthesis of every solution
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export.log
#
# Run after run_hls.tcl. The s_axilite and m_axi adapters are pre-written RTL
# that the C synthesis estimate counts poorly, so the area this lesson quotes
# comes from here. The project and solutions are opened WITHOUT -reset, so the
# RTL that run_hls.tcl produced is kept.
#
# Results: vadd_proj/<sol>/impl/report/verilog/*export*.rpt

open_project vadd_proj

foreach sol {base fifo axilite maxi} {
    puts "=============================================================="
    puts "== export $sol"
    puts "=============================================================="
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit