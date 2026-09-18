# Solution: ii1
#
# Pipeline VADD_LOOP with a target initiation interval of 1, so that a new
# iteration starts every clock cycle. The -II 1 is the default and is written
# out only to make the difference to ii2 visible.
set_directive_pipeline -II 1 "vadd/VADD_LOOP"