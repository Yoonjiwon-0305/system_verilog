`timescale 1ns / 1ps

// # case 5
module tb_fork_join ();

    initial begin
        $timeformat(-9, 3, "ns");
        #1 $display("%t : start fork_join", $time);

        fork
            //task A
            A_thread();

            //task B 
            B_thread();

            //task C 
            C_thread();
        join_any

        #10 $display("%t : end fork_join", $time);
        disable fork;
        $stop;
    end

    task A_thread();
        repeat (5) $display("%t : A_thread", $time);
    endtask  //A_threade

    task B_thread();
        forever begin
            $display("%t : B_thread", $time);
            #5;
        end
    endtask  //B_threade

    task C_thread();
        forever begin
            $display("%t : C_thread", $time);
            #10;
        end
    endtask  //C_threade

endmodule
