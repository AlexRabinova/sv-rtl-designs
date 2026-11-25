`timescale 1ns/1ps

module tb_gearbox_8to7;

    logic       clk;
    logic       rst_n;
    logic       in_valid;
    logic       in_ready;
    logic [7:0] in_data;
    logic       out_valid;
    logic       out_ready;
    logic [6:0] out_data;

    gearbox_8to7 dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .in_data   (in_data),
        .out_valid (out_valid),
        .out_ready (out_ready),
        .out_data  (out_data)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Waveform dump
    initial begin
        $dumpfile("gearbox_8to7.vcd");
        $dumpvars(0, tb_gearbox_8to7);
    end

    // Bit-level scoreboard queue
    bit expected_bits[$];
    int bytes_sent   = 0;
    int words_rcvd   = 0;
    int error_count  = 0;

    localparam int NUM_BYTES = 28; // 4 full 7-byte frames = 224 bits = 32 output words

    // Monitor accepted 8-bit inputs
    always @(posedge clk) begin
        if (rst_n && in_valid && in_ready) begin
            for (int i = 0; i < 8; i++) begin
                expected_bits.push_back(in_data[i]);
            end
            bytes_sent++;
        end
    end

    // Check accepted 7-bit outputs against expected bitstream
    always @(posedge clk) begin
        if (rst_n && out_valid && out_ready) begin
            if (expected_bits.size() < 7) begin
                $error("[%0t] Underflow: received 7-bit word %02h with only %0d expected bits!",
                       $time, out_data, expected_bits.size());
                error_count++;
            end else begin
                logic [6:0] exp_word;
                for (int i = 0; i < 7; i++) begin
                    exp_word[i] = expected_bits.pop_front();
                end
                if (out_data !== exp_word) begin
                    $error("[%0t] Mismatch on word #%0d: got 7'b%07b, expected 7'b%07b",
                           $time, words_rcvd, out_data, exp_word);
                    error_count++;
                end
            end
            words_rcvd++;
        end
    end

    // Stimulus
    initial begin
        rst_n    = 1'b0;
        in_valid = 1'b0;
        in_data  = 8'h00;
        out_ready = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Phase 1: Continuous full-throughput streaming (2 frames = 14 bytes -> 16 words)
        out_ready <= 1'b1;
        for (int b = 0; b < 14; b++) begin
            in_valid <= 1'b1;
            in_data  <= 8'hA0 + b[7:0];
            do begin
                @(posedge clk);
            end while (!in_ready);
        end
        in_valid <= 1'b0;

        // Wait for pipeline to drain
        repeat (5) @(posedge clk);

        // Phase 2: Randomized valid/ready stalls (2 frames = 14 bytes -> 16 words)
        for (int b = 14; b < NUM_BYTES; b++) begin
            // Random idle bubble before asserting in_valid
            repeat ($urandom_range(0, 2)) begin
                in_valid  <= 1'b0;
                out_ready <= $urandom_range(0, 1);
                @(posedge clk);
            end

            in_valid <= 1'b1;
            in_data  <= $urandom_range(0, 255);
            do begin
                out_ready <= $urandom_range(0, 1);
                @(posedge clk);
            end while (!in_ready);
        end

        in_valid  <= 1'b0;
        out_ready <= 1'b1;
        repeat (10) @(posedge clk);

        // Final Summary
        if (error_count == 0 && expected_bits.size() == 0 && words_rcvd == (NUM_BYTES * 8) / 7) begin
            $display("PASS: Transferred %0d bytes -> %0d 7-bit words with 0 errors.",
                     bytes_sent, words_rcvd);
        end else begin
            $display("FAIL: errors=%0d, leftover_bits=%0d, words_rcvd=%0d",
                     error_count, expected_bits.size(), words_rcvd);
        end

        $finish;
    end

endmodule