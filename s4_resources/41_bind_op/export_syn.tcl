# Lesson 4.1 - optional Vivado synthesis of every solution
#
#   vitis_hls -f export_syn.tcl 2>&1 | tee export.log
#
# Run this after run_hls.tcl. It opens the existing project WITHOUT -reset,
# so the C synthesis results stay in place, and runs Vivado synthesis on the
# RTL of each solution. The post-synthesis report under
# poly_proj/<solution>/impl/report/verilog/ gives the real LUT, FF and DSP
# counts and the real critical path. This lesson needs those numbers for two
# reasons: the fabric multipliers' LUT cost is only an estimate in C
# synthesis, and the extra FF of lat3 may be absorbed into the DSP slices.

set lesson_dir [file normalize [file dirname [info script]]]
cd $lesson_dir

open_project poly_proj

foreach sol {base fabric lat0 lat3} {
    puts "=============================================================="
    puts "== export_design -flow syn, solution $sol"
    puts "=============================================================="
    open_solution $sol
    export_design -flow syn -rtl verilog -format ip_catalog
}

exit