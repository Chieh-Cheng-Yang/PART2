# Verdi play script used by "make waves_verdi TEST=all".
# Deliverable 5.1: complete pipeline flow of a load, lw $12, 4($0) at pc 0x54.
# Event window: about 210 ns to 290 ns. Data in decimal, pc/instructions in hex.
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"Fetch" \
{/MIPS_Testbench/clk} \
{/MIPS_Testbench/dut/pc} \
{/MIPS_Testbench/dut/instr} \
}
wvAddSignal -win $_nWave2 -group {"Decode" \
{/MIPS_Testbench/dut/mips/dp/instrD} \
{/MIPS_Testbench/dut/mips/dp/rsD} \
{/MIPS_Testbench/dut/mips/dp/rtD} \
{/MIPS_Testbench/dut/mips/dp/signimmD} \
}
wvAddSignal -win $_nWave2 -group {"Execute" \
{/MIPS_Testbench/dut/mips/dp/srcaE} \
{/MIPS_Testbench/dut/mips/dp/srcbE} \
{/MIPS_Testbench/dut/mips/dp/aluoutE} \
{/MIPS_Testbench/dut/mips/dp/writeregE} \
}
wvAddSignal -win $_nWave2 -group {"Memory" \
{/MIPS_Testbench/dut/mips/dp/aluoutM} \
{/MIPS_Testbench/dut/readdata} \
{/MIPS_Testbench/dut/mips/dp/memtoregM} \
}
wvAddSignal -win $_nWave2 -group {"Writeback" \
{/MIPS_Testbench/dut/mips/dp/readdataW} \
{/MIPS_Testbench/dut/mips/dp/memtoregW} \
{/MIPS_Testbench/dut/mips/dp/resultW} \
{/MIPS_Testbench/dut/mips/dp/writeregW} \
{/MIPS_Testbench/dut/mips/dp/regwriteW} \
}
wvSelectSignal -win $_nWave2 {( "Decode" 2 3 4 )} {( "Execute" 1 2 3 4 )} {( "Memory" 1 2 )} {( "Writeback" 1 3 4 )}
wvSetRadix -win $_nWave2 -format UDec
wvSelectSignal -win $_nWave2 {( "Fetch" 1 )}
wvZoomAll -win $_nWave2