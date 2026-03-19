`timescale 1ns / 1ps

module ram (

    input  logic       clk,
    input  logic       we,
    input  logic [7:0] addr,
    input  logic [7:0] wdata,
    output logic [7:0] rdata

);

    logic [7:0] mem[0:2**8-1];

    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end else begin
            rdata <= mem[addr];
        end
    end
endmodule
