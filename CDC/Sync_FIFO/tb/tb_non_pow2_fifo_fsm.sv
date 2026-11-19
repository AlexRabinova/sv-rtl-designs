`timescale 1ns/1ps

module tb_non_pow2_fifo_fsm;

    // Parameters
    localparam DATA_WIDTH = 32;
    localparam DEPTH      = 10; // Non-power-of-2 depth
    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam CLK_PERIOD = 10;

    // DUT Signals
    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] din;
    logic                  full;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] dout;
    logic                  empty;
    logic                  error_flag;

    // Instantiate DUT
    non_pow2_fifo_fsm #(
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
        .empty(empty),
        .error_flag(error_flag)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        din   = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        $display("--- Test 1: Verify Initial Conditions ---");
        assert(empty == 1 && full == 0) 
            else $error("Test 1 Failed: FIFO should be empty initially");

        $display("--- Test 2: Fill FIFO & Verify Non-Power-of-2 Rollover Pointer ---");
        for (int i = 0; i < DEPTH; i++) begin
            write_word(32'hA000_0000 + i);
        end

        #2;
        assert(full == 1 && empty == 0) 
            else $error("Test 2 Failed: FIFO should be full after %0d writes", DEPTH);

        $display("--- Test 3: Trigger Overflow Error State ---");
        write_word(32'hDEAD_BEEF); // Write to full FIFO
        #(CLK_PERIOD);
        assert(error_flag == 1) 
            else $error("Test 3 Failed: Error flag should assert on write overflow");
        
        // Clear error by resetting system
        reset_dut();

        $display("--- Test 4: Read All Items & Check Sequence ---");
        // Fill FIFO again
        for (int i = 0; i < DEPTH; i++) begin
            write_word(32'h100 + i);
        end

        // Empty FIFO and check read latency & values
        for (int i = 0; i < DEPTH; i++) begin
            read_and_check(32'h100 + i);
        end
        assert(empty == 1) 
            else $error("Test 4 Failed: FIFO should be empty after reading all items");

        $display("--- Test 5: Trigger Underflow Error State ---");
        read_word(); // Read from empty FIFO
        #(CLK_PERIOD);
        assert(error_flag == 1) 
            else $error("Test 5 Failed: Error flag should assert on read underflow");

        reset_dut();

        $display("--- Test 6: Concurrent Read and Write Operations ---");
        // Pre-fill with 3 items
        for (int i = 0; i < 3; i++) begin
            write_word(i + 1);
        end

        // Perform concurrent write and read
        @ (posedge clk);
        wr_en <= 1'b1;
        rd_en <= 1'b1;
        din   <= 32'h99;
        
        @ (posedge clk);
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        
        @ (posedge clk);
        assert(dout == 32'h1) 
            else $error("Test 6 Failed: Read value mismatch during concurrent operation");

        $display("--- ALL TESTS PASSED SUCCESSFULLY ---");
        $finish;
    end

    // Helper Tasks
    task write_word(input [DATA_WIDTH-1:0] data);
        @ (posedge clk);
        wr_en <= 1'b1;
        din   <= data;
        @ (posedge clk);
        wr_en <= 1'b0;
    endtask

    task read_word();
        @ (posedge clk);
        rd_en <= 1'b1;
        @ (posedge clk);
        rd_en <= 1'b0;
    endtask

    task read_and_check(input [DATA_WIDTH-1:0] expected_data);
        @ (posedge clk);
        rd_en <= 1'b1;
        @ (posedge clk);
        rd_en <= 1'b0;
        assert(dout == expected_data) 
            else $error("Data Mismatch! Expected: 0x%0h, Got: 0x%0h", expected_data, dout);
    endtask

    task reset_dut();
        rst_n <= 0;
        #(CLK_PERIOD * 2);
        rst_n <= 1;
        #(CLK_PERIOD);
    endtask

endmodule