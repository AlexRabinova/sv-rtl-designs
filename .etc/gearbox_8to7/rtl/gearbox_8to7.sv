`timescale 1ns/1ps

module gearbox_8to7 (
    input  logic       clk,
    input  logic       rst_n,

    // 8-bit Upstream Interface
    input  logic       in_valid,
    output logic       in_ready,
    input  logic [7:0] in_data,

    // 7-bit Downstream Interface
    output logic       out_valid,
    input  logic       out_ready,
    output logic [6:0] out_data
);

    typedef enum logic [2:0] {
        S0 = 3'd0, // 0 leftovers carried in; load R1..R8
        S1 = 3'd1, // 1 leftover  in R1;       load R2..R9
        S2 = 3'd2, // 2 leftovers in R1..R2;   load R3..R10
        S3 = 3'd3, // 3 leftovers in R1..R3;   load R4..R11
        S4 = 3'd4, // 4 leftovers in R1..R4;   load R5..R12
        S5 = 3'd5, // 5 leftovers in R1..R5;   load R6..R13
        S6 = 3'd6, // 6 leftovers in R1..R6;   load R7..R14 (all 14 full)
        S7 = 3'd7  // 7 leftovers in R1..R7;   stall input, drain R1..R7
    } state_t;

    state_t      state_q, state_d;
    logic [13:0] reg_buf_q;   // R1..R14 mapped to [0]..[13]
    logic        out_valid_q;

    logic        in_fire;
    logic        out_fire;

    assign in_fire  = in_valid && in_ready;
    assign out_fire = out_valid_q && out_ready;

    // ========================================================================
    // STAGE 1: Sequential State Register
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= S0;
        end else begin
            state_q <= state_d;
        end
    end

    // ========================================================================
    // STAGE 2: Combinational Next-State Logic
    // ========================================================================
    always_comb begin
        state_d = state_q;

        case (state_q)
            S0: if (in_fire)  state_d = S1;
            S1: if (in_fire)  state_d = S2;
            S2: if (in_fire)  state_d = S3;
            S3: if (in_fire)  state_d = S4;
            S4: if (in_fire)  state_d = S5;
            S5: if (in_fire)  state_d = S6;
            S6: if (in_fire)  state_d = S7;
            S7: if (out_fire) state_d = S0;
            default:          state_d = S0;
        endcase
    end

    // ========================================================================
    // STAGE 3: Output Logic & Registered Datapath (14-Bit Shift/Load Buffer)
    // ========================================================================
    // Combinational handshake & output assignments
    assign in_ready  = (state_q != S7) && (!out_valid_q || out_ready);
    assign out_valid = out_valid_q;
    assign out_data  = reg_buf_q[6:0]; // Hardwired to R1..R7

    // Sequential datapath update driven by current state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_buf_q   <= 14'd0;
            out_valid_q <= 1'b0;
        end else if (state_q == S7) begin
            if (out_fire) begin
                reg_buf_q   <= 14'd0;
                out_valid_q <= 1'b0;
            end
        end else if (in_fire) begin
            out_valid_q <= 1'b1;

            case (state_q)
                S0: begin
                    reg_buf_q       <= 14'd0;
                    reg_buf_q[7:0]  <= in_data;
                end
                S1: begin
                    reg_buf_q       <= 14'd0;
                    reg_buf_q[0]    <= reg_buf_q[7];
                    reg_buf_q[8:1]  <= in_data;
                end
                S2: begin
                    reg_buf_q       <= 14'd0;
                    reg_buf_q[1:0]  <= reg_buf_q[8:7];
                    reg_buf_q[9:2]  <= in_data;
                end
                S3: begin
                    reg_buf_q       <= 14'd0;
                    reg_buf_q[2:0]  <= reg_buf_q[9:7];
                    reg_buf_q[10:3] <= in_data;
                end
                S4: begin
                    reg_buf_q       <= 14'd0;
                    reg_buf_q[3:0]  <= reg_buf_q[10:7];
                    reg_buf_q[11:4] <= in_data;
                end
                S5: begin
                    reg_buf_q       <= 14'd0;
                    reg_buf_q[4:0]  <= reg_buf_q[11:7];
                    reg_buf_q[12:5] <= in_data;
                end
                S6: begin
                    reg_buf_q[5:0]  <= reg_buf_q[12:7];
                    reg_buf_q[13:6] <= in_data;
                end
                default: begin
                    reg_buf_q       <= 14'd0;
                end
            endcase
        end else if (out_fire) begin
            // Downstream accepted R1..R7 while upstream paused: shift R8..R14 down
            reg_buf_q[6:0]  <= reg_buf_q[13:7];
            reg_buf_q[13:7] <= 7'd0;
            out_valid_q     <= 1'b0;
        end
    end

endmodule