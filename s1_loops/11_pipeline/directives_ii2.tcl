# Solution: ii2
#
# Pipeline VADD_LOOP with a target initiation interval of 2, so that a new
# iteration starts every second clock cycle. With an iteration depth of 2
# this gives no overlap at all; see the question in README.md section 9.
set_directive_pipeline -II 2 "vadd/VADD_LOOP"