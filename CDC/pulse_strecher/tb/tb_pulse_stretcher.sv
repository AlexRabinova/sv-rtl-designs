`timescale 1ns/1ps

module tb_pulse_stretcher;

    // Parameters
    localparam int STRETCH_CYCLES = 3;
    
    // Clock periods (Asynchronous clocks: e.g., Source = 100MHz [10ns], Dest = 250MHz [4ns])
    localparam real CLK_SRC_PERIOD = 10.0;
    localparam real CLK_DST_PERIOD = 4.0;

    // Signals
    logic clk_src;
    logic rst_src_n;
    logic pulse_in;

    logic clk_dst;
    logic rst_dst_n;
    logic pulse_out;

    // Instantiate DUT
    pulse_stretcher #(
        .STRETCH_CYCLES(STRETCH_CYCLES)
    ) dut (
        .clk_src(clk_src),
        .rst_src_n(rst_src_n),
        .pulse_in(pulse_in),
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .pulse_out(pulse_out)
    );

    // Clock Generation: Source Clock (100 MHz)
    initial begin
        clk_src = 1'b0;
        forever #(CLK_SRC_PERIOD / 2.0) clk_src = ~clk_src;
    end

    // Clock Generation: Destination Clock (250 MHz)
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
        // Initialize signals
        rst_src_n = 1'b0;
        rst_dst_n = 1'b0;
        pulse_in  = 1'b0;

        // Apply resets
        #(CLK_SRC_PERIOD * 5);
        rst_src_n = 1'b1;
        rst_dst_n = 1'b1;
        #(CLK_SRC_PERIOD * 5);

        $display("[%0t] Starting Pulse Stretcher CDC Tests...", $time);

        // Test 1: Single Pulse
        $display("[%0t] Test 1: Driving single pulse...", $time);
        drive_pulse();

        // Wait enough time between pulses to let the CDC clear
        #(CLK_SRC_PERIOD * 20);

        // Test 2: Back-to-back Pulses (testing robustness)
        $display("[%0t] Test 2: Driving second pulse...", $time);
        drive_pulse();

        #(CLK_SRC_PERIOD * 20);

        $display("[%0t] Simulation finished successfully.", $time);
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0t ns | pulse_in=%b | pulse_out=%b", $time, pulse_in, pulse_out);
    end

endmodule