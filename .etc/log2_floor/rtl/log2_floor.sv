module log2_floor #(
    parameter int WIDTH = 8
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [WIDTH-1:0]         din,
    output logic [$clog2(WIDTH)-1:0] dout,
    output logic                     done
);

    // Output bus width dynamically sized to hold max log value
    localparam int LOG_WIDTH = $clog2(WIDTH);

    // FSM States
    typedef enum logic [1:0] {
        IDLE  = 2'b01,
        SHIFT = 2'b10,
        DONE  = 2'b11
    } state_t;

    state_t state, next_state;

    logic [WIDTH-1:0]     shift_reg, next_shift_reg;
    logic [LOG_WIDTH-1:0] count, next_count;

    // 1. Sync block: updates state and datapath registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            shift_reg <= '0;
            count     <= '0;
        end else begin
            state     <= next_state;
            shift_reg <= next_shift_reg;
            count     <= next_count;
        end
    end

    // 2. Next-state block: computes next state and next register values
    always_comb begin
        next_state     = state;
        next_shift_reg = shift_reg;
        next_count     = count;

        case (state)
            IDLE: begin
                if (start) begin
                    if (din == '0) begin
                        next_shift_reg = '0;
                        next_count     = '0;
                        next_state     = DONE;
                    end else if (din == 1'b1) begin
                        // Edge case: log2(1) = 0, no shifts needed
                        next_shift_reg = din;
                        next_count     = '0;
                        next_state     = DONE;
                    end else begin
                        next_shift_reg = din;
                        next_count     = '0;
                        next_state     = SHIFT;
                    end
                end
            end

            SHIFT: begin
                // Shift right as long as value is greater than 1
                if (shift_reg > 1'b1) begin
                    next_shift_reg = {1'b0, shift_reg[WIDTH-1:1]};
                    next_count     = count + 1'b1;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state     = IDLE;
                next_shift_reg = '0;
                next_count     = '0;
            end
        endcase
    end

    // 3. Output-state block: drives outputs from current state and registers
    always_comb begin
        done = 1'b0;
        dout = '0;

        case (state)
            DONE: begin
                done = 1'b1;
                dout = count; // Directly output the count, no subtraction
            end

            default: begin
                done = 1'b0;
                dout = '0;
            end
        endcase
    end

endmodule