// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module tb_rr_arbiter;

    // Parameters
    localparam int WIDTH = 4;

    // Testbench signals
    logic             clk;
    logic             rst_n;
    logic [WIDTH-1:0] req;
    logic [WIDTH-1:0] mask;
    logic [WIDTH-1:0] grant;

    // Instantiate the Round Robin Arbiter (DUT)
    rr_arbiter #(.WIDTH(WIDTH)) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .mask(mask),
        .grant(grant)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Waveform dump for EDA tools (EDA Playground compatible)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_rr_arbiter);
    end

    // Test stimulus sequence
    initial begin
        // Initialize signals
        clk   = 0;
        rst_n = 0;
        req   = '0;
        mask  = {WIDTH{1'b1}}; // Default: all requests enabled (unmasked)

        // Apply reset
        #15;
        rst_n = 1;
        @(posedge clk);

        // --- Test 1: Full Round Robin Rotation ---
        $display("[%0t] Test 1: Asserting all requests to observe round-robin rotation", $time);
        req = 4'b1111; // All agents requesting
        #40;           // Allow 4 clock cycles to cycle through all 4 priorities

        // --- Test 2: Idle State & Pointer Holding ---
        $display("[%0t] Test 2: Dropping requests to test idle pointer-holding", $time);
        req = 4'b0000; // No requests
        #20;           // Arbiter idles; pointer should freeze its position

        // --- Test 3: Sparse Requests & Wrap-around ---
        $display("[%0t] Test 3: Testing sparse requests (bits 0 and 2)", $time);
        req = 4'b0101; 
        #30;

        // --- Test 4: Masked Arbitration ---
        $display("[%0t] Test 4: Testing masked design (disabling bits 1 and 2)", $time);
        mask = 4'b1001; // Only allow bit 0 and bit 3 to participate
        req  = 4'b1111; // Everyone requests, but 1 and 2 are masked out
        #40;

        // --- Test 5: Return to normal ---
        $display("[%0t] Test 5: Re-enabling mask and sending new requests", $time);
        mask = 4'b1111;
        req  = 4'b0010;
        #20;
        req  = '0;
        #20;

        $display("[%0t] Simulation finished successfully!", $time);
        $finish;
    end

    // Monitor changes in grants and pointer state for easy log reading
    initial begin
        $monitor("Time=%0t ns | rst_n=%b | mask=%b | req=%b | grant=%b | ptr_oh=%b", 
                 $time, rst_n, mask, req, grant, u_dut.ptr_oh);
    end

endmodule