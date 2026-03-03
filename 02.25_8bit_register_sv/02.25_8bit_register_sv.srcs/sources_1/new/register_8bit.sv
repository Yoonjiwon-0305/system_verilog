`timescale 1ns / 1ps

module register_8bit (

    input              clk,
    input              reset,
    input              we,
    input  logic [7:0] wdata,
    output logic [7:0] rdata
);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            rdata <= 0;
        end else begin
            if (we) begin
                rdata <= wdata;
            end
        end
    end
endmodule
