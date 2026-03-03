`timescale 1ns / 1ps

module adder (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        mode,
    output logic [31:0] s,
    output logic        c
);
    //alu
    assign {c, s} = (mode) ? (a - b) : (a + b);

endmodule
