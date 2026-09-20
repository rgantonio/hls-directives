# Solution: merge
#
# Merge the loops inside the function two_loops. The directive names the
# region that contains the loops, not one of the loops. Both loops have the
# same constant bound and no dependence on each other, so no -force is needed.
# Check run.log: a merge message for two_loops should appear only here.
set_directive_loop_merge "two_loops"