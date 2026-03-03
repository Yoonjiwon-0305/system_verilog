`timescale 1ns / 1ps

interface tx_interface (
    input clk
);
    logic       reset;
    logic [7:0] push_data;
    logic       push;
    logic       full;
    logic       uart_tx;
    logic       b_tick;
endinterface

class transaction;
    rand bit [7:0] push_data;
    rand bit push;
    bit full;
    bit uart_tx;
    bit [7:0] compare_data;
    bit ex_uart_done;

    constraint c_push {
        push dist {
            1 := 80,
            0 := 20
        };
    }
    function void display(string name);
        $display("%t : [%s] data=%2h, push=%b, full=%b, done=%b", $time, name,
                 push_data, push, full, ex_uart_done);
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

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual tx_interface tx_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual tx_interface tx_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.tx_if = tx_if;
    endfunction

    task preset();
        tx_if.push_data <= 0;
        tx_if.reset <= 1'b1;
        repeat (2) @(posedge tx_if.clk);
        tx_if.reset <= 1'b0;
        @(posedge tx_if.clk);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);

            if (tx_if.full) begin
                wait (tx_if.full == 1'b0);
            end

            @(posedge tx_if.clk);
            #1;
            if (tr.push) begin
                tx_if.push      <= 1'b1;
                tx_if.push_data <= tr.push_data;
            end else begin
                tx_if.push <= 1'b0;  
            end

            @(posedge tx_if.clk);
            tx_if.push <= 1'b0;
            tr.display("drv");
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual tx_interface tx_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual tx_interface tx_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.tx_if = tx_if;
    endfunction

    task run();
        fork
            // fifo
            forever begin
                @(posedge tx_if.clk);
                if (tx_if.push && !tx_if.full) begin
                    tr = new();
                    tr.push = 1;
                    tr.push_data = tx_if.push_data;
                    mon2scb_mbox.put(tr);
                    tr.display("mon");
                end
            end
            //uart_tx
            forever begin
                logic [7:0] in_data;
                wait (tx_if.uart_tx == 0);
                repeat (8) @(posedge tx_if.b_tick);
                for (int i = 0; i < 8; i++) begin
                    repeat (16) @(posedge tx_if.b_tick);
                    in_data[i] = tx_if.uart_tx;
                end
                repeat (16) @(posedge tx_if.b_tick);
                tr = new();
                tr.ex_uart_done = 1;
                tr.compare_data = in_data;
                mon2scb_mbox.put(tr);
                wait (tx_if.uart_tx == 1);
                 tr.display("mon");
            end
        join
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    int pass_cnt = 0, fail_cnt = 0, try_cnt = 0;
    logic [7:0] queue[$:7];
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");

            if (tr.push && !tr.full) begin
                queue.push_front(tr.push_data);
            end

            if (tr.ex_uart_done) begin
                try_cnt++;
                compare_data = queue.pop_back();

                if (tr.compare_data === compare_data) begin
                    $display(" PASS => COMPART_DATA: %h == REAL_DATA: %h", compare_data,
                             tr.compare_data);
                    pass_cnt++;
                end else begin
                    $display(" Fail => Exp: %h != Act: %h", compare_data,
                             tr.compare_data);
                    fail_cnt++;
                end
                ->gen_next_ev;
            end
            ->gen_next_ev;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_ev;

    function new(virtual tx_interface tx_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, tx_if);
        mon = new(mon2scb_mbox, tx_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run();
        drv.preset();
        fork
            gen.run(20);
            drv.run();
            mon.run();
            scb.run();
        join_any


        #1000;

        $display("_______________________________");
        $display("** UART_TX verif **");
        $display("*******************************");
        $display("** total try count = %3d     **", scb.try_cnt);
        $display("** pass count = %3d           **", scb.pass_cnt);
        $display("** fail count = %3d           **", scb.fail_cnt);
        $display("*******************************");
        $stop;
    endtask
endclass

module tb_uart_tx ();
    logic clk = 0;
    tx_interface tx_if (clk);
    environment env;

    total_uart_tx dut (
        .clk(clk),
        .reset(tx_if.reset),
        .push_data(tx_if.push_data),
        .push(tx_if.push),
        .full(tx_if.full),
        .b_tick(tx_if.b_tick),
        .uart_tx(tx_if.uart_tx)
    );

    always #5 clk = ~clk;

    initial begin
        $timeformat(-9, 3, "ns");
        env = new(tx_if);
        env.run();
    end
endmodule
