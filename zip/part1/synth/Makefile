# Synthesis (Design Compiler). Each run uses its own directory so the
# reports (timing.rep, area.rep, area_hier.rep, qor.rep, power.rep,
# cell.rep) and dc.log do not overwrite each other.
#   make orig    original single-cycle design      -> run_orig/
#   make pipe    pipelined design                  -> run_pipe/
#   make sram    pipelined design with SRAM macros -> run_sram/
#   make all     all three
DC ?= dc_shell

.PHONY: orig pipe sram all clean
orig:
	rm -rf run_orig && mkdir run_orig && cd run_orig && $(DC) -f ../compile_orig.tcl | tee dc.log
pipe:
	rm -rf run_pipe && mkdir run_pipe && cd run_pipe && $(DC) -f ../compile_pipe.tcl | tee dc.log
sram:
	rm -rf run_sram && mkdir run_sram && cd run_sram && $(DC) -f ../compile_with_sram.tcl | tee dc.log
all: orig pipe sram
clean:
	rm -rf run_orig run_pipe run_sram
