module vr_register_slice #(
    parameter int DATA_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Upstream (Input from Producer)
    input  logic                    s_valid,
    output logic                    s_ready,
    input  logic [DATA_WIDTH-1:0]   s_data,
    
    // Downstream (Output to Consumer)
    output logic                    m_valid,
    input  logic                    m_ready,
    output logic [DATA_WIDTH-1:0]   m_data
);

    // Internal skid buffer storage
    logic [DATA_WIDTH-1:0] reg_data;
    logic                  reg_valid;

    // Upstream is ready as long as the skid buffer is empty.
    // (When reg_valid is 0, we can always absorb one more piece of data if needed).
    assign s_ready = !reg_valid;

    // Main Output Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= '0;
        end else if (m_ready || !m_valid) begin
            if (reg_valid) begin
                // Consume data from the skid buffer
                m_valid <= 1'b1;
                m_data  <= reg_data;
            end else begin
                // Pass-through directly from upstream
                m_valid <= s_valid;
                m_data  <= s_data;
            end
        end
    end

    // Skid Buffer Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_valid <= 1'b0;
            reg_data  <= '0;
        end else begin
            if (!m_ready) begin
                // Downstream is stalling. If upstream sends data while our main register 
                // is already valid, stash it into the skid buffer.
                if (s_valid && s_ready) begin
                    reg_valid <= 1'b1;
                    reg_data  <= s_data;
                end
            end else begin
                // Downstream accepted the main register data. 
                // If the skid buffer had data, it was just promoted to main, so clear the skid buffer.
                // If the skid buffer didn't have data, keep it empty (or grab from s_valid if needed).
                if (reg_valid) begin
                    reg_valid <= 1'b0;
                end
            end
        end
    end

endmodule