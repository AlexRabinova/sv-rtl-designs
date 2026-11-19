`timescale 1ns/1ps

// =====================================================================
// 1. Top-Level Async FIFO Module
// =====================================================================
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4   // Depth = 2^ADDR_WIDTH (e.g., 4 -> 16 locations)
)(
    // Write Clock Domain
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  full,

    // Read Clock Domain
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  empty
);

    // Internal wires connecting control and memory
    logic [ADDR_WIDTH:0] wptr, rptr;
    logic [ADDR_WIDTH:0] wq2_rptr, rq2_wptr;
    logic [ADDR_WIDTH-1:0] waddr, raddr;
    logic                  wfull, rempty;
    logic                  wclken;

    assign full  = wfull;
    assign empty = rempty;
    assign wclken = winc & ~wfull;

    // Read Pointer & Empty Flag Generation (Read Domain)
    rptr_empty #(ADDR_WIDTH) u_rptr_empty (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rinc(rinc),
        .rq2_wptr(rq2_wptr),
        .raddr(raddr),
        .rptr(rptr),
        .rempty(rempty)
    );

    // Write Pointer & Full Flag Generation (Write Domain)
    wptr_full #(ADDR_WIDTH) u_wptr_full (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .winc(winc),
        .wq2_rptr(wq2_rptr),
        .waddr(waddr),
        .wptr(wptr),
        .wfull(wfull)
    );

    // 2FF Synchronizer: Read Pointer to Write Domain
    sync_flop #(ADDR_WIDTH + 1) u_sync_r2w (
        .clk(wclk),
        .rst_n(wrst_n),
        .d_in(rptr),
        .d_out(wq2_rptr)
    );

    // 2FF Synchronizer: Write Pointer to Read Domain
    sync_flop #(ADDR_WIDTH + 1) u_sync_w2r (
        .clk(rclk),
        .rst_n(rrst_n),
        .d_in(wptr),
        .d_out(rq2_wptr)
    );

    // Dual-Port RAM / Register Array
    fifo_mem #(DATA_WIDTH, ADDR_WIDTH) u_fifo_mem (
        .wclk(wclk),
        .wclken(wclken),
        .waddr(waddr),
        .wdata(wdata),
        .rclk(rclk),
        .raddr(raddr),
        .rdata(rdata)
    );

endmodule


// =====================================================================
// 2. Dual-Port RAM Module
// =====================================================================
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input  logic                  wclk,
    input  logic                  wclken,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic                  rclk,
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [DATA_WIDTH-1:0] rdata
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always_ff @(posedge wclk) begin
        if (wclken) begin
            mem[waddr] <= wdata;
        end
    end

    always_ff @(posedge rclk) begin
        rdata <= mem[raddr];
    end

endmodule


// =====================================================================
// 3. 2-Flip-Flop Synchronizer (Gray Code Pointers)
// =====================================================================
module sync_flop #(
    parameter WIDTH = 5
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] d_out
);

    logic [WIDTH-1:0] q1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1    <= '0;
            d_out <= '0;
        end else begin
            q1    <= d_in;
            d_out <= q1;
        end
    end

endmodule


// =====================================================================
// 4. Read Pointer & Empty Logic (Read Domain)
// =====================================================================
module rptr_empty #(
    parameter ADDR_WIDTH = 4
)(
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    input  logic [ADDR_WIDTH:0]   rq2_wptr,
    output logic [ADDR_WIDTH-1:0] raddr,
    output logic [ADDR_WIDTH:0]   rptr,
    output logic                  rempty
);

    logic [ADDR_WIDTH:0] rbin, rbin_next, rgray_next;
    logic                 rempty_val;

    assign raddr = rbin[ADDR_WIDTH-1:0];
    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= '0;
            rptr <= '0;
        end else begin
            rbin <= rbin_next;
            rptr <= rgray_next;
        end
    end

    assign rempty_val = (rgray_next == rq2_wptr);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rempty <= 1'b1;
        end else begin
            rempty <= rempty_val;
        end
    end

endmodule


// =====================================================================
// 5. Write Pointer & Full Logic (Write Domain)
// =====================================================================
module wptr_full #(
    parameter ADDR_WIDTH = 4
)(
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [ADDR_WIDTH:0]   wq2_rptr,
    output logic [ADDR_WIDTH-1:0] waddr,
    output logic [ADDR_WIDTH:0]   wptr,
    output logic                  wfull
);

    logic [ADDR_WIDTH:0] wbin, wbin_next, wgray_next;
    logic                 wfull_val;

    assign waddr = wbin[ADDR_WIDTH-1:0];
    assign wbin_next  = wbin + (winc & ~wfull);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= '0;
            wptr <= '0;
        end else begin
            wbin <= wbin_next;
            wptr <= wgray_next;
        end
    end

    assign wfull_val = (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], 
                                      wq2_rptr[ADDR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wfull <= 1'b0;
        end else begin
            wfull <= wfull_val;
        end
    end

endmodule