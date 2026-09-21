# Lesson 5.2 - out-of-context Vivado synthesis of every solution.
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export.log
#
# Run after run_hls.tcl. The project and solutions are opened without -reset
# so the existing synthesis results are reused. The point is to confirm that
# the field selection costs no LUTs: the C synthesis LUT estimate is not
# reliable enough for that claim. Totals land in
# rgb_proj/<sol>/impl/report/verilog/rgb_export.rpt.

open_project rgb_proj

foreach sol {base disaggregate aggregate_bit aggregate_byte} {
    puts "== export $sol"
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit