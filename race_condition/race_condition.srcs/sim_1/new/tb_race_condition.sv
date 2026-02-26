`timescale 1ns / 1ps

module tb_race_condition ();

    logic p, q;

    assign p = q;

    initial begin
        q = 1;
        #1 q = 0;
        $display("%d", p);
        $stop;

    end


endmodule
