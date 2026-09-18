# hls-directives - top level helpers
#
#   make list
#   make run   LESSON=s0_setup/01_top
#   make check LESSON=s0_setup/01_top
#   make clean LESSON=s0_setup/01_top

SHELL  := /bin/bash
LESSON ?= s0_setup/01_top
PROJ   ?= *_proj

.PHONY: list run check clean

list:
	@find . -name run_hls.tcl -printf '%h\n' | sed 's|^\./||' | sort

run:
	cd $(LESSON) && vitis_hls -f run_hls.tcl 2>&1 | tee run.log

check:
	@cd $(LESSON) && for p in $(PROJ); do \
	    echo "== $$p"; \
	    bash ../../common/collect_latency.sh $$p; \
	    echo; \
	    bash ../../common/collect_resources.sh $$p; \
	done

clean:
	cd $(LESSON) && rm -rf $(PROJ) run.log vitis_hls.log *.tmp