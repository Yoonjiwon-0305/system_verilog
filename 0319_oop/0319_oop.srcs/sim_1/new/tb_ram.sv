`timescale 1ns / 1ps

//interface
interface ram_interface (
    input logic clk
);

    logic       we;
    logic [7:0] addr;
    logic [7:0] wdata;
    logic [7:0] rdata;

endinterface  //ram_interface

//software
class test;

    virtual ram_interface ram_if;  // 소프트웨어 인터페이스

    function new(virtual ram_interface ram_if);
        this.ram_if = ram_if;
    endfunction  //new()

    virtual task write(logic [7:0] waddr, logic [7:0] wdata);
        ram_if.we    = 1;
        ram_if.addr  = waddr;
        ram_if.wdata = wdata;
        @(posedge ram_if.clk);
    endtask

    virtual task read(
        logic [7:0] raddr
    );  // 이때의 virtual는 클래스의 기능: override에 대한 기능 //상속받은 자식 클래스내부에서 이름 똑같은 task에 내용을 재정의 할수있음
        ram_if.we   = 0;
        ram_if.addr = raddr;
        @(posedge ram_if.clk);
    endtask

endclass  //

class test_burst extends test; // write와 read의 기능은 포함하면서 새로운기능 추가됌 // 상속을 하면 원본은 변하지 않고 유지가 된다

    function new(virtual ram_interface ram_if);
        super.new(ram_if);  // super => 부모클래스의 new를 의미
    endfunction

    task write_burst(logic [7:0] waddr, logic [7:0] wdata, int len);
        for (int i = 0; i < len; i++) begin
            super.write(waddr, wdata);  //부모클래스의 write
            waddr++;
        end
    endtask

    task write(logic [7:0] waddr, logic [7:0] wdata);  // 재정의

        ram_if.we    = 1;
        ram_if.addr  = waddr+1;
        ram_if.wdata = wdata;
        @(posedge ram_if.clk);
        waddr++;

    endtask  //
endclass  //test_burst extends test

class transaction;
    logic            we;
    rand logic [7:0] addr;
    rand logic [7:0] wdata;
    logic      [7:0] rdata;

    constraint c_addr {addr inside {[8'h00 : 8'h10]};}
    constraint c_wdata {wdata inside {[8'h10 : 8'h20]};}

    function print(string name);
        $display("[%s] we:%0d, addr:0x%0x, wdata:0x%0x, rdata:0x%0x", name, we,
                 addr, wdata, rdata);
    endfunction  //new()
endclass  //transaction

class test_rand extends test; //test_rand가 tr.new()를 통해 instance(실체화) 시켰다.

    transaction tr;  //스택영역에 메모리 공간 잡힘 //신호값만 만들어주는 역할

    function new(virtual ram_interface ram_if);
        super.new(ram_if);
    endfunction  //new()

    task write_rand(int loop);
        repeat (loop) begin
            tr = new();
            tr.randomize();
            tr.print("tr");
            ram_if.we    = 1;
            ram_if.addr  = tr.addr;
            ram_if.wdata = tr.wdata;
            @(posedge ram_if.clk);
        end
    endtask  //
endclass  //test_rand extends test

//hardware
module tb_ram ();

    logic clk;

    ram_interface ram_if (clk);  // 하드웨어 인터페이스

    ram dut (
        .clk(ram_if.clk),
        .we(ram_if.we),
        .addr(ram_if.addr),
        .wdata(ram_if.wdata),
        .rdata(ram_if.rdata)
    );

    initial clk = 0;

    always #5 clk = ~clk;

    test      jiwon;  //test=> 객체 X  jiwon => handler(클래스 변수)
    test_rand BlackPink;

    initial begin
        repeat (5) @(posedge clk);

        jiwon = new(ram_if);  //(상상한) handler를 실체화 new() => 객체     ==new(virtual ram_interface(자료형) ram_if(변수선언) = ram_if(값) )
        BlackPink = new(ram_if);
        $display("addr = 0x%0h", jiwon);
        $display("addr = 0x%0h", BlackPink);

        //객체 -> 주어가 있는 write read
        jiwon.write(8'h00, 8'h01);
        jiwon.write(8'h01, 8'h02);
        jiwon.write(8'h02, 8'h03);
        jiwon.write(8'h03, 8'h04);

        BlackPink.write_rand(10);

        jiwon.read(8'h00);
        jiwon.read(8'h01);
        jiwon.read(8'h02);
        jiwon.read(8'h03);

        //객체 아님 -> 주어가 없는 write read
        //write
        //ram_write(8'h00, 8'h01);
        //ram_write(8'h01, 8'h02);
        //ram_write(8'h02, 8'h03);
        //ram_write(8'h03, 8'h04);

        //read
        //ram_read(8'h00);
        //ram_read(8'h01);
        //ram_read(8'h02);
        //ram_read(8'h03);

        #20;
        $finish;
    end
endmodule

