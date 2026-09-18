# Solution: off
#
# Keep ROW_LOOP and COL_LOOP as a nest. UG1399 places the directive on the
# innermost loop; -off stops the tool from flattening this nest on its own.
# Check run.log: no "Flattening a loop nest" message should appear for off.
set_directive_loop_flatten -off "madd/COL_LOOP"