CEN 571 - Lab 2 Part II
=======================

Authors:
You Lun Lan
Chieh Cheng Yang


Overview
--------
This project extends the pipelined MIPS processor with two custom
features:

1. MULADD instruction
2. Performance Monitor (PERFMON)


MULADD
------
Syntax:

    muladd rd, rs, rt

Operation:

    rd = rs * rt + rd_old

MULADD uses three register operands. A third register-file read
port was added to read the original value of rd. Data dependencies
for MULADD are handled by stalling the pipeline.


PERFMON
-------
Syntax:

    perfmon <register>, <flag>

    flag = 0 : Read cycle counter
    flag = 1 : Read instruction counter

The selected counter value is written to the specified register.


Simulation
----------
The design was compiled and simulated using Synopsys VCS and
waveforms were viewed using Synopsys Verdi.

To compile and run:

    cd sim
    make compile_and_sim

To generate the Verdi database:

    make compile_verdi

To run the simulation:

    make sim

To open the waveform in Verdi:

    make waves_verdi


Expected Test Results
---------------------
A successful simulation should report:

    MULADD PASS: result=29 cycle=18
    PERFMON CYCLE PASS: result=19 cycle=23
    PERFMON INSTRUCTION PASS: result=7 cycle=24
    PART 2 TEST PASS: MULADD and PERFMON verified
