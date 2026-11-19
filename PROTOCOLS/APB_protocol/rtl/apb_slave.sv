// =========================================================================
// 2. APB Slave Module
// =========================================================================
module apb_slave #(
    parameter int DEPTH = 16
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // APB Bus Signals (Direct Ports)
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);

    logic [31:0] mem [0:DEPTH-1];
    logic trans_active;
    assign trans_active = psel && penable;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) mem[i] <= '0;
        end else if (trans_active && pready) begin
            if (pwrite) mem[paddr[3:2]] <= pwdata;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prdata <= '0;
        end else if (psel && !penable && !pwrite) begin
            prdata <= mem[paddr[3:2]];
        end
    end

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

endmodule