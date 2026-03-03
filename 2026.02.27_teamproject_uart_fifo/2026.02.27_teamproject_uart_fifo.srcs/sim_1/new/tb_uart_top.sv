`timescale 1ns / 1ps

interface uart_if (
    input clk
);
    logic reset;
    logic uart_rx;
    logic uart_tx;
    logic b_tick;
endinterface

class transaction;
    rand bit [7:0] data;
    bit [7:0] resp_data;

    function void display(string name);
        $display("%t : [%s] data=%h, resp=%h", $time, name, data, resp_data);
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
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("GEN");
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_if u_if;

    function new(mailbox#(transaction) gen2drv_mbox, virtual uart_if u_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.u_if = u_if;
    endfunction

    task run();
        u_if.uart_rx <= 1'b1;
        forever begin
            gen2drv_mbox.get(tr);

            // Start bit
            u_if.uart_rx <= 1'b0;
            repeat (16) @(posedge u_if.b_tick);

            for (int i = 0; i < 8; i++) begin
                u_if.uart_rx <= tr.data[i];
                repeat (16) @(posedge u_if.b_tick);
            end

            // Stop bit
            u_if.uart_rx <= 1'b1;
            repeat (16) @(posedge u_if.b_tick);

            tr.display("DRV_SENT");
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_if u_if;

    function new(mailbox#(transaction) mon2scb_mbox, virtual uart_if u_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.u_if = u_if;
    endfunction

    task run();
        forever begin
            logic [7:0] rdata;
            wait (u_if.uart_tx == 0);
            repeat (8) @(posedge u_if.b_tick);

            for (int i = 0; i < 8; i++) begin
                repeat (16) @(posedge u_if.b_tick);
                rdata[i] = u_if.uart_tx;
            end

            repeat (16) @(posedge u_if.b_tick);

            tr = new();
            tr.resp_data = rdata;
            mon2scb_mbox.put(tr);

            wait (u_if.uart_tx == 1);
        end
    endtask
endclass

class scoreboard;

    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    logic [7:0] compare_queue[$];
    int pass_cnt = 0, fail_cnt = 0, try_cnt = 0;

    function new(mailbox#(transaction) monscb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run();
        fork
            forever begin
                transaction g_tr;
                gen2scb_mbox.get(g_tr);
                compare_queue.push_back(g_tr.data);
            end

            forever begin
                transaction m_tr;
                logic [7:0] exp_data;
                mon2scb_mbox.get(m_tr);

                try_cnt++;
                exp_data = compare_queue.pop_front();

                if (m_tr.resp_data === exp_data) begin
                    $display("%t : [PASS] Exp:%h == Act:%h", $time, exp_data,
                             m_tr.resp_data);
                    pass_cnt++;
                end else begin
                    $display("%t : [FAIL] Exp:%h != Act:%h", $time, exp_data,
                             m_tr.resp_data);
                    fail_cnt++;
                end
            end
        join
    endtask
endclass

class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_ev;

    virtual uart_if        u_if;

    function new(virtual uart_if u_if);
        this.u_if = u_if;
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, u_if);
        mon = new(mon2scb_mbox, u_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run(int count);
        fork
            gen.run(count);
            drv.run();
            mon.run();
            scb.run();
        join_any

        wait (scb.try_cnt == count);
        #10000;

        $display("_______________________________");
        $display("** UART Loopback Verification **");
        $display("Total: %0d, Pass: %0d, Fail: %0d", scb.try_cnt, scb.pass_cnt,
                 scb.fail_cnt);
        $display("*******************************");
        $stop;
    endtask
endclass

module tb_uart_top ();
    logic clk = 0;
    always #5 clk = ~clk;

    uart_if u_if (clk);
    environment env;

    uart_top dut (
        .clk(clk),
        .reset(u_if.reset),
        .uart_rx(u_if.uart_rx),
        .uart_tx(u_if.uart_tx),
        .b_tick(u_if.b_tick)
    );

    initial begin
        $timeformat(-9, 3, "ns");
        u_if.reset = 1;
        #100 u_if.reset = 0;

        env = new(u_if);
        env.run(10);
    end
endmodule
