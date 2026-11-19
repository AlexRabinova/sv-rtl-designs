`timescale 1ns/1ps

module tb_skid_buffer;

    // Clock & Reset
    logic        clk;
    logic        rst_n;

    // Upstream Interface
    logic        i_valid;
    logic        o_ready;
    logic [31:0] i_data;

    // Downstream Interface
    logic        o_valid;
    logic        i_ready;
    logic [31:0] o_data;

    // Clock generation (100MHz -> 10ns period)
    always #5 clk = ~clk;

    // DUT Instantiation
    skid_buffer dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .i_valid(i_valid),
        .o_ready(o_ready),
        .i_data (i_data),
        .o_valid(o_valid),
        .i_ready(i_ready),
        .o_data (o_data)
    );

    // Test Sequence
    initial begin
        // Initialize signals
        clk     = 0;
        rst_n   = 0;
        i_valid = 0;
        i_ready = 0;
        i_data  = 32'h0;

        // Apply Reset
        #15;
        rst_n = 1;
        $display("[TB] Reset Deasserted");
        @(posedge clk);

        // ---------------------------------------------------------------------
        // Test 1: Empty -> Load -> Continuous Streaming (Normal Mode, State 1)
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: Continuous Streaming Pass-through ---");
        i_ready <= 1;
        
        // Push Data 0x101
        i_valid <= 1;
        i_data  <= 32'h101;
        @(posedge clk);
        
        // Push Data 0x102 (o_valid should turn high now)
        i_data  <= 32'h102;
        @(posedge clk);
        
        // Push Data 0x103
        i_data  <= 32'h103;
        @(posedge clk);

        // Stop input
        i_valid <= 0;
        @(posedge clk);
        @(posedge clk); // Allow buffer to drain back to state 0

        // ---------------------------------------------------------------------
        // Test 2: Backpressure Triggering Skid State (State 1 -> State 2)
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: Backpressure & Skid Capture ---");
        // Step A: Load initial item into main_reg (State 1)
        i_valid <= 1;
        i_ready <= 1;
        i_data  <= 32'hA0;
        @(posedge clk);

        // Step B: Downstream stalls (i_ready=0), Upstream sends new data (i_valid=1)
        // main_reg holds 0xA0, incoming 0xB0 must go to skid_reg
        i_ready <= 0;
        i_data  <= 32'hB0;
        @(posedge clk);

        // Step C: Verify o_ready went LOW (state=2, Full)
        #1; // Wait small offset for assign logic evaluation
        if (o_ready === 0) begin
            $display("[PASS] Backpressure asserted (o_ready = 0) in Skid state.");
        end else begin
            $display("[FAIL] o_ready should be 0 during Skid state!");
        end

        // ---------------------------------------------------------------------
        // Test 3: Downstream Re-opens & Drains Skid Register (State 2 -> State 1)
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: Re-opening Downstream and Draining ---");
        // Upstream must hold valid low because o_ready was 0 on previous cycle
        i_valid <= 0; 
        
        // Downstream accepts data (i_ready = 1)
        i_ready <= 1;
        @(posedge clk); // skid_reg (0xB0) moves to main_reg
        
        #1;
        if (o_data === 32'hB0 && o_ready === 1) begin
            $display("[PASS] Skid register successfully shifted to main output. o_data = 0x%h", o_data);
        end else begin
            $display("[FAIL] Expected o_data = 0xB0, got 0x%h", o_data);
        end

        // Drain final item
        i_ready <= 1;
        @(posedge clk);
        
        #1;
        if (dut.state === 0) begin
            $display("[PASS] Skid Buffer successfully drained back to Empty state.");
        end

        $display("\n[TB] All tests completed.");
        $finish;
    end

    // Monitor Outputs
    initial begin
        $monitor("Time=%0t | State=%0d | i_valid=%b i_ready=%b | o_valid=%b o_ready=%b | i_data=0x%h o_data=0x%h",
                 $time, dut.state, i_valid, i_ready, o_valid, o_ready, i_data, o_data);
    end

endmodule