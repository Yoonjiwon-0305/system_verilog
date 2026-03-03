`timescale 1ns / 1ps

interface adder_interface;  //HW
    // hw 니까 logic사용
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] s;
    logic        c;
    logic        mode;  // 정의만 함
endinterface  //adder_interface

class transaction;  // 운반하는 역할  // SW

    rand bit [31:0] a;  // 랜덤수로 전달할거야 라는 의미
    rand bit [31:0] b;
    // 시뮬레이션에 랜덤값을 생성한다는 의미만 전달 // 아직 랜덤 수 생성하지 않았음
    bit mode;

endclass  //transaction

class generator;  //SW // generarte => 반복하기 위해 사용// verilog의 문법 그대로 가져옴 generate

    transaction tr; // tr이라는 이름으로 transaction 생성 // 상속 아님
    virtual adder_interface adder_interf_gen;  // port 생성 // 소프트웨어와 하드웨어를 연결하기 위한 virtual

    function new(virtual adder_interface adder_interf_ext);  // 
        // 클래스에서 제공하는 생성자
        this.adder_interf_gen = adder_interf_ext;  // 연결해주는 동작  // 내부 이름 = 외부 이름
        tr = new();// new()=> 생성자
    endfunction

    task run(); // task  시간 관리 가능 //funtion 은 시간 관리 안된다// 스레드,프로세스와 같음 
        tr.randomize(); // 이때 랜덤 값 생성 // transaction에서 rand라고 적혀진 애들만 random값이 생성된다
        tr.mode = 0;
        adder_interf_gen.a = tr.a;
        adder_interf_gen.b = tr.b;
        adder_interf_gen.mode = tr.mode;

        //drive (시간제어)
        #10;
    endtask

endclass  //generator

module tb_adder_sv ();  //HW

    // interface와 충돌 하기 때문에 삭제 //logic [31:0] a, b, s;
    // interface와 충돌 하기 때문에 삭제 //logic c, mode;


    adder_interface adder_interf ();
    // class generator 를 선언 // 실체화 
    // gen : generator 객체를 관리하기 위한 handler

    generator gen;  // generator를선언 // handler에 이름을 붙인거임 

    adder dut (
        .a   (adder_interf.a),
        .b   (adder_interf.b),
        .mode(adder_interf.mode),
        .s   (adder_interf.s),
        .c   (adder_interf.c)
    );

    initial begin
        //class generater 생성
        //generator class의 function new가 실행됨
        gen = new(adder_interf);  // 동적할당 // handler를 new를 부름으로써 실제로 할당한것임// adder_interf를 인자로 넘겨준것 
        gen.run(); // 실제로 행동하는 부분

        $stop;
    end

endmodule
