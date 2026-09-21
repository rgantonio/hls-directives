# Lesson 5.3 - Vivado synthesis of every solution, to count flip-flop
# primitives (FDRE, FDSE, FDCE, FDPE) and LUTs after real synthesis.
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export.log
#
# Run after run_hls.tcl. The project and solutions are opened without -reset,
# so the existing synthesis results are kept. Primitive counts land in
# counter_proj/<sol>/impl/verilog/report/counter_utilization_synth.rpt and
# totals in counter_proj/<sol>/impl/report/verilog/counter_export.rpt.

open_project counter_proj

foreach sol {base reset_cnt reset_hist} {
    puts "== export $sol"
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit