`timescale 100ps/100ps

module tb_freq_doubler_xor;

    // Parameters
    localparam time CLK_PERIOD = 10ns;
    localparam time TPD_DELAY  = 2.5ns; // Tune this to adjust output pulse width

    // Signals
    logic clk_in;
    logic clk_out;

    // Instantiate DUT
    freq_doubler_xor #(.TPD(TPD_DELAY)) dut (
        .clk_in(clk_in),
        .clk_out(clk_out)
    );

    // Clock generator (50% duty cycle)
    initial begin
        clk_in = 1'b0;
        forever #(CLK_PERIOD / 2) clk_in = ~clk_in;
    end

    // Simulation control & VCD dump for GTKWave
    initial begin
        // Standard system tasks supported by Vivado's XSim for VCD generation
        $dumpfile("freq_doubler.vcd");
        $dumpvars(0, tb_freq_doubler_xor);

        // Run simulation for 10 clock cycles then exit
        #(CLK_PERIOD * 10);

        $display("Simulation completed successfully.");
        $finish;
    end

endmodule