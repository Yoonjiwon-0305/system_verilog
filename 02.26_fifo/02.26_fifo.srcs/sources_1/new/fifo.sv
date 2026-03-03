`timescale 1ns / 1ps

module fifo (
    input  logic       clk,
    input  logic       reset,
    input  logic       push,
    input  logic       pop,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    logic [3:0] w_wptr_waddr, w_rptr_raddr;

    register_file U_REGISTER_FILE (

        .clk(clk),
        .wdata(wdata),
        .waddr(w_wptr_waddr),
        .raddr(w_rptr_raddr),
        .we(push & (~full)),
        .rdata(rdata)
    );

    control_unit U_CONTROL_UNIT (
        .clk  (clk),
        .reset(reset),
        .pop  (pop),
        .push (push),
        .wptr (w_wptr_waddr),
        .rptr (w_rptr_raddr),
        .full (full),
        .empty(empty)
    );


endmodule

module register_file (

    input  logic       clk,
    input  logic [7:0] wdata,
    input  logic [3:0] waddr,
    input  logic [3:0] raddr,
    input  logic       we,
    output logic [7:0] rdata
);

    logic [7:0] register_file[0:15];

    always_ff @(posedge clk) begin
        if (we) begin
            register_file[waddr] <= wdata;
        end
    end

    assign rdata = register_file[raddr];
endmodule


module control_unit (
    input  logic       clk,
    input  logic       reset,
    input  logic       pop,
    input  logic       push,
    output logic [3:0] wptr,
    output logic [3:0] rptr,
    output logic       full,
    output logic       empty
);


    logic [3:0] wptr_reg, wptr_next, rptr_reg, rptr_next;
    logic full_reg, full_next, empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 0;
            empty_reg <= 1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end

    end

    always_comb begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({
            push, pop
        })

            //push
            2'b10: begin
                if (!full) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end
                if (wptr_next == rptr_reg) begin
                    full_next = 1'b1;
                end

            end

            //pop
            2'b01: begin
                if (!empty) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end
                if (rptr_next == wptr_reg) begin
                    empty_next = 1'b1;
                end

            end

            //push,pop
            2'b11: begin
                if (full_reg == 1'b1) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg == 1'b1) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end

            end

        endcase
    end
endmodule
