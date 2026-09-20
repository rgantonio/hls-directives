# Solution: false_dep
#
# Same two helpers as base, then the directive of this lesson.
#
# DEPENDENCE promises that no iteration of HIST_LOOP reads an element of acc
# that another iteration writes (-type inter). The dependence inside one
# iteration, read acc[b] then write acc[b], is real and is left alone.
#
# The tool does not check the promise. It is true only for inputs in which no
# two samples within two iterations of each other name the same bin. The
# "repeat" co-simulation shows what happens when it is broken.
set_directive_pipeline "hist/HIST_LOOP"
set_directive_bind_storage -type RAM_2P -impl BRAM -latency 1 "hist" acc
set_directive_dependence -variable acc -type inter -dependent false "hist/HIST_LOOP"
