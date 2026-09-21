# Lesson 6.1 - Vivado synthesis of both solutions
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export.log
#
# Run after run_hls.tcl. The project and solutions are opened without -reset,
# so the existing C synthesis results are reused. This shows the physical
# form of the channel memory t (LUTRAM, block RAM or flip-flops), which the
# C synthesis estimate cannot be trusted to report.
#
# Totals:     pipe2_proj/<sol>/impl/report/verilog/pipe2_export.rpt
# Primitives: pipe2_proj/<sol>/impl/verilog/report/pipe2_utilization_synth.rpt

open_project pipe2_proj

foreach sol {base dataflow} {
    puts "== export_design -flow syn, solution $sol"
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit