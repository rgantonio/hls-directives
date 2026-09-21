# Solution: reset_hist
#
# Adds a reset to the static array hist only. A memory has no reset pin, so
# the RTL must write the eight initial values back one address at a time, or
# the tool must move hist into registers.
#
# Predicted, not yet measured: function latency 1 per call; the first call
# after a reset takes about 9 cycles from start to done; an address counter
# and a mux on the memory ports appear; after a mid-run reset, hits restarts
# at 2 while ap_return continues at 104. If hist moves to the Register
# section of the report instead, the reset costs 64 FF and no cycles.

set_directive_reset "counter" hist