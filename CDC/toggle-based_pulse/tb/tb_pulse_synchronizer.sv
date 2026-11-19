`timescale 1ns/1ps

module tb_pulse_synchronizer_fast_to_slow;

    // Parameters
    localparam int SYNC_STAGES = 2;
    
    // Clock periods: Source is FAST (300MHz [3.333ns]), Dest is SLOW (100MHz [10ns])
    localparam real CLK_SRC_PERIOD = 3.333;
    localparam real CLK_DST_PERIOD = 10.0;

    // Signals
    logic clk_src;
    logic rst_src_n;
    logic pulse_in;

    logic clk_dst;
    logic rst_dst_n;
    logic pulse_out;

    // Instantiate DUT
    pulse_synchronizer #(
        .SYNC_STAGES(SYNC_STAGES)
    ) dut (
        .clk_src(clk_src),
        .rst_src_n(rst_src_n),
        .pulse_in(pulse_in),
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .pulse_out(pulse_out)
    );

    // Clock Generation: Fast Source Clock (~300 MHz)
    initial begin
        clk_src = 1'b0;
        forever #(CLK_SRC_PERIOD / 2.0) clk_src = ~clk_src;
    end

    // Clock Generation: Slow Destination Clock (100 MHz)
    initial begin
        clk_dst = 1'b0;
        forever #(CLK_DST_PERIOD / 2.0) clk_dst = ~clk_dst;
    end

    // Task: Generate a single-cycle pulse in the source domain
    task drive_pulse();
        @(posedge clk_src);
        #1; // small offset after clock edge
        pulse_in = 1'b1;
        @(posedge clk_src);
        #1;
        pulse_in = 1'b0;
    endtask

    // Stimulus and Verification
    initial begin
        // --- VCD Dump Setup for Icarus Verilog & EDA Tools ---
        $dumpfile("waveform_fast_to_slow.vcd");
        $dumpvars(0, tb_pulse_synchronizer_fast_to_slow);

        // Initialize signals
        rst_src_n = 1'b0;
        rst_dst_n = 1'b0;
        pulse_in  = 1'b0;

        // Apply resets (using slow clock period reference for safety)
        #(CLK_DST_PERIOD * 5);
        rst_src_n = 1'b1;
        rst_dst_n = 1'b1;
        #(CLK_DST_PERIOD * 5);

        $display("[%0t] Starting Fast-to-Slow Pulse Synchronizer Tests...", $time);

        // Test 1: Single Pulse
        $display("[%0t] Test 1: Driving single pulse on fast clock...", $time);
        drive_pulse();

        // Wait enough time for propagation across the slow destination clock domain
        #(CLK_DST_PERIOD * 10);

        // Test 2: Second Pulse
        $display("[%0t] Test 2: Driving second pulse...", $time);
        drive_pulse();

        #(CLK_DST_PERIOD * 10);

        $display("[%0t] Simulation finished successfully.", $time);
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0t ns | pulse_in=%b | pulse_out=%b", $time, pulse_in, pulse_out);
    end

endmodule