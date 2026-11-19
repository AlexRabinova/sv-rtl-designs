// =========================================================================
// 1. APB Master Module
// =========================================================================
module apb_master (
    input  logic        clk,
    input  logic        rst_n,
    
    // Command Interface
    input  logic        req_valid,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic        req_write,
    output logic        req_ready,
    
    // APB Bus Signals (Direct Ports)
    output logic [31:0] paddr,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] pwdata,
    input  logic [31:0] prdata,
    input  logic        pready,
    input  logic        pslverr
);

    // FSM States using localparams instead of enums for Icarus compatibility
    localparam logic [1:0] IDLE   = 2'b00;
    localparam logic [1:0] SETUP  = 2'b01;
    localparam logic [1:0] ACCESS = 2'b10;

    logic [1:0] current_state, next_state;

    logic [31:0] addr_reg;
    logic [31:0] wdata_reg;
    logic        write_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            addr_reg      <= '0;
            wdata_reg     <= '0;
            write_reg     <= '0;
        end else begin
            current_state <= next_state;
            if (req_valid && req_ready) begin
                addr_reg  <= req_addr;
                wdata_reg <= req_wdata;
                write_reg <= req_write;
            end
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE:   if (req_valid) next_state = SETUP;
            SETUP:  next_state = ACCESS;
            ACCESS: if (pready) next_state = req_valid ? SETUP : IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_comb begin
        psel    = 1'b0;
        penable = 1'b0;
        paddr   = '0;
        pwrite  = 1'b0;
        pwdata  = '0;
        req_ready = 1'b0;

        case (current_state)
            IDLE: begin
                req_ready = 1'b1;
                if (req_valid) begin
                    psel   = 1'b1;
                    paddr  = req_addr;
                    pwrite = req_write;
                    pwdata = req_wdata;
                end
            end
            SETUP: begin
                psel   = 1'b1;
                paddr  = addr_reg;
                pwrite = write_reg;
                pwdata = wdata_reg;
            end
            ACCESS: begin
                psel    = 1'b1;
                penable = 1'b1;
                paddr   = addr_reg;
                pwrite  = write_reg;
                pwdata  = wdata_reg;
                if (pready && req_valid) req_ready = 1'b1;
            end
        endcase
    end
endmodule