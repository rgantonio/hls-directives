# Solution: sub
#
# The top function is vadd_core, selected with "set_top vadd_core" in
# run_hls.tcl. The synthesis boundary moves one level down the call tree, so
# vadd itself, its local array t and SCALE_LOOP are no longer part of the
# design. No other directive is applied.