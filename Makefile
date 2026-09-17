# ======================================================================
# hls-exercises — root Makefile
#
#   make list                 show every exercise found
#   make run EX=<dir>         run one exercise
#   make check                dry run: list what clean would delete
#   make clean                delete all generated tool output
#   make clean EX=<dir>       delete generated output for one exercise
#   make clean PROJ='<glob>'   narrow to matching project dirs (quote it)
#
# Generated output is anything the tool creates. Hand-written sources
# (*.cpp, *.tcl, README.md, params.json) and everything under notes/
# and common/ are never touched.
# ======================================================================

SHELL := /bin/bash

HLS   ?= vitis_hls
PROJ  ?= *_proj
EX    ?=

# Any directory holding a run_hls.tcl is an exercise.
ALL_EXERCISES := $(sort $(patsubst %/run_hls.tcl,%,$(wildcard s*/*/run_hls.tcl)))

# EX=<dir> narrows every target to one exercise; unset means the whole repo.
ifeq ($(strip $(EX)),)
  SCOPE := .
else
  SCOPE := $(patsubst %/,%,$(EX))
endif

# --- what counts as junk ----------------------------------------------
# Directories Vitis generates: any *_proj project dir, plus strays it
# drops in the working directory (cosim and export add most of these).
JUNK_DIRS  := $(PROJ) .Xil xsim.dir .crash_reporter .ipcache
# Files Vitis generates.
JUNK_FILES := vitis_hls.log vivado_hls.log run.log run_*.log *.jou *.str *.wdb *.wcfg \
              *.pb hs_err_pid*.log .crash_report.log

# Build the -name clauses.
DIR_CLAUSE := $(patsubst %,-name '%' -o,$(JUNK_DIRS)) -false
FILE_CLAUSE := $(patsubst %,-name '%' -o,$(JUNK_FILES)) -false

# Never descend into these.
KEEP_CLAUSE := -name notes -o -name .git -o -name common

# Matched directories are pruned so find does not try to descend into
# something rm has already removed.
MATCH := \( -type d \( $(DIR_CLAUSE) \) -prune \) -o \( -type f \( $(FILE_CLAUSE) \) \)

FIND_JUNK = find $(SCOPE) \( $(KEEP_CLAUSE) \) -prune -o \( $(MATCH) \)

.PHONY: help list run check clean
.DEFAULT_GOAL := help

help:
	@echo "targets: list | run EX=<dir> | check [EX=<dir>] | clean [EX=<dir>]"
	@echo "vars:    HLS=$(HLS)  PROJ=$(PROJ)"
	@echo "$(words $(ALL_EXERCISES)) exercise(s) found; 'make list' to see them."

list:
	@for e in $(ALL_EXERCISES); do echo "  $$e"; done

run:
	@if [ -z "$(strip $(EX))" ]; then \
	  echo "run needs one exercise: make run EX=s0_flow/01_project_anatomy"; exit 1; fi
	@if [ ! -f "$(SCOPE)/run_hls.tcl" ]; then \
	  echo "no run_hls.tcl in $(SCOPE)"; exit 1; fi
	cd $(SCOPE) && $(HLS) -f run_hls.tcl 2>&1 | tee run.log

# Dry run. Worth doing once after any change to the repo layout.
check:
	@echo "clean would delete, under '$(SCOPE)':"
	@$(FIND_JUNK) -print | sed 's/^/  /' || true
	@echo "(notes/, common/ and .git/ are never touched)"

clean:
	@$(FIND_JUNK) -exec rm -rf {} + 2>/dev/null || true
	@echo "cleaned: $(SCOPE)"