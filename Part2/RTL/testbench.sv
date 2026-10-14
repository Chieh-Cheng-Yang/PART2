`timescale 1ns/1ps

module MIPS_Testbench;

    logic clk = 1'b0;
    logic reset = 1'b1;

    logic [31:0] writedata, dataadr;
    logic memwrite;

    localparam int MAX_CYCLES = 500;

    int write_count = 0;
    int cycle_count = 0;

    top dut (
        .clk(clk),
        .reset(reset),
        .writedata(writedata),
        .dataadr(dataadr),
        .memwrite(memwrite)
    );

    // Clock period: 10 ns
    always #5 clk = ~clk;

    initial begin
        repeat (2) @(negedge clk);
        reset = 1'b0;
    end

    // Record waveforms
    initial begin
	    $fsdbDumpfile("novas.fsdb");
	    $fsdbDumpvars(0, MIPS_Testbench);
	end

    always @(posedge clk) begin
        if (!reset) begin
            cycle_count = cycle_count + 1;

            if (memwrite === 1'b1) begin
                write_count = write_count + 1;

                case (write_count)

    // ============================================================
    // MULADD
    // $1 = 3*4+5 = 17
    // $1 = 3*4+17 = 29
    // ============================================================
    1: begin
        if (dataadr !== 32'd0 ||
            writedata !== 32'd29)
            $fatal(1,
                "MULADD FAILED: data=%0d addr=%0d; expected data=29 addr=0",
                writedata, dataadr
            );

        $display(
            "MULADD PASS: result=%0d cycle=%0d",
            writedata, cycle_count
        );
    end


    // ============================================================
    // PERFMON flag = 0
    // Read cycle counter
    // ============================================================
    2: begin
        if (dataadr !== 32'd4 ||
            writedata !== 32'd19)
            $fatal(1,
                "PERFMON CYCLE FAILED: data=%0d addr=%0d; expected data=19 addr=4",
                writedata, dataadr
            );

        $display(
            "PERFMON CYCLE PASS: result=%0d cycle=%0d",
            writedata, cycle_count
        );
    end


    // ============================================================
    // PERFMON flag = 1
    // Read instruction counter
    // ============================================================
    3: begin
        if (dataadr !== 32'd8 ||
            writedata !== 32'd7)
            $fatal(1,
                "PERFMON INSTRUCTION FAILED: data=%0d addr=%0d; expected data=7 addr=8",
                writedata, dataadr
            );

        $display(
            "PERFMON INSTRUCTION PASS: result=%0d cycle=%0d",
            writedata, cycle_count
        );

        #1;
        $display("PART 2 TEST PASS: MULADD and PERFMON verified");
        $finish;
    end


    default:
        $fatal(1, "Unexpected additional memory write");

endcase

            end else if (memwrite !== 1'b0) begin
                $fatal(1, "memwrite is unknown");
            end

            if (cycle_count >= MAX_CYCLES)
                $fatal(1,
                    "TIMEOUT: only %0d writes observed",
                    write_count
                );
        end
    end

endmodule
