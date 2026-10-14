# Verdi play script used by "make waves_verdi TEST=fwd".
# Deliverable 5.2: ADD sequence with forwarding (data hazards).
#   pc 0x08-0x14 back-to-back adds : about 40 ns to 140 ns
#   lw $13 -> add $14 (load-use)   : about 165 ns to 215 ns
# forwardaE / forwardbE: 0 = register file, 1 = ResultW (WB), 2 = ALUOutM (MEM)
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"Pipeline" \
{/MIPS_Testbench/clk} \
{/MIPS_Testbench/dut/pc} \
{/MIPS_Testbench/dut/mips/dp/instrD} \
}
wvAddSignal -win $_nWave2 -group {"Execute operands" \
{/MIPS_Testbench/dut/mips/dp/rsE} \
{/MIPS_Testbench/dut/mips/dp/rtE} \
{/MIPS_Testbench/dut/mips/dp/rd1E} \
{/MIPS_Testbench/dut/mips/dp/rd2E} \
}
wvAddSignal -win $_nWave2 -group {"Forwarding control" \
{/MIPS_Testbench/dut/mips/dp/writeregM} \
{/MIPS_Testbench/dut/mips/dp/regwriteM} \
{/MIPS_Testbench/dut/mips/dp/writeregW} \
{/MIPS_Testbench/dut/mips/dp/regwriteW} \
{/MIPS_Testbench/dut/mips/dp/forwardaE} \
{/MIPS_Testbench/dut/mips/dp/forwardbE} \
}
wvAddSignal -win $_nWave2 -group {"Forwarded values" \
{/MIPS_Testbench/dut/mips/dp/aluoutM} \
{/MIPS_Testbench/dut/mips/dp/resultW} \
{/MIPS_Testbench/dut/mips/dp/srcaE} \
{/MIPS_Testbench/dut/mips/dp/srcbE} \
{/MIPS_Testbench/dut/mips/dp/aluoutE} \
}
wvAddSignal -win $_nWave2 -group {"Load-use stall" \
{/MIPS_Testbench/dut/mips/dp/lwstallD} \
{/MIPS_Testbench/dut/mips/dp/stallF} \
{/MIPS_Testbench/dut/mips/dp/stallD} \
{/MIPS_Testbench/dut/mips/dp/flushE} \
}
wvSelectSignal -win $_nWave2 {( "Execute operands" 1 2 3 4 )} {( "Forwarding control" 1 3 5 6 )} {( "Forwarded values" 1 2 3 4 5 )}
wvSetRadix -win $_nWave2 -format UDec
wvSelectSignal -win $_nWave2 {( "Pipeline" 1 )}
wvZoomAll -win $_nWave2