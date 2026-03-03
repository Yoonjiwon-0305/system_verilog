`timescale 1ns / 1ps

interface rx_interface (
    input logic clk
);
    logic reset;
    logic rx;
    logic [7:0] rx_data;
    logic rx_done;
    logic b_tick;
endinterface

class transaction;
    rand bit [7:0] in_rx_data;
    logic    [7:0] rx_data;
    logic          rx_done;

    function void display(string name);
        $display("%t : [%s] in_rx_data = %2h, rx_data = %2h, rx_done = %d",
                 $time, name, in_rx_data, rx_data, rx_done);
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
    virtual rx_interface rx_if;

    function new(mailbox#(transaction) gen2drv_mbox, virtual rx_interface rx_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.rx_if = rx_if;
    endfunction

    task preset();
        rx_if.rx <= 1'b1;
        rx_if.reset <= 1'b1;
        repeat (2) @(posedge rx_if.clk);
        rx_if.reset <= 1'b0;
        @(posedge rx_if.clk);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            rx_if.rx <= 0;
            repeat (10) @(negedge rx_if.b_tick);
            for (int i = 0; i < 8; i++) begin
                rx_if.rx <= tr.in_rx_data[i];
                repeat (16) @(negedge rx_if.b_tick);
            end
            rx_if.rx <= 1;
            tr.display("dvr");
            repeat (16) @(negedge rx_if.b_tick);
            
        end
    endtask
endclass

class monitor;
    virtual rx_interface rx_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox, virtual rx_interface rx_if);
        this.rx_if = rx_if;
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction

    task run();
        forever begin
            transaction tr = new();
            wait (rx_if.rx == 0);
            repeat (18) @(posedge rx_if.b_tick);
            for (int i = 0; i < 8; i++) begin
                tr.in_rx_data[i] = rx_if.rx;
                repeat (16) @(posedge rx_if.b_tick);
            end
            @(posedge rx_if.rx_done );
            #1;
            tr.rx_done = rx_if.rx_done;
            tr.rx_data = rx_if.rx_data;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask
endclass

class scoreboard;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    int pass_cnt, fail_cnt, try_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
        this.pass_cnt     = 0;
        this.fail_cnt     = 0;
        this.try_cnt      = 0;
    endfunction

    task run();
        transaction tr;
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");
            try_cnt++;
            if (tr.in_rx_data === tr.rx_data) begin
                pass_cnt++;
                $display("%t : PASS = compare_data: %h, real_data: %h", $time, tr.in_rx_data, tr.rx_data);
            end else begin
                fail_cnt++;
                $display("%t : FAIL = exp: %h, got: %h", $time, tr.in_rx_data, tr.rx_data);
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

    function new(virtual rx_interface rx_if);
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
        #100;
        $display("_______________________________");
        $display("** UART RX Verification **");
        $display("*******************************");
        $display("** total try count = %3d     **", scb.try_cnt);
        $display("** pass count = %3d           **", scb.pass_cnt);
        $display("** fail count = %3d           **", scb.fail_cnt);
        $display("*******************************");
        $finish;
    endtask
endclass

module tb_uart_rx ();
    logic clk = 0;
    rx_interface rx_if (clk);
    environment env;

    uart_rx dut (
        .clk(clk),
        .reset(rx_if.reset),
        .rx_in(rx_if.rx),
        .rx_data(rx_if.rx_data),
        .rx_done(rx_if.rx_done)
    );

    assign rx_if.b_tick = dut.b_tick;
    always #5 clk = ~clk;

    initial begin
        $timeformat(-6, 3, "us");
        env = new(rx_if);
        env.run(10);
    end
endmodule