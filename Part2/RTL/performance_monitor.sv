`timescale 1ns/1ps
module performance_monitor (
    input  logic        clk,
    input  logic        reset,
    input  logic        instruction_finished,

    output logic [31:0] cycle_count,
    output logic [31:0] instruction_count
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count       <= 32'b0;
            instruction_count <= 32'b0;
        end
        else begin
            cycle_count <= cycle_count + 32'd1;

            if (instruction_finished)
                instruction_count <= instruction_count + 32'd1;
        end
    end

endmodule
