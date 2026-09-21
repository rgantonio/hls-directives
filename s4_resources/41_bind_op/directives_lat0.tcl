# Solution: lat0
#
# All three multiplies stay on DSP slices, as in base, but with latency 0:
# no register inside the core, so each product must settle within the state
# that uses it. -impl dsp restates the choice base already makes. It is here
# so the tool cannot satisfy the latency by moving the multiply to fabric,
# which is what max1 did in lesson 3.2. With the implementation fixed, the
# latency is the only effective difference from base.
#
# Predicted: 3 states, latency 2, interval 3, 9 DSP, and an estimated clock
# above 3.33 ns with a timing warning, while the run still exits 0.

set_directive_bind_op -op mul -impl dsp -latency 0 "poly" sq
set_directive_bind_op -op mul -impl dsp -latency 0 "poly" lin
set_directive_bind_op -op mul -impl dsp -latency 0 "poly" quad