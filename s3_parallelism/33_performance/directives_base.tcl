# Solution: base
#
# No directives. The scheduler produces whatever schedule it considers shortest
# for a clock period of 3.33 ns, and that schedule is the reference the other
# five solutions are compared against.
#
# common/part.tcl sets config_compile -pipeline_loops 0, and here that setting
# does real work: without it, Vitis would pipeline a 16-iteration loop on its
# own and this baseline would already be optimized. So ACC_LOOP runs one
# iteration at a time.
#
# Measured on Vitis HLS 2023.2.2 for xcku5p-ffvb676-2-e at 3.33 ns: the float
# addition binds to Core 18 'FAddSub_fulldsp' with <Latency = 10>, generating
# the module acc_fadd_32ns_32ns_32_11_full_dsp_1, and one iteration occupies
# fourteen states:
#
#   state 2      loop test, i+1, address of x[i] driven onto the ap_memory port
#   state 3      read data returns          (RAM core, Latency = 1, 2 states)
#   states 4-14  the floating-point add     (Latency = 10, 11 states)
#   state 15     sum written back
#
#   L_it     = 14
#   loop     = 16 * 14 = 224
#   function = 225,  interval = 226
#
# DSP 2, FF 485, LUT 344, estimated clock 2.262 ns against a 2.431 ns budget.
