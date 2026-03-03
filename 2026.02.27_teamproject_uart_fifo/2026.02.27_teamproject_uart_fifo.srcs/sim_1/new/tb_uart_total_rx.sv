`timescale 1ns / 1ps

interface total_rx_interface (
    input clk
);
    logic       reset;
    logic       rx;
    logic       pop;
    logic [7:0] pop_data;
    logic       full;
    logic       empty;
    logic       b_tick;
endinterface

class transaction;
    rand bit [7:0] in_rx_data;
    bit [7:0] expected_data;
    logic [7:0] pop_data;

    function void display(string name);
        $display("%t : [%s] in_rx_data = %2h, pop_data = %2h", $time, name,
                 in_rx_data, pop_data);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int count);
        repeat (count) begin
            tr = new();
            if (!tr.randomize()) $error("Randomization failed");
            gen2drv_mbox.put(tr);
            @(gen_next_ev);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual total_rx_interface rx_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual total_rx_interface rx_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.rx_if        = rx_if;
    endfunction

    task preset();
        rx_if.rx <= 1'b1;
        rx_if.reset <= 1'b1;
        repeat (5) @(posedge rx_if.clk);
        rx_if.reset <= 1'b0;
        @(posedge rx_if.clk);
    endtask

    task put_data(bit [7:0] data);
        rx_if.rx <= 1'b0;  // Start bit
        repeat (16) @(posedge rx_if.clk) wait (rx_if.b_tick);

        for (int i = 0; i < 8; i++) begin
            rx_if.rx <= data[i]; 
            repeat (16) @(posedge rx_if.clk) wait (rx_if.b_tick);
        end

        rx_if.rx <= 1'b1;  // Stop bit
        repeat (16) @(posedge rx_if.clk) wait (rx_if.b_tick);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            put_data(tr.in_rx_data);
        end
    endtask
endclass

class monitor;
    transaction tr;
    virtual total_rx_interface rx_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual total_rx_interface rx_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.rx_if = rx_if;
    endfunction

    task run();
        forever begin
            tr = new();
            wait (rx_if.rx == 1'b0 && rx_if.b_tick);

            repeat (8) begin
                @(posedge rx_if.clk);
                wait (rx_if.b_tick);
            end

            for (int i = 0; i < 8; i++) begin
                repeat (16) begin
                    @(posedge rx_if.clk);
                    wait (rx_if.b_tick);
                end
                tr.expected_data[i] = rx_if.rx;
            end

            wait (rx_if.empty == 1'b0);

            rx_if.pop <= 1'b1;
            @(posedge rx_if.clk);
            tr.pop_data = rx_if.pop_data;

            mon2scb_mbox.put(tr);

            rx_if.pop <= 1'b0;
            @(posedge rx_if.clk);

            tr.display("mon");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    int pass_cnt, fail_cnt, total_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            total_cnt++;
            // tr.rx_in_data를 tr.expected_data로 수정 (모니터 샘플링 값과 비교)
            if (tr.expected_data == tr.pop_data) begin
                $display("PASS");
                pass_cnt++;
            end else begin
                $display("FAIL: Exp=%h, Act=%h", tr.expected_data, tr.pop_data);
                fail_cnt++;
            end

            ->gen_next_ev;
        end
    endtask
endclass

class environment;
    generator                  gen;
    driver                     drv;
    monitor                    mon;
    scoreboard                 scb;
    mailbox #(transaction)     gen2drv_mbox;
    mailbox #(transaction)     mon2scb_mbox;
    event                      gen_next_ev;
    virtual total_rx_interface rx_if;

    function new(virtual total_rx_interface rx_if);
        this.rx_if = rx_if;
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, rx_if);
        mon = new(mon2scb_mbox, rx_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run(int count);
        drv.preset();

        fork
            gen.run(count);
            drv.run();
            mon.run();
            scb.run();
        join_any

        #1000;
        $display("_______________________________");
        $display("** UART RX Verification **");
        $display("*******************************");
        // scb.total_cnt로 경로 지정
        $display("** total try count = %3d     **", scb.total_cnt);
        $display("** pass count = %3d          **", scb.pass_cnt);
        $display("** fail count = %3d          **", scb.fail_cnt);
        $display("*******************************");
        $finish;
    endtask
endclass

module tb_total_rx ();
    logic clk = 0;
    total_rx_interface rx_if (clk);
    environment env;

    total_uart_rx dut (
        .clk(clk),
        .reset(rx_if.reset),
        .rx_in(rx_if.rx),
        .pop(rx_if.pop),
        .pop_data(rx_if.pop_data),
        .full(rx_if.full),
        .empty(rx_if.empty)
    );

    assign rx_if.b_tick = dut.U_UART_RX.b_tick;

    always #5 clk = ~clk;

    initial begin
        $timeformat(-9, 3, "ns");
        env = new(rx_if);
        env.run(10);
    end
endmodule