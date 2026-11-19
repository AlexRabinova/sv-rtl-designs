module poly_system (
    input  logic        clk,
    input  logic        rst_n,      // Asynchronous active-low reset
    input  logic        valid,      // Trigger from input producer
    input  logic [7:0]  x,          // 8-bit input x
    output logic [7:0]  y,          // 8-bit output y = x^3 + x^2 + x
    output logic        hold,       // Tells producer to hold input stable
    output logic        finish      // High when computation is complete
);

    // FSM State Definition
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        ST_A = 2'b01,
        ST_B = 2'b10,
        ST_C = 2'b11
    } state_t;

    state_t current_state, next_state;

    // Control and Datapath internal signals
    logic        sel;
    logic [7:0]  mux_out;
    logic [8:0]  adder_out;   // 9-bit to prevent overflow on +1 addition
    logic [15:0] mult_out;  // 16-bit multiplication result
    logic [7:0]  reg_in;
    logic [7:0]  reg_out;

    // ==========================================
    // DATAPATH LOGIC
    // ==========================================

    // 1. MUX: sel = 0 selects raw input x, sel = 1 selects register feedback
    assign mux_out = (sel == 1'b0) ? x : reg_out;

    // 2. Full Adder: mux_out + 1
    assign adder_out = mux_out + 8'd1;

    // 3. Multiplier: (adder_out) * x
    assign mult_out = adder_out * x;

    // Truncate multiplier output back to 8 bits for standard datapath width
    assign reg_in = mult_out[7:0];

    // 4. Output Register (with async reset)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_out <= 8'd0;
        end else begin
            reg_out <= reg_in;
        end
    end

    // Assign final output
    assign y = reg_out;


    // ==========================================
    // CONTROL PATH (FSM)
    // ==========================================

    // State Transition Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State & Control Signal Logic
    always_comb begin
        // Default values
        next_state = current_state;
        sel        = 1'b0;
        hold       = 1'b0;
        finish     = 1'b0;

        case (current_state)
            IDLE: begin
                sel  = 1'b0;
                hold = 1'b0;
                if (valid) begin
                    next_state = ST_A;
                end else begin
                    next_state = IDLE;
                end
            end

            ST_A: begin
                sel  = 1'b0; // Select raw input x
                hold = 1'b1; // Tell producer to hold input stable
                next_state = ST_B;
            end

            ST_B: begin
                sel  = 1'b1; // Select feedback from register
                hold = 1'b1; // Keep hold active
                next_state = ST_C;
            end

            ST_C: begin
                sel    = 1'b0;
                hold   = 1'b0; // Release hold
                finish = 1'b1; // Signal completion
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule