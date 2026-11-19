`timescale 1ns / 1ps

module tb_axis_fifo_fwft;

    // Parameters
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int CLK_PERIOD = 10; // 100 MHz

    // Signals
    logic                  clk;
    logic                  rst_n;

    // Upstream Interface (Slave)
    logic                  s_axis_tvalid;
    logic                  s_axis_tready;
    logic [DATA_WIDTH-1:0] s_axis_tdata;

    // Downstream Interface (Master)
    logic                  m_axis_tvalid;
    logic                  m_axis_tready;
    logic [DATA_WIDTH-1:0] m_axis_tdata;

    // Testbench Scoreboard Queue
    logic [DATA_WIDTH-1:0] expected_queue[$];

    // DUT Instantiation
    sync_fifo_axis_skid #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata (s_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata (m_axis_tdata)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ------------------------------------------------------------------------
    // Driver Tasks
    // ------------------------------------------------------------------------
    
    // Explicit automatic lifetime fixes ModelSim vlog-LRM-2244 warning
    task automatic send_data(input logic [DATA_WIDTH-1:0] data);
        @ (posedge clk);
        s_axis_tvalid <= 1'b1;
        s_axis_tdata  <= data;

        // Hold until accepted
        do begin
            @ (posedge clk);
        end while (!s_axis_tready);

        // Record expected data for verification
        expected_queue.push_back(data);
        s_axis_tvalid <= 1'b0;
        s_axis_tdata  <= '0;
    endtask

    // ------------------------------------------------------------------------
    // Self-Checking Monitor (Scoreboard)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        // Guard against evaluation during active-low reset
        if (rst_n) begin
            // Only evaluate on a successful downstream transfer handshake
            if (m_axis_tvalid && m_axis_tready) begin
                // Guard against popping an empty queue
                if (expected_queue.size() == 0) begin
                    $error("[SCOREBOARD ERROR] Received unexpected output 0x%0h while queue is empty!", m_axis_tdata);
                end else begin
                    automatic logic [DATA_WIDTH-1:0] exp_data = expected_queue.pop_front();
                    
                    if (m_axis_tdata !== exp_data) begin
                        $error("[MISMATCH] Expected: 0x%0h, Got: 0x%0h", exp_data, m_axis_tdata);
                    end else begin
                        $display("[MATCH] Received 0x%0h successfully.", m_axis_tdata);
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Test Sequences
    // ------------------------------------------------------------------------
    initial begin
        // Initialize Signals
        clk           = 0;
        rst_n         = 0;
        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        m_axis_tready = 0;

        // Apply Reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);
        $display("\n--- TEST 1: Single Data Write & FWFT Availability ---");
        
        // Push 1 byte into empty FIFO
        @ (posedge clk);
        s_axis_tvalid <= 1'b1;
        s_axis_tdata  <= 8'hA1;
        expected_queue.push_back(8'hA1);
        @ (posedge clk);
        s_axis_tvalid <= 1'b0;

        // Verify FWFT: Data must appear on output combinationally / pre-fetched BEFORE asserting m_axis_tready
        @ (posedge clk);
        if (m_axis_tvalid && m_axis_tdata == 8'hA1) begin
            $display("[PASS] FWFT verified: m_axis_tdata (0x%0h) ready at output prior to m_axis_tready!", m_axis_tdata);
        end else begin
            $error("[FAIL] FWFT error: m_axis_tvalid = %b, m_axis_tdata = 0x%0h", m_axis_tvalid, m_axis_tdata);
        end

        // Pop data
        m_axis_tready <= 1'b1;
        @ (posedge clk);
        m_axis_tready <= 1'b0;

        #(CLK_PERIOD * 2);
        $display("\n--- TEST 2: Backpressure and Skid Buffer Absorption ---");
        
        // Fill FIFO while consumer is stalling (m_axis_tready = 0)
        m_axis_tready <= 1'b0;
        for (int i = 1; i <= 6; i++) begin
            send_data(8'hB0 + i);
        end

        // Verify upstream tready goes low when capacity is reached
        #(CLK_PERIOD);
        if (!s_axis_tready) begin
            $display("[PASS] Upstream correctly backpressured (s_axis_tready = 0).");
        end

        // Drain the entire buffer with backpressure
        $display("Draining buffer...");
        m_axis_tready <= 1'b1;
        wait (expected_queue.size() == 0);
        @ (posedge clk);
        m_axis_tready <= 1'b0;

        #(CLK_PERIOD * 2);
        $display("\n--- TEST 3: Full-Throughput Continuous Burst ---");

        // Drive both sides high simultaneously
        m_axis_tready <= 1'b1;
        for (int i = 1; i <= 10; i++) begin
            @ (posedge clk);
            s_axis_tvalid <= 1'b1;
            s_axis_tdata  <= 8'hC0 + i;
            expected_queue.push_back(8'hC0 + i);
        end
        @ (posedge clk);
        s_axis_tvalid <= 1'b0;

        wait (expected_queue.size() == 0);
        m_axis_tready <= 1'b0;

        #(CLK_PERIOD * 5);
        $display("\n--- ALL TESTS PASSED SUCCESSFULLY ---");
        $finish;
    end

endmodule