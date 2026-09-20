# Solution: dist2
#
# Same two helpers as base, then the other form of the directive.
#
# Instead of denying the dependence, this solution declares that it is real
# but that the iterations involved are two apart. The number 2 is taken
# straight from the II Violation message that base prints, which reads
# "distance = 2". This solution exists to show that copying that number into
# the directive is a mistake: the distance in the message is not the
# iteration distance the -distance option expects, the true iteration
# distance of a histogram is 1, and the resulting hardware is wrong.
set_directive_pipeline "hist/HIST_LOOP"
set_directive_bind_storage -type RAM_2P -impl BRAM -latency 1 "hist" acc
set_directive_dependence -variable acc -type inter -dependent true -direction RAW -distance 2 "hist/HIST_LOOP"
