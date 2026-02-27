`timescale 1ns / 1ps


module uart_tx (
    input        clk,
    input        reset,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       uart_tx,
    output       tx_busy,
    output       tx_done
);

    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;


    // state reg
    reg [1:0] current_state, next_state;
    reg tx_reg, tx_next;
    //bit_cnt
    reg [2:0]
        bit_cnt_reg,
        bit_cnt_next; // 이전단계에서 next와 current형식으로 동작했기때문에 똑같이 

    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;  // 16배속한 tick검출 

    reg [7:0] data_in_buf_reg, data_in_buf_next;
    assign uart_tx = tx_reg;  //  for output CL=> SL
    //busy,done
    reg busy_reg, busy_next, done_reg, done_next;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    //state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state   <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 1'b0;
            b_tick_cnt_reg  <= 4'h0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;

        end else begin
            current_state   <= next_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        next_state       = current_state;
        tx_next          = tx_reg;  // ratch발생예방
        bit_cnt_next     = bit_cnt_reg;
        busy_next        = busy_reg;
        done_next        = 1'b0;
        data_in_buf_next = data_in_buf_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        case (current_state)
            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next       = 1'b0;
                done_next       = 1'b0;
                if (tx_start) begin
                    next_state       = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end

            end
            START: begin
                // to start uart frame of start bit
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'h0;
                        next_state = DATA;
                    end else begin

                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 4'h0;
                            next_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            next_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                bit_cnt_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin

                        done_next  = 1'b1;
                        next_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
