`timescale 1ns / 1ps

module uart_top (
    input clk,
    input reset,
    input uart_rx,
    output uart_tx


);

    wire w_b_tick;
    wire [7:0] w_rx_data;
    assign uart_data = w_rx_data;

    wire [7:0] w_tx_fifo_pop_data, w_rx_fifo_pop_data;
    wire w_tx_fifo_full, w_rx_fifo_full, w_tx_busy, w_tx_fifo_empty,w_rx_fifo_empty;
    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );
    fifo U_FIFO_RX (

        .clk(clk),
        .reset(reset),
        .push(w_rx_done),
        .pop(~w_tx_fifo_full),
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_pop_data),
        .full(),
        .empty(w_rx_fifo_empty)

    );


    fifo U_FIFO_TX (

        .clk(clk),
        .reset(reset),
        .push(~w_rx_fifo_empty),
        .pop(~w_tx_busy),
        .push_data(w_rx_fifo_pop_data),
        .pop_data(w_tx_fifo_pop_data),
        .full(w_tx_fifo_full),
        .empty(w_tx_fifo_empty)

    );

    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .tx_start(~w_tx_fifo_empty),
        .b_tick(w_b_tick),
        .tx_data(w_tx_fifo_pop_data),
        .uart_tx(uart_tx),
        .tx_busy(w_tx_busy),
        .tx_done()
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .reset(reset),
        .b_tick(w_b_tick)
    );


endmodule

module baud_tick (
    input      clk,
    input      reset,
    output reg b_tick
);
    parameter BAUDRATE = 9600 * 16;
    parameter F_count = 100_000_000 / BAUDRATE;
    reg [$clog2(F_count)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            if (counter_reg == (F_count - 1)) begin
                counter_reg <= 0;
                b_tick      <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1'b1;
                b_tick <= 1'b0;
            end
        end
    end
endmodule
