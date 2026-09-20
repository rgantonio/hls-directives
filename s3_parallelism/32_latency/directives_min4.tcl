# Solution: min4
#
# Ask for a minimum function latency of 4 cycles. The natural latency is 2S,
# where S is the number of states one multiply occupies, so the request is
# already satisfied before the tool does anything for any S >= 2.
#
# This number was chosen to be comfortably below the natural latency and in
# fact lands exactly on it, because S turned out to be 2 rather than 3. The
# do-nothing case is unaffected -- a constraint that is met is met -- but it is
# a useful reminder that a latency written as an absolute number of cycles is
# a guess about the operator library until it has been measured.
#
# A satisfied constraint produces no logic and no message. This solution exists
# to measure that, rather than to assert it: the expected result is the same
# latency as base, the same resources as base, no warning in run.log, and the
# same hardware as base.
#
# Measured: latency 4, interval 5, DSP 9, FF 596, LUT 242 -- every number
# identical to base. The generated poly.v is NOT textually identical: the
# directive inserts a speclatency pseudo-operation into the intermediate
# representation, which shifts every auto-generated net and register name
# suffix by 6. Normalise the suffixes away and the files are byte identical.
# See README.md section 7.
set_directive_latency -min 4 "poly"
