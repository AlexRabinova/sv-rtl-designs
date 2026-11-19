`timescale 1ns / 1ps

module tb_divide_by_5;

    // Inputs
    reg clk;
    reg rst_n;

    // Outputs
    wire clk_out;

    // Instantiate the Unit Under Test (UUT)
    divide_by_5 uut (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out(clk_out)
    );

    // Generate a clock with a 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;

        // Configure VCD file generation
        $dumpfile("divide_by_5.vcd");
        $dumpvars(0, tb_divide_by_5);

        // Apply reset for 25ns, then release
        #25;
        rst_n = 1;

        // Run simulation long enough to see multiple divided cycles (e.g., 300ns)
        #300;

        $display("Simulation completed successfully.");
        $finish;
    end

endmodule