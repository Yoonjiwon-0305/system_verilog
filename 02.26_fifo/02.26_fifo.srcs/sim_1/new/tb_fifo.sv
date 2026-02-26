`timescale 1ns / 1ps

interface fifo_interface ();
    logic       clk;
    logic       reset;
    logic       push;
    logic       pop;
    logic [7:0] wdata;
    logic [7:0] rdata;
    logic       full;
    logic       empty;
endinterface  //fifo_interface

class transaction;

    rand bit [7:0] wdata;
    rand bit       push;
    rand bit       pop;
    logic    [7:0] rdata;

    function void display(string name);  // 리턴 타입 없는 함수
        $display("%t : [%s] push = %d, pop = %d, wdata = %2h, rdata = %2h",
                 $time, name, push, pop, wdata, rdata);

    endfunction  // 시간 성분 없으니까 task가 아닌 function 사용한 방법

endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            assert (tr.randomize())
            else $display("[gen] tr.randomize() error!!!");
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask

endclass  //generator

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;

    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task run();
        fifo_if.wdata <= 0;
        fifo_if.push  <= 0;
        fifo_if.pop   <= 0;
        forever begin
            gen2drv_mbox.get(tr);
            @(negedge fifo_if.clk);
            fifo_if.wdata = tr.wdata;
            fifo_if.push  = tr.push;
            fifo_if.pop   = tr.pop;
            tr.display("drv");
        end
    endtask  //

endclass  //driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task run();
        forever begin
            @(posedge fifo_if.clk);
            if (fifo_if.push || fifo_if.pop) begin  // 하나라도 1이면 
                tr = new();
                tr.push = fifo_if.push;
                tr.pop = fifo_if.pop;
                tr.wdata = fifo_if.wdata;
                tr.rdata = fifo_if.rdata;
                mon2scb_mbox.put(tr);
            end
        end
    endtask  //

endclass  //monitor

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    int pass_cnt = 0, fail_cnt = 0, try_cnt = 0;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();

    endtask  //
endclass  //scoreboard

class environment;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_ev;

    function new(virtual fifo_interface fifo_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, fifo_if);
        mon = new(mon2scb_mbox, fifo_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        fork
            gen.run(10);
            mon.run();
            drv.run();
            scb.run();
        join_any

        #10;
        $display("_______________________________");
        $display("** fifo verifi **");
        $display("*******************************");
        $display("** total try count = %3d     **", scb.try_cnt);
        $display("** pass count = %3d          **", scb.pass_cnt);
        $display("** fail count = %3d          **", scb.fail_cnt);
        $display("*******************************");

        $stop;
    endtask
endclass  //environment

module tb_fifo ();

    logic clk = 0;
    assign sram_if.clk = clk;

    fifo_interface fifo_if ();

    environment env;

    fifo dut (
        .clk  (fifo_if.clk),
        .reset(fifo_if.reset),
        .push (fifo_if.push),
        .pop  (fifo_if.pop),
        .wdata(fifo_if.wdata),
        .rdata(fifo_if.rdata),
        .full (fifo_if.full),
        .empty(fifo_if.empty)
    );

    always #5 clk = ~clk;

    initial begin

        $timeformat(-9, 3, "ns");
        env = new(fifo_if);

        env.run();
    end
endmodule
