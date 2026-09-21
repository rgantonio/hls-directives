# Solution: reset_cnt
#
# Adds a reset to the static scalar cnt only. Its always block gains
# "if (ap_rst == 1'b1) cnt <= 8'd100;", a synchronous, active-high reset.
#
# Predicted, not yet measured: latency and interval as in base; no extra FF
# and no extra LUT; FDSE cells rise from 1 to 4, because 100 = 0110_0100 sets
# three bits; after a mid-run reset, ap_return restarts at 101 while hits
# continues at 5.

set_directive_reset "counter" cnt