# Solution: bram_lat2
#
# The same block RAM as bram, with the read latency raised to 2. The block RAM
# then uses its built-in output register, so read data arrives two cycles
# after the address instead of one. Only the -latency option differs from
# bram. Every read of a_buf in the unpipelined ADD_LOOP should wait one
# cycle longer.
set_directive_bind_storage -type RAM_1P -impl BRAM -latency 2 "vadd" a_buf