`timescale 1ns/1ps

module tb_fir_filter_folded();

    parameter int DATA_WIDTH = 16;
    parameter int NUM_TAPS   = 101;

    // Testbench signals
    logic                     clk;
    logic                     rst_n;
    logic                     valid_i;
    logic signed [15:0]       x_i;
    logic signed [15:0]       h_rom [NUM_TAPS];
    logic                     valid_o;
    logic signed [37:0]       y_o;

    // Instantiate the Folded FIR Filter (DUT)
    fir_filter_folded #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_TAPS(NUM_TAPS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(valid_i),
        .x_i(x_i),
        .h_rom(h_rom),
        .valid_o(valid_o),
        .y_o(y_o)
    );

    // Clock Generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk     = 1'b0;
        rst_n   = 1'b0;
        valid_i = 1'b0;
        x_i     = '0;

        // Initialize Coefficient ROM
        // Let's set h[0] = 2 and h[1] = 1, and the rest to 0 for a predictable test.
        for (int i = 0; i < NUM_TAPS; i++) begin
            h_rom[i] = '0;
        end
        h_rom[0] = 16'sd2;
        h_rom[1] = 16'sd1;

        // Apply Reset
        #25;
        rst_n = 1'b1;
        #20;

        // --- Test Scenario 1: Send input sample x[n] = 10 ---
        @(posedge clk);
        x_i     = 16'sd10;
        valid_i = 1'b1;
        
        @(posedge clk);
        valid_i = 1'b0; // Deassert valid; the filter will run its 101 cycles sequentially

        // Wait long enough for the 101-cycle sequential computation to finish
        repeat (110) @(posedge clk);

        // --- Test Scenario 2: Send input sample x[n] = 5 ---
        @(posedge clk);
        x_i     = 16'sd5;
        valid_i = 1'b1;

        @(posedge clk);
        valid_i = 1'b0;

        // Wait for completion again
        repeat (110) @(posedge clk);

        $finish;
    end

    // Monitor Block to capture and print outputs when valid_o pulses high
    always_ff @(posedge clk) begin
        if (valid_o) begin
            $display("[T = %0t ns] Filter Result (y_o) = %0d", $time, y_o);
        end
    end

    // VCD Waveform Generation Block
    initial begin
        $dumpfile("fir_filter_wave.vcd");  // Name of the VCD file
        $dumpvars(0, tb_fir_filter_folded); // Dump all variables under this testbench scope
    end

endmodule