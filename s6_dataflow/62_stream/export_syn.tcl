# Lesson 6.2 - Vivado synthesis of every solution (about 8 minutes)
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export.log
#
# Run after run_hls.tcl. The project and solutions are opened without -reset
# so that the C synthesis results are kept. Primitives land in
#   pipe2_proj/<sol>/impl/verilog/report/pipe2_utilization_synth.rpt
# and totals in
#   pipe2_proj/<sol>/impl/report/verilog/pipe2_export.rpt

open_project pipe2_proj

foreach sol {base pipo d2} {
    puts "== export $sol"
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit