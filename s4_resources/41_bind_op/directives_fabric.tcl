# Solution: fabric
#
# All three multiplies are bound to fabric, which means LUTs and carry chains
# instead of DSP slices. No -latency is given, so the tool picks the number of
# register stages it needs to meet the 3.33 ns clock.
#
# One directive binds one operation, the one whose result is assigned to the
# named variable, so each multiply needs its own line. LLVM removes sq by
# rewriting a*(x*x) as (a*x)*x; README section 7 checks whether the binding
# on sq follows the rewritten multiply.
#
# Predicted: 0 DSP, about 3,250 LUT, and latency 4 if the tool picks one
# register stage per multiply.

set_directive_bind_op -op mul -impl fabric "poly" sq
set_directive_bind_op -op mul -impl fabric "poly" lin
set_directive_bind_op -op mul -impl fabric "poly" quad