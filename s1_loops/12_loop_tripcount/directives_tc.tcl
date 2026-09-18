# Solution: tc
#
# Tell the latency estimator that VADD_LOOP runs between 1 and 16 times,
# and 8 times on average. The directive is for analysis only: the generated
# RTL is expected to be identical to base, and nothing checks these numbers
# against the code.
set_directive_loop_tripcount -min 1 -max 16 -avg 8 "vadd/VADD_LOOP"