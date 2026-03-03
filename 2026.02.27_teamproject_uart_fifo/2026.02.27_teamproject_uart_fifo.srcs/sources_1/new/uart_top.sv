`timescale 1ns / 1ps

module uart_top (
    input  clk,
    input  reset,
    input  uart_rx,
    output uart_tx,
    output b_tick // 외부 검증용 포트 추가
);
    wire [7:0] w_rx_pop_data;
    wire w_rx_tx_empty;
    wire w_tx_rx_full;
    wire w_b_tick; // 내부 연결용

    // TX 모듈에서 나오는 b_tick을 최상위 포트로 연결
    assign b_tick = w_b_tick;

    total_uart_rx U_TOTAL_RX (
        .clk(clk),
        .reset(reset),
        .rx_in(uart_rx),
        .pop(~w_rx_tx_empty && ~w_tx_rx_full), 
        .pop_data(w_rx_pop_data),
        .full(),
        .empty(w_rx_tx_empty)
    );

    total_uart_tx U_TOTAL_TX (
        .clk(clk),
        .reset(reset),
        .push_data(w_rx_pop_data),
        .push(~w_rx_tx_empty), 
        .full(w_tx_rx_full),
        .b_tick(w_b_tick), // TX 내부의 b_tick을 받아옴
        .uart_tx(uart_tx)
    );
endmodule

// total_uart_rx와 baud_tick 모듈은 구조를 유지하되, 
// 검증 시 b_tick을 공유해야 하므로 total_uart_tx의 b_tick을 메인으로 사용합니다.
module total_uart_rx (
    input  logic clk,
    input  logic reset,
    input  logic rx_in,
    input  logic pop,
    output logic [7:0] pop_data, 
    output logic full,
    output logic empty
);
    wire [7:0] w_rx_data;
    wire w_rx_done;

    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx_in(rx_in),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    fifo U_FIFO_RX (
        .clk(clk),
        .reset(reset),
        .push(w_rx_done),
        .pop(pop), 
        .push_data(w_rx_data),
        .pop_data(pop_data),
        .full(full),
        .empty(empty)
    );
endmodule

module total_uart_tx (
    input  logic clk,
    input  logic reset,
    input  logic [7:0] push_data, 
    input  logic push,
    output logic full,
    output logic b_tick,    
    output logic uart_tx
);
    wire [7:0] w_tx_fifo_pop_data;
    wire w_tx_busy, w_tx_fifo_empty, w_tx_done;

    fifo U_FIFO_TX (
        .clk(clk),
        .reset(reset),
        .push(push), 
        .pop(w_tx_done), 
        .push_data(push_data),
        .pop_data(w_tx_fifo_pop_data),
        .full(full),
        .empty(w_tx_fifo_empty)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .tx_start(~w_tx_fifo_empty && ~w_tx_busy),
        .tx_data(w_tx_fifo_pop_data),
        .uart_tx(uart_tx),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .b_tick(b_tick)    
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

    always @(posedge clk or posedge reset) begin
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