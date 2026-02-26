`timescale 1ns / 1ps

interface register_interface;
    logic       clk;
    logic       reset;
    logic [7:0] wdata;
    logic [7:0] rdata;

    property preset_ckeck;
        @(posedge clk) reset |=> (rdata == 0);
    endproperty

    reg_reset_check :
    assert property (preset_ckeck)
    else $display("%t : Assert error : reset check", $time);  // 검증용 

endinterface  // register_interface


class transaction;

    rand bit [7:0] wdata;
    logic    [7:0] rdata;

    task display(string name);
        $display("%t : [%s] wdata = %h, rdata = %h", $time, name, wdata, rdata);
    endtask  //display
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

endclass  //generator

class driver;

    transaction tr;
    virtual register_interface register_if;
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual register_interface register_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.register_if  = register_if;

    endfunction  //new()

    task preset();
        register_if.clk   = 0;
        register_if.reset = 1;
        register_if.wdata = 0;
        @(posedge register_if.clk);
        @(posedge register_if.clk);
        register_if.reset = 0;
        @(posedge register_if.clk);
    endtask  //preset

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(negedge register_if.clk);
            register_if.wdata = tr.wdata;
            tr.display("dvr");
        end
    endtask  //run
endclass  //driver

class monitor;

    transaction tr;
    virtual register_interface register_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual register_interface register_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.register_if  = register_if;

    endfunction  //new()

    task run();
        forever begin
            tr = new();
            @(posedge register_if.clk);
            #1;
            tr.wdata = register_if.wdata;
            tr.rdata = register_if.rdata;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask  //run
endclass  // monitor

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);

            if (tr.wdata == tr.rdata) begin
                $display("%t : Pass : wdata = %h, rdata = %h", $time, tr.wdata,
                         tr.rdata);
            end else begin
                $display("%t : Fail : wdata = %h, rdata = %h", $time, tr.wdata,
                         tr.rdata);
            end
            tr.display("scb");
            ->gen_next_ev;
        end
    endtask  //run
endclass  //scoreboard


class environment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    //virtual register_interface register_if;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    function new(virtual register_interface register_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, register_if);
        mon = new(mon2scb_mbox, register_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #20;
        $stop;
    endtask
endclass  //environment

module tb_register_8bit ();

    register_interface register_if ();

    environment env;

    register_8bit dut (

        .clk  (register_if.clk),
        .reset(register_if.reset),
        .wdata(register_if.wdata),
        .rdata(register_if.rdata)
    );

    always #5 register_if.clk = ~register_if.clk;

    initial begin
        //register_if.clk   = 0;
        //register_if.reset = 1;

        $timeformat(-9, 3, "ns");
        env = new(register_if);

        env.run();
    end

endmodule
