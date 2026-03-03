`timescale 1ns / 1ps

interface adder_interface;
    logic [31:0] a;
    logic [31:0] b;
    logic        mode;
    logic [31:0] s;
    logic        c;

endinterface  //adder_interface


class transaction;

    randc bit [31:0] a;
    randc bit [31:0] b;
    randc bit        mode;
    logic     [31:0] s;
    logic            c;

    //모두가 쓰는 class 이므로 여기다 만듦

    task display(string name);
        $display("%t : [%s] a = %h, b = %h, mode = %h, sum = %h,carry = %h",
                 $time, name, a, b, mode, s, c);
    endtask  //display / $display가 아니므로 이름으로 가능하다

    //#1. constraint range {
    //    a > 10;
    //    b > 32'hffff_0000;
    //} // 랜덤수의 조건문

    //#2. constraint dist_pattern {
    //    a dist {
    //        0 := 8,
    //        32'hffff_ffff := 1,
    //        [1 : 32'hffff_fffe] := 1
    //    };
    //}
    //
    //#3. constraint dist_pattern {
    //    a dist {
    //        0 :/ 80,
    //        32'hffff_ffff :/ 10,
    //        [1 : 32'hffff_fffe] :/ 10
    //    };
    //}
    //
    //#4. constraint list_pattern {a inside {[0 : 16]};}

    constraint list_pattern {
        a inside {0, 15, 31, 63, 127, 255, 1023, 32'h0000_ffff};
    }

endclass

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
            tr.display(
                "gen");  // 어떤값을 보냈는지 확인 하기 위함
            @(gen_next_ev);  // 위치 중요 // scb 에서 비교검증하여 성공하면 입력 들어옴 // 드라이버가 dut에 잘 넣어줬는지 확인하고 다음 데이터 전달
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
            tr.display("drv");
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
            tr.display("mon");
        end

    endtask  //
endclass  //monitor

class scoreboard;

    // handler
    transaction                   tr;
    mailbox #(transaction)        mon2scb_mbox;
    event                         gen_next_ev;
    bit                    [31:0] expected_sum;
    bit                           expected_carry;
    int                           pass_cnt,       fail_cnt;
    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;

    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");
            // 비교할 expected data
            if (tr.mode == 0) {expected_carry, expected_sum} = tr.a + tr.b;
            else {expected_carry, expected_sum} = tr.a - tr.b;

            if ((expected_sum == tr.s) && (expected_carry == tr.c)) begin
                $display(
                    "[Pass] : a = %d, b = %d, mode = %d, sum = %d,carry = %d",
                    tr.a, tr.b, tr.mode, tr.s, tr.c);
                pass_cnt++;
            end else begin
                $display(
                    "[Fail] : a = %d, b = %d, mode = %d, sum = %d,carry = %d",
                    tr.a, tr.b, tr.mode, tr.s, tr.c);
                fail_cnt++;
                $display("expected sum = %h", expected_sum);
                $display("expected carry = %h", expected_carry);
            end
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

    int i;

    function new(virtual adder_interface adder_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, mon_next_ev, adder_if);
        mon = new(mon2scb_mbox, mon_next_ev, adder_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run(); // 여기에 blocking 연산 생략 되어 있음, pork join,begin and (=> 순서대로 작동)생략 되어 있는것임 
        i = 100;
        fork  // gen,drv동시 실행 // 병렬 실행 
            gen.run(i);
            drv.run();
            mon.run();
            scb.run();
        join_any  // join_any => 어떤 task든 누구라도 하나 끝나면 다음 라인 실행 //race컨디션을 만들면 안된다.
        // cpu는 하나이기 때문에 자세히 들여다 보면 순서가 존재 => 따라서 이 순서를 시뮬레이션이 랜덤으로 실행한다. => race컨디션을 만들면 안된다.
        #20; // 왜?? scb가 끝날때까지 기다려야함  ,cnt가 세워질때까지 기다려야함

        $display("______________________________");
        $display("** 32bit Adder Verification **");
        $display("------------------------------");
        $display("**  Total test cnt = %3d  **", i);
        $display("**  Total pass cnt = %3d  **", scb.pass_cnt);
        $display("**  Total fail cnt = %3d  **", scb.fail_cnt);
        $display("------------------------------");
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
        $timeformat(-9, 3, "ns");
        env = new(adder_if);

        env.run();

    end
endmodule
