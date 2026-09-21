# Solution: lat3
#
# All three multiplies stay on DSP slices with latency 3: three register
# stages inside each core, so each multiply occupies four states. -impl dsp
# restates the choice base already makes, for the same reason as in lat0.
#
# Predicted: states = 2(3 + 1) + 1 = 9, latency 8, interval 9, still 9 DSP,
# an estimated clock no worse than base, and more FF. Some or all of those
# FF may be absorbed into the DSP48E2 internal registers by Vivado, which
# only export_syn.tcl can show.

set_directive_bind_op -op mul -impl dsp -latency 3 "poly" sq
set_directive_bind_op -op mul -impl dsp -latency 3 "poly" lin
set_directive_bind_op -op mul -impl dsp -latency 3 "poly" quad