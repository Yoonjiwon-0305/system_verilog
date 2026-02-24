`timescale 1ns / 1ps

interface adder_interface;
    logic [31:0] a;
    logic [31:0] b;
    logic        mode;
    logic [31:0] s;
    logic        c;

endinterface  //adder_interface


class transaction;

    rand bit [31:0] a;
    rand bit [31:0] b;
    rand bit        mode;
    logic    [31:0] s;
    logic           c;

endclass  //transaction 


class generator;

    //handler 
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int count);
        repeat (count) begin
            this.tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);  // mailbox에 tr을 put한 것임
            @(gen_next_ev);  // 위치 중요 // 
        end
    endtask  //

endclass  //generator


class driver;

    // handler
    transaction tr;
    virtual adder_interface adder_if;  // sw =>hw 이기 때문에 virtual
    mailbox #(transaction) gen2drv_mbox;
    event mon_next_ev;


    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_ev,
                 virtual adder_interface adder_if);
        this.adder_if = adder_if;
        this.mon_next_ev = mon_next_ev;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction  //new()

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            adder_if.a    = tr.a;
            adder_if.b    = tr.b;
            adder_if.mode = tr.mode;
            #10;
            // event 발생
            ->mon_next_ev;
        end
    endtask  //

endclass  //driver

class monitor;

    // handler
    transaction tr;
    virtual adder_interface adder_if;
    mailbox #(transaction) mon2scb_mbox;
    event mon_next_ev;

    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_ev,
                 virtual adder_interface adder_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.adder_if = adder_if;
        this.mon_next_ev = mon_next_ev;


    endfunction  //new()

    task run();
        forever begin
            @(mon_next_ev);
            tr = new();
            tr.a = adder_if.a;
            tr.b = adder_if.b;
            tr.mode = adder_if.mode;
            tr.s = adder_if.s;
            tr.c = adder_if.c;
            mon2scb_mbox.put(tr);
        end

    endtask  //
endclass  //monitor

class scoreboard;

    // handler
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
            //compare,pass,fail
            $display("%t:a=%d, b=%d,mode=%d,s=%d,c=%d", $time, tr.a, tr.b,
                     tr.mode, tr.s, tr.c);
            ->gen_next_ev;
        end
    endtask  //
endclass  //scoreboard

class environment;

    // handler
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    virtual adder_interface adder_if;

    mailbox #(transaction)  gen2drv_mbox;  // 키워드 #(데이터 타입) 이름 
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_ev;  // scb to gen
    event mon_next_ev;  // arv to mon

    function new(virtual adder_interface adder_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, mon_next_ev, adder_if);
        mon = new(mon2scb_mbox, mon_next_ev, adder_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run(); // 여기에 blocking 연산 생략 되어 있음, pork join,begin and (=> 순서대로 작동)생략 되어 있는것임 
        fork  // gen,drv동시 실행 // 병렬 실행 
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any  // join_any => 어떤 task든 누구라도 하나 끝나면 다음 라인 실행 //race컨디션을 만들면 안된다.
        // cpu는 하나이기 때문에 자세히 들여다 보면 순서가 존재 => 따라서 이 순서를 시뮬레이션이 랜덤으로 실행한다. => race컨디션을 만들면 안된다.
        $stop;
    endtask  //

    // fork~join_none => 실행후 next line 실행
endclass  //envirnment


module tb_adder_verification ();

    adder_interface adder_if ();

    environment env;

    adder dut (
        .a   (adder_if.a),
        .b   (adder_if.b),
        .mode(adder_if.mode),
        .s   (adder_if.s),
        .c   (adder_if.c)
    );

    initial begin
        // 생성자
        env = new(adder_if);

        env.run();

    end
endmodule
