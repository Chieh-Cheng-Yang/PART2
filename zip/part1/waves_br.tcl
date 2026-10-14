# Verdi play script used by "make waves_verdi TEST=br".
# Deliverable 5.3: BEQ sequence with flushing (control hazards).
#   loop exit (beq at 0x0c taken) + taken beq at 0x24 : about 290 ns to 370 ns
#   beq at 0x3c using comparator forwarding           : about 395 ns to 425 ns
# A flush shows as flushD = 1, then instrD = 00000000 (bubble) next cycle.
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"Fetch" \
{/MIPS_Testbench/clk} \
{/MIPS_Testbench/dut/pc} \
{/MIPS_Testbench/dut/instr} \
}
wvAddSignal -win $_nWave2 -group {"Decode / branch" \
{/MIPS_Testbench/dut/mips/dp/instrD} \
{/MIPS_Testbench/dut/mips/dp/branchD} \
{/MIPS_Testbench/dut/mips/dp/jumpD} \
{/MIPS_Testbench/dut/mips/dp/cmpaD} \
{/MIPS_Testbench/dut/mips/dp/cmpbD} \
{/MIPS_Testbench/dut/mips/dp/equalD} \
{/MIPS_Testbench/dut/mips/dp/pcsrcD} \
{/MIPS_Testbench/dut/mips/dp/pcbranchD} \
}
wvAddSignal -win $_nWave2 -group {"Flush / stall" \
{/MIPS_Testbench/dut/mips/dp/flushD} \
{/MIPS_Testbench/dut/mips/dp/stallD} \
{/MIPS_Testbench/dut/mips/dp/branchstallD} \
{/MIPS_Testbench/dut/mips/dp/forwardaD} \
{/MIPS_Testbench/dut/mips/dp/forwardbD} \
}
wvAddSignal -win $_nWave2 -group {"Memory writes" \
{/MIPS_Testbench/memwrite} \
{/MIPS_Testbench/dataadr} \
{/MIPS_Testbench/writedata} \
}
wvSelectSignal -win $_nWave2 {( "Decode / branch" 4 5 )} {( "Memory writes" 2 3 )}
wvSetRadix -win $_nWave2 -format UDec
wvSelectSignal -win $_nWave2 {( "Fetch" 1 )}
wvZoomAll -win $_nWave2