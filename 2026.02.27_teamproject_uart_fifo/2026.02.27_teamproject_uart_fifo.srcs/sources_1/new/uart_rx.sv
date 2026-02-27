module uart_rx (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    input  logic       b_tick,
    output logic [7:0] rx_data,
    output logic       rx_done

);
    logic [1:0] current_state, next_state;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [2:0] bit_cnt_next, bit_cnt_reg;
    logic done_reg, done_next;
    logic [7:0] buf_reg, buf_next;

    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state  <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            done_reg       <= 0;
            buf_reg        <= 0;
        end else begin
            current_state  <= next_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    // next, output
    always @(*) begin
        next_state      = current_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                b_tick_cnt_next = 5'b0;
                bit_cnt_next = 3'b0;
                if (b_tick & !rx) begin
                    next_state = START;
                end
            end
            START: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        next_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            next_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end
            STOP: begin

                if (b_tick)
                    if (b_tick_cnt_reg == 15) begin
                        next_state = IDLE;
                        done_next  = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end

        endcase
    end




endmodule
