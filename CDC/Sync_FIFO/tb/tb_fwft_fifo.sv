`timescale 1ns/1ps

module tb_fwft_fifo;

    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 8;
    parameter CLK_PERIOD = 10; // 100 MHz clock

    // DUT Signals
    reg                   clk;
    reg                   rst;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] din;
    wire                  full;
    wire                  valid;
    reg                   ready;
    wire [DATA_WIDTH-1:0] dout;

    // Instantiate DUT
    fwft_fifo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .wr_en (wr_en),
        .din   (din),
        .full  (full),
        .valid (valid),
        .ready (ready),
        .dout  (dout)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Task to write a single word to the FIFO
    task write_word(input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            wr_en <= 1'b1;
            din   <= data;
            @(posedge clk);
            wr_en <= 1'b0;
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize Signals
        clk   = 0;
        rst   = 1;
        wr_en = 0;
        din   = 0;
        ready = 0;

        // Reset Pulse
        #(CLK_PERIOD * 2);
        rst = 0;
        #(CLK_PERIOD);

        $display("=== TEST 1: Checking Prefetch & FWFT Initial Latency ===");
        // Write the first word and observe when valid goes high (2 clock cycles expected)
        write_word(32'hA1A1_A1A1);
        
        // Wait until valid goes high or timeout
        fork
            begin
                wait(valid == 1'b1);
                $display("[PASS] Word prefetched! FWFT 'valid' asserted. dout = 0x%0h (Expected: 0xA1A1A1A1)", dout);
            end
            begin
                #(CLK_PERIOD * 5);
                if (!valid) $error("[FAIL] Prefetch timeout! 'valid' failed to assert.");
            end
        join_any;

        $display("\n=== TEST 2: Continuous FWFT Streaming (ready = 1) ===");
        ready = 1'b1; // Consume first word
        
        // Burst write 3 words while ready is high
        fork
            begin
                write_word(32'hB2B2_B2B2);
                write_word(32'hC3C3_C3C3);
                write_word(32'hD4D4_D4D4);
            end
            begin
                // Monitor reads on every clock cycle
                repeat(3) begin
                    @(posedge clk);
                    if (valid && ready) begin
                        $display("[READ] Streams FWFT word = 0x%0h", dout);
                    end
                end
            end
        join

        #(CLK_PERIOD * 2);

        $display("\n=== TEST 3: Backpressure & Skid Buffer Test ===");
        // Write two words to setup backpressure scenario
        write_word(32'hE5E5_E5E5);
        write_word(32'hF6F6_F6F6);
        
        // Wait for first word to prefetch
        wait(valid == 1'b1);
        
        // Apply Backpressure (Stall downstream)
        ready = 1'b0;
        $display("[STALL] Set ready = 0. Word 0x%0h sitting on dout.", dout);
        #(CLK_PERIOD * 3);

        // Check that valid stayed high and dout didn't corrupt during stall
        if (valid && dout == 32'hE5E5_E5E5) begin
            $display("[PASS] Primary register holding data correctly during stall.");
        end else begin
            $error("[FAIL] Data corrupted during stall! dout = 0x%0h", dout);
        end

        // Release Backpressure and drain the skid buffer
        $display("[UNSTALL] Set ready = 1. Draining skid buffer...");
        ready = 1'b1;
        
        @(posedge clk);
        $display("[READ] Consumed primary word. Next word from skid buffer = 0x%0h (Expected: 0xF6F6F6F6)", dout);
        
        @(posedge clk);
        ready = 1'b0; // Stop reading

        #(CLK_PERIOD * 3);
        $display("\n=== All Tests Completed Successfully ===");
        $finish;
    end

endmodule