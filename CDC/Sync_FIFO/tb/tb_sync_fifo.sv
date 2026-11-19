`timescale 1ns/1ps

module tb_sync_fifo;

    // Parameters matching DUT
    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 4;
    localparam CLK_PERIOD = 10;

    // DUT Signals
    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] din;
    logic                  full;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] dout;
    logic                  valid_out;
    logic                  empty;

    // Instantiate Device Under Test (DUT)
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .din(din),
        .full(full),
        .rd_en(rd_en),
        .dout(dout),
        .valid_out(valid_out),
        .empty(empty)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Tracking Variables
    int error_count = 0;

    // -------------------------------------------------------------
    // Helper Tasks
    // -------------------------------------------------------------
    task automatic reset_fifo();
        rst_n <= 1'b0;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        din   <= '0;
        repeat (2) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    task automatic write_data(input logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        wr_en <= 1'b1;
        din   <= data;
        @(posedge clk);
        wr_en <= 1'b0;
    endtask;

    task automatic read_data();
        @(posedge clk);
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
    endtask;

    // -------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------
    initial begin
        clk = 0;
        
        $display("\n==================================================");
        $display("   STARTING SYNCHRONOUS FIFO TESTBENCH VERIFICATION");
        $display("==================================================\n");

        // TEST 1: Power-on Reset & Initial Flags Check
        $display("[TEST 1] Checking Reset State...");
        reset_fifo();
        if (!empty || full) begin
            $error("[FAIL] Post-reset state invalid! empty=%b (exp 1), full=%b (exp 0)", empty, full);
            error_count++;
        end else begin
            $display("[PASS] Reset state clean: FIFO is empty.");
        end

        // TEST 2: Underflow Test (Reading when EMPTY)
        $display("\n[TEST 2] Checking Underflow Guard (Read when empty)...");
        read_data();
        if (valid_out !== 1'b0) begin
            $error("[FAIL] valid_out high on empty read! valid_out=%b", valid_out);
            error_count++;
        end else begin
            $display("[PASS] Read ignored when empty. valid_out remained 0.");
        end

        // TEST 3: Basic Write & Read-Latency Verification (Standard FIFO check)
        $display("\n[TEST 3] Checking Write & 1-Cycle Read Latency...");
        write_data(8'hA5); // Fill 1 slot
        
        // Assert rd_en and verify timing
        @(posedge clk);
        rd_en <= 1'b1;
        
        // Before clock edge: verify standard FIFO behavior (Data is not fall-through)
        #1; 
        if (valid_out === 1'b1) begin
            $display("[NOTE] FIFO presents data combinational/FWFT style.");
        end

        @(posedge clk); // Clock edge captures read
        rd_en <= 1'b0;
        #1; // Sample output after edge
        
        if (valid_out === 1'b1 && dout === 8'hA5) begin
            $display("[PASS] Standard 1-cycle latency verified! Received dout = 0x%0h, valid_out = 1", dout);
        end else begin
            $error("[FAIL] Standard read failed! Received dout = 0x%0h (exp 0xA5), valid_out = %b (exp 1)", dout, valid_out);
            error_count++;
        end

        // TEST 4: Filling to Capacity & Overflow Guard
        $display("\n[TEST 4] Filling FIFO to DEPTH (%0d) & Testing Overflow...", DEPTH);
        reset_fifo();
        
        for (int i = 0; i < DEPTH; i++) begin
            write_data(8'h10 + i);
        end

        #1;
        if (!full) begin
            $error("[FAIL] FIFO should be FULL after %0d writes!", DEPTH);
            error_count++;
        end else begin
            $display("[PASS] FIFO full flag asserted correctly.");
        end

        // Attempt write when full
        write_data(8'hFF); // Should be ignored
        #1;
        if (full !== 1'b1) begin
            $error("[FAIL] Full flag dropped unexpectedly after overflow attempt.");
            error_count++;
        end else begin
            $display("[PASS] Overflow write attempt safely guarded.");
        end

        // TEST 5: Sequential Readout of Full Data & Valid Pulse Tracking
        $display("\n[TEST 5] Draining FIFO & Validating Data Integrity...");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            rd_en <= 1'b1;
            @(posedge clk);
            rd_en <= 1'b0;
            #1;
            
            if (valid_out !== 1'b1 || dout !== (8'h10 + i)) begin
                $error("[FAIL] Read step %0d failed! Received dout=0x%0h (exp 0x%0h), valid_out=%b", 
                        i, dout, (8'h10 + i), valid_out);
                error_count++;
            end
        end

        // Extra clock cycle check for valid_out deassertion
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0) begin
            $error("[FAIL] valid_out did not drop back to 0 after FIFO emptied!");
            error_count++;
        end else begin
            $display("[PASS] All data popped sequentially with correct 1-cycle valid_out pulses.");
        end

        // TEST 6: Simultaneous Read and Write (Throughput Test)
        $display("\n[TEST 6] Testing Simultaneous Read and Write...");
        reset_fifo();
        write_data(8'h33); // Put 1 item in FIFO first

        @(posedge clk);
        wr_en <= 1'b1;
        din   <= 8'h44;
        rd_en <= 1'b1;
        
        @(posedge clk);
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        #1;

        if (valid_out === 1'b1 && dout === 8'h33) begin
            $display("[PASS] Simultaneous R/W: Old data 0x33 popped successfully.");
        end else begin
            $error("[FAIL] Simultaneous R/W failed to present old data correctly!");
            error_count++;
        end

        // Pop the newly written data
        read_data();
        #1;
        if (valid_out === 1'b1 && dout === 8'h44) begin
            $display("[PASS] Simultaneous R/W: New data 0x44 stored and read successfully.");
        end else begin
            $error("[FAIL] Simultaneous R/W failed to write new data during read!");
            error_count++;
        end

        // Summary
        $display("\n==================================================");
        if (error_count == 0) begin
            $display("   SUCCESS: ALL TESTS PASSED SUCCESSFULLY!");
        end else begin
            $display("   FAILURE: %0d ERROR(S) DETECTED IN TESTBENCH", error_count);
        end
        $display("==================================================\n");

        $finish;
    end

endmodule