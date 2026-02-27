`timescale 1ns / 1ps

interface rx_interface (
    input clk
);

    logic       clk;
    logic       reset;
    logic       rx;
    logic       b_tick;
    logic [7:0] rx_data;
    logic       rx_done;

endinterface  //rx_interface

class transaction;


    function new();
        
    endfunction //new()
endclass //transaction

module tb_uart_rx ();

    logic clk = 0;
    rx_interface rx_if (clk);
    uart_rx dut (
        .clk(clk),
        .reset(rx_if.reset),
        .rx(rx_if.rx),
        .b_tick(rx_if.b_tick),
        .rx_data(rx_if.rx_data),
        .rx_done(rx_if.rx_done)
    );

    always #5 clk = ~clk;

    initial begin

    end
endmodule
