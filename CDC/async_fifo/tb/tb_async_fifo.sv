`timescale 1ns/1ps

module tb_async_fifo;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4; // Depth = 16

    // Write Domain Signals
    logic                      wclk;
    logic                      wrst_n;
    logic                      winc;
    logic [DATA_WIDTH-1:0]     wdata;
    logic                      full;

    // Read Domain Signals
    logic                      rclk;
    logic                      rrst_n;
    logic                      rinc;
    logic [DATA_WIDTH-1:0]     rdata;
    logic                      empty;

    // Instantiate the Unit Under Test (UUT)
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_uut (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .winc(winc),
        .wdata(wdata),
        .full(full),
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rinc(rinc),
        .rdata(rdata),
        .empty(empty)
    );

    // -----------------------------------------------------------------
    // Clock Generation (Asynchronous clocks with different frequencies)
    // wclk: 100 MHz (10ns period)
    // rclk: ~71.4 MHz (14ns period)
    // -----------------------------------------------------------------
    initial wclk = 0;
    always #5 wclk = ~wclk;

    initial rclk = 0;
    always #7 rclk = ~rclk;

    // -----------------------------------------------------------------
    // Monitor Read Data
    // -----------------------------------------------------------------
    always @(posedge rclk) begin
        if (rinc && !empty) begin
            $display("[TIME: %0t ns] READ  -> Data: 0x%0h", $time, rdata);
        end
    end

    // -----------------------------------------------------------------
    // Stimulus Sequence
    // -----------------------------------------------------------------
    initial begin
        // Initialize signals
        winc   = 0;
        wdata  = 0;
        rinc   = 0;
        wrst_n = 0;
        rrst_n = 0;

        // Setup VCD waveform dumping for GTKWave
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        // Apply reset
        $display("[TIME: %0t ns] Applying Reset...", $time);
        #30;
        wrst_n = 1;
        rrst_n = 1;
        #20;
        $display("[TIME: %0t ns] Release Reset. Starting tests.", $time);

        // =============================================================
        // Test 1: Write until FULL (Depth = 16)
        // =============================================================
        $display("\n--- Test 1: Writing until FIFO is FULL ---");
        repeat (20) begin
            @(posedge wclk);
            if (!full) begin
                winc  <= 1'b1;
                wdata <= $urandom_range(1, 255);
                $display("[TIME: %0t ns] WRITE -> Data: 0x%0h", $time, wdata);
            end else begin
                winc  <= 1'b0;
                $display("[TIME: %0t ns] FIFO is FULL. Attempted write blocked.", $time);
            end
        end
        @(posedge wclk);
        winc <= 1'b0;

        #40;

        // =============================================================
        // Test 2: Read until EMPTY
        // =============================================================
        $display("\n--- Test 2: Reading until FIFO is EMPTY ---");
        repeat (20) begin
            @(posedge rclk);
            if (!empty) begin
                rinc <= 1'b1;
            end else begin
                rinc <= 1'b0;
                $display("[TIME: %0t ns] FIFO is EMPTY. Attempted read blocked.", $time);
            end
        end
        @(posedge rclk);
        rinc <= 1'b0;

        #40;

        // =============================================================
        // Test 3: Concurrent Read & Write (Async Domain Stress Test)
        // =============================================================
        $display("\n--- Test 3: Concurrent Read/Write ---");
        fork
            // Write thread
            begin
                repeat (12) begin
                    @(posedge wclk);
                    if (!full) begin
                        winc  <= 1'b1;
                        wdata <= $urandom_range(1, 255);
                        $display("[TIME: %0t ns] [CONC] WRITE -> 0x%0h", $time, wdata);
                    end
                end
                @(posedge wclk);
                winc <= 1'b0;
            end
            // Read thread (starts slightly delayed)
            begin
                #25;
                repeat (14) begin
                    @(posedge rclk);
                    if (!empty) begin
                        rinc <= 1'b1;
                    end
                end
                @(posedge rclk);
                rinc <= 1'b0;
            end
        join

        #100;
        $display("\n[TIME: %0t ns] Simulation Completed Successfully!", $time);
        $finish;
    end

endmodule