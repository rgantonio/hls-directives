# Solution: tl_tight
#
# A target of 20 cycles for sixteen dependent floating-point additions. No
# transformation the tool is permitted to apply reaches it: scheduling cannot
# compress a dependence chain, and unrolling cannot either, because sixteen
# dependent additions remain sixteen dependent additions however they are
# grouped. Regrouping them into partial sums would work and would change the
# answer, which is why the tool may not do it without
# config_compile -unsafe_math_optimizations.
#
# Unlike tl_miss, this one is refused loudly:
#
#   WARNING: [HLS 214-392] Cannot apply performance pragma target_tl=20 cycles
#     for loop 'ACC_LOOP' ... The target requires a pipeline II less than the
#     minimal achievable II of 9 determined by recurrent II equal to 9
#   INFO: [HLS 200-1957] Failed to apply performance pragma with Target TL='20'
#
# The two refusals produce the same hardware -- both are byte-for-byte base --
# so the warning is the only thing that distinguishes them, and the warning is
# emitted for some refused targets and not for others. Measured on this
# installation the boundary sits between 128, which warns, and 136, which does
# not. Only the INFO line is reliable.

set_directive_performance -target_tl 20 -unit cycle "acc/ACC_LOOP"
