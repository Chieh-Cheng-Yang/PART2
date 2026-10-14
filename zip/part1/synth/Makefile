# Synthesis with Design Compiler (same command as the Lab 0 package:
# dc_shell-t -f <script>). Each run uses its own directory so the reports
# (timing.rep, area.rep, area_hier.rep, qor.rep, power.rep, cell.rep) and
# synth.log do not overwrite each other.
#   make orig    original single-cycle design      -> run_orig/   (compile_orig.tcl)
#   make pipe    pipelined design                  -> run_pipe/   (compile_pipe.tcl)
#   make sram    pipelined design with SRAM macros -> run_sram/   (compile_with_sram.tcl)
#   make all     all three
DC ?= dc_shell-t

.PHONY: orig pipe sram all clean
orig:
	rm -rf run_orig && mkdir run_orig && cd run_orig && $(DC) -f ../compile_orig.tcl | tee synth.log
pipe:
	rm -rf run_pipe && mkdir run_pipe && cd run_pipe && $(DC) -f ../compile_pipe.tcl | tee synth.log
sram:
	rm -rf run_sram && mkdir run_sram && cd run_sram && $(DC) -f ../compile_with_sram.tcl | tee synth.log
all: orig pipe sram
clean:
	rm -rf run_orig run_pipe run_sram