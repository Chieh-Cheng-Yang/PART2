# Lab 2 Part 1 - pipelined MIPS
#   make test TEST=all            run one program (all | fwd | br | orig) on the pipelined design
#   make regress                  run all four programs, print a pass/fail summary
#   make ipc                      forwarding and flushing IPC comparisons for the report
#   make single TEST=all          run a program on the ORIGINAL single-cycle design (original/*.v)
#   make wave TEST=fwd            run with a VCD dump (waveform.vcd)
#   SIM=iverilog                  use Icarus Verilog instead of VCS
#   DEFS="+define+NO_FORWARDING"  extra defines (NO_FORWARDING, BRANCH_STALL, DUMP, FSDB)

SIM   ?= vcs
TEST  ?= all
DEFS  ?=
RTL    = top.sv controller.sv datapath.sv
ORIG   = original/top.v original/controller.v original/datapath.v
TB     = testbench.sv
TDEF   = $(if $(filter all,$(TEST)),,+define+TEST_$(shell echo $(TEST) | tr a-z A-Z))

ifeq ($(SIM),iverilog)
  RUN = iverilog -g2012 -o simv.out $(subst +define+,-D,$(TDEF) $(DEFS)) $(1) && vvp -n simv.out
else
  RUN = vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -q $(TDEF) $(DEFS) $(1) -o simv -l compile.log && ./simv -q
endif

.PHONY: test single _single wave regress ipc clean

test:
	cp tests/memfile_$(TEST).dat memfile.dat
	$(call RUN,$(TB) $(RTL))

single:
	cp tests/memfile_$(TEST).dat memfile.dat
	$(MAKE) -s _single TEST=$(TEST) DEFS="$(DEFS) +define+SINGLE_CYCLE"

_single:
	$(call RUN,$(TB) $(ORIG))

wave:
	$(MAKE) test TEST=$(TEST) DEFS="$(DEFS) +define+DUMP"

# Verdi: FSDB dump (needs -kdb), then open nWave with the matching play script
waves_verdi:
	cp tests/memfile_$(TEST).dat memfile.dat
	vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -q +define+FSDB $(TDEF) $(DEFS) $(TB) $(RTL) -o simv -l compile.log
	./simv -q -no_save
	verdi -ssf waveform.fsdb -play waves_$(TEST).tcl &

regress:
	@for t in all fwd br orig; do \
	  $(MAKE) -s test TEST=$$t > log_$$t.txt 2>&1; \
	  printf "%-5s : " $$t; grep -E "TEST (PASSED|FAILED)" log_$$t.txt || echo "DID NOT RUN (see log_$$t.txt)"; \
	done
	@cp tests/memfile_all.dat memfile.dat

ipc:
	@echo "=== ADD forwarding (fwd program) ==="
	@$(MAKE) -s test TEST=fwd                                | grep -E "Design|Cycles|CPI|Stall|TEST (P|F)"
	@$(MAKE) -s test TEST=fwd DEFS="+define+NO_FORWARDING"   | grep -E "Design|Cycles|CPI|Stall|TEST (P|F)"
	@echo "=== BEQ flushing (br program) ==="
	@$(MAKE) -s test TEST=br                                 | grep -E "Design|Cycles|CPI|Branches|TEST (P|F)"
	@$(MAKE) -s test TEST=br DEFS="+define+BRANCH_STALL"     | grep -E "Design|Cycles|CPI|Branches|TEST (P|F)"
	@echo "=== single-cycle vs pipelined (all program) ==="
	@$(MAKE) -s single TEST=all                              | grep -E "Design|Cycles|CPI|TEST (P|F)"
	@$(MAKE) -s test TEST=all                                | grep -E "Design|Cycles|CPI|TEST (P|F)"
	@cp tests/memfile_all.dat memfile.dat

clean:
	rm -rf simv simv.daidir csrc simv.out ucli.key compile.log compile_verdi.log log_*.txt *.vcd *.fsdb \
	       DVEFiles vcdplus.vpd novas.conf novas.rc novas.log novas_dump.log verdi_config_file verdiLog