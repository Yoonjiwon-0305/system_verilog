`timescale 1ns / 1ps
//# case 1
//interface sram_interface;
//
//    logic       clk;
//    logic [3:0] addr;
//    logic       we;
//    logic [7:0] wdata;
//    logic [7:0] rdata;
//
//endinterface  //sram_interface

//# case 2
interface sram_interface ();
    logic       clk;
    logic [3:0] addr;
    logic       we;
    logic [7:0] wdata;
    logic [7:0] rdata;


endinterface  //sram_interface(input clk)

class transaction;

    rand bit [7:0] wdata;
    rand bit       we;
    rand bit [3:0] addr;
    logic    [7:0] rdata;

    function void display(string name);  // 리턴 타입 없는 함수
        $display("%t : [%s] we = %d, addr = %2h, wdata = %2h, rdata = %2h",
                 $time, name, we, addr, wdata, rdata);

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
            assert (tr.randomize())  // 원인파악하기 위해 넣어줌
            else
                $display(
                    "[gen] tr.randomize() error!!!"
                );  // 조건이 돌지 않을때 
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask  //run
endclass  // generator

class driver;

    transaction tr;
    virtual sram_interface sram_if;
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual sram_interface sram_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.sram_if = sram_if;

    endfunction  //new()

    task run();
        sram_if.we    <= 0;
        sram_if.addr  <= 0;
        sram_if.wdata <= 0;
        forever begin
            gen2drv_mbox.get(tr);
            @(negedge sram_if.clk);
            sram_if.we    = tr.we;
            sram_if.wdata = tr.wdata;
            sram_if.addr = tr.addr;
            tr.display("dvr");
        end
    endtask  //run
endclass  //driver

class monitor;

    transaction tr;
    virtual sram_interface sram_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual sram_interface sram_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.sram_if = sram_if;
    endfunction  //new()

    task run();
        forever begin
            @(posedge sram_if.clk);
            #1;
            tr       = new();
            tr.wdata = sram_if.wdata;
            tr.we    = sram_if.we;
            tr.rdata = sram_if.rdata;
            tr.addr  = sram_if.addr;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask  //run()
endclass

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    int pass_cnt, fail_cnt, try_cnt;

    //coverage
    covergroup cg_sram;

        cp_addr: coverpoint tr.addr {
            bins min = {0}; bins max = {15}; bins mid[]= {[1 : 14]};

        }

    endgroup

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev = gen_next_ev;
        cg_sram = new();
    endfunction  //new()

    task run();
        logic [7:0] memory[0:15];
        pass_cnt = 0;
        fail_cnt = 0;
        try_cnt  = 0;
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");
            
            cg_sram.sample();
            if (tr.we) begin
                memory[tr.addr] = tr.wdata;
                $display("%2h", memory[tr.addr]);
            end else begin
                try_cnt++;
                if (memory[tr.addr] === tr.rdata) begin
                    $display("%t : Pass : wdata = %2h, rdata = %2h", $time,
                             memory[tr.addr], tr.rdata);
                    pass_cnt++;
                end else begin
                    $display("%t : Fail : wdata = %2h, rdata = %2h", $time,
                             memory[tr.addr], tr.rdata);
                    fail_cnt++;
                end
            end

            ->gen_next_ev;
        end
    endtask  //runard

endclass

class environment;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_ev;

    function new(virtual sram_interface sram_if);

        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, sram_if);
        mon = new(mon2scb_mbox, sram_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        //drv.preset();
        fork
            gen.run(50);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $display("coveradge addr = %d",scb.cg_sram.get_inst_coverage());
        $display("_______________________________");
        $display("** sram verifi **");
        $display("*******************************");
        $display("** total try count = %3d     **", scb.try_cnt);
        $display("** pass count = %3d          **", scb.pass_cnt);
        $display("** fail count = %3d          **", scb.fail_cnt);
        $display("*******************************");

        $stop;
    endtask

endclass  //environment

module tb_sram ();

    logic clk = 0;

    sram_interface sram_if ();
    assign sram_if.clk = clk;
    environment env;

    sram dut (
        .clk  (sram_if.clk),
        .addr (sram_if.addr),
        .we   (sram_if.we),
        .wdata(sram_if.wdata),
        .rdata(sram_if.rdata)
    );

    always #5 clk = ~clk;

    initial begin

        $timeformat(-9, 3, "ns");
        env = new(sram_if);

        env.run();
    end
endmodule
