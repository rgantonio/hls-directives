# Kernel fsum8, solution: default
#
# No directive. This file exists so that every solution sources a directives
# file of the same name pattern, and it is intentionally empty of commands.
#
# Predicted: the float sum keeps the order the source writes, because IEEE 754
# addition is not associative and Vitis will not change a result the C code
# specifies. Latency 76, interval 77, sf written in state 77.

# Measured: exactly as predicted. The chain is kept, latency 76, interval 77.
# Identical to off, which is the whole point: for floats there is nothing for
# -off to suppress. See README.md section 7.4.
