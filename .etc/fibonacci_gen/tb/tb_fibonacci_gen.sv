`timescale 1ns/1ns

module tb_fibonacci_gen;

    parameter WIDTH = 16;

    // Testbench signals
    logic             clk;
    logic             rst_n;
    logic             cin;
    logic [WIDTH-1:0] fib_out;

    // Instantiate the Fibonacci generator module
    fibonacci_gen #(.WIDTH(WIDTH)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cin(cin),
        .fib_out(fib_out)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin

        $dumpfile("fibonacci_gen.vcd");
        $dumpvars(0, tb_fibonacci_gen);
        // Initialize inputs
        clk   = 0;
        rst_n = 0;
        cin   = 0;

        // Hold reset active for 20ns
        #20;
        rst_n = 1;

        // Wait for a clock edge, then pulse cin = 1 for exactly one clock cycle
        @(posedge clk);
        #1; // Small delay after clock edge to avoid race conditions
        cin = 1;

        @(posedge clk);
        #1;
        cin = 0; // Drop cin back to 0

        // Let the simulation run for 12 clock cycles to observe the sequence
        repeat (12) begin
            @(posedge clk);
        end

        $finish;
    end

    // Monitor the sequence output
    initial begin
        $monitor("Time = %0t ns | rst_n = %b | cin = %b | Reg A = %0d | Fib Out (Reg B) = %0d", 
                 $time, rst_n, cin, uut.reg_a, fib_out);
    end

endmodule