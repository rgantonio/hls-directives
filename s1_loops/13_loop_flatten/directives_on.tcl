# Solution: on
#
# Ask explicitly for the nest to be flattened. The directive goes on the
# innermost loop and flattens it together with the loops above it. On this
# kernel it is the only solution that flattens, and it is slower than off
# because the j/i wrap multiplexer pushes the memory read into an extra state.
set_directive_loop_flatten "madd/COL_LOOP"
