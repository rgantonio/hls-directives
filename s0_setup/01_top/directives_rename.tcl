# Solution: rename
#
# Give the function vadd the alternative top-level name vadd_ip. run_hls.tcl
# then selects the design with "set_top vadd_ip". The synthesized logic is
# identical to the base solution; only the RTL module name changes.
set_directive_top -name vadd_ip "vadd"