`timescale 1ns / 1ps

//8bit adder 'logic' 사용

module adder (

    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        mode,
    output logic [31:0] s,
    output logic        c

);
    //ALU
    assign {c, s} = (mode) ? a - b : a + b;

endmodule
