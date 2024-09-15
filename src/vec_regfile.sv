`include "../define/vec_regfile_defs.svh"
`include "../define/vector_processor_defs.svh"

module vec_regfile (
    // Inputs
    input   logic                           clk, reset,
    input   logic   [ADDR_WIDTH-1:0]        raddr_1, raddr_2,  // The address of the vector registers to be read
    input   logic   [DATA_WIDTH-1:0]        wdata,             // The vector that is to be written in the vector register
    input   logic   [ADDR_WIDTH-1:0]        waddr,             // The address of the vector register where the vector is written
    input   logic                           wr_en,             // The enable signal to write in the vector register 
    input   logic   [3:0]                   lmul,              // LMUL value (controls register granularity)

    // Outputs 
    output  logic   [DATA_WIDTH-1:0]        rdata_1, rdata_2,  // The read data from the vector register file
    output  logic   [VECTOR_LENGTH-1:0]     vector_length,     // Width of the vector depending on LMUL
    output  logic                           wrong_addr         // Signal to indicate an invalid address
);

    // Fixed-size Vector Register File (VLEN and MAX_VEC_REGISTERS)
    logic [`VLEN-1:0] vec_regfile [`MAX_VEC_REGISTERS-1:0];

    // Dynamically calculate vector length and number of registers based on LMUL
    always_comb begin
        
        vector_length = `VLEN;
        
        case (lmul)
            4'b0001: vector_length = `VLEN;        // LMUL = 1
            4'b0010: vector_length = 2 * `VLEN;    // LMUL = 2
            4'b0100: vector_length = 4 * `VLEN;    // LMUL = 4
            4'b1000: vector_length = 8 * `VLEN;    // LMUL = 8
            default: vector_length = `VLEN;
        endcase
    end

    // Address validation and read operation
    logic addr_error; // Temporary signal for address error checking
    always_comb begin
        // Default values for rdata and addr_error
        rdata_1 = 'h0;
        rdata_2 = 'h0;
        addr_error = 0;

        case (lmul)
            4'b0001: begin // LMUL = 1
                if (raddr_1 >= `MAX_VEC_REGISTERS || raddr_2 >= `MAX_VEC_REGISTERS) begin
                    addr_error = 1;
                end else begin
                    rdata_1 = vec_regfile[raddr_1];
                    rdata_2 = vec_regfile[raddr_2];
                end
            end
            4'b0010: begin // LMUL = 2
                if (raddr_1 >= `MAX_VEC_REGISTERS - 1 || raddr_2 >= `MAX_VEC_REGISTERS - 1 ||
                    raddr_1 % 2 != 0 || raddr_2 % 2 != 0) begin
                    addr_error = 1;
                end else begin
                    rdata_1 = {vec_regfile[raddr_1 + 1], vec_regfile[raddr_1]};
                    rdata_2 = {vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                end
            end
            4'b0100: begin // LMUL = 4
                if (raddr_1 >= `MAX_VEC_REGISTERS - 3 || raddr_2 >= `MAX_VEC_REGISTERS - 3 ||
                    raddr_1 % 4 != 0 || raddr_2 % 4 != 0) begin
                    addr_error = 1;
                end else begin
                    rdata_1 = {vec_regfile[raddr_1 + 3], vec_regfile[raddr_1 + 2], vec_regfile[raddr_1 + 1], vec_regfile[raddr_1]};
                    rdata_2 = {vec_regfile[raddr_2 + 3], vec_regfile[raddr_2 + 2], vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                end
            end
            4'b1000: begin // LMUL = 8
                if (raddr_1 >= `MAX_VEC_REGISTERS - 7 || raddr_2 >= `MAX_VEC_REGISTERS - 7 ||
                    raddr_1 % 8 != 0 || raddr_2 % 8 != 0) begin
                    addr_error = 1;
                end else begin
                    rdata_1 = {vec_regfile[raddr_1 + 7], vec_regfile[raddr_1 + 6], vec_regfile[raddr_1 + 5], vec_regfile[raddr_1 + 4],
                               vec_regfile[raddr_1 + 3], vec_regfile[raddr_1 + 2], vec_regfile[raddr_1 + 1], vec_regfile[raddr_1]};
                    rdata_2 = {vec_regfile[raddr_2 + 7], vec_regfile[raddr_2 + 6], vec_regfile[raddr_2 + 5], vec_regfile[raddr_2 + 4],
                               vec_regfile[raddr_2 + 3], vec_regfile[raddr_2 + 2], vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                end
            end
            default: addr_error = 1;
        endcase
    end

    // Write operation and error handling for both read and write addresses
    always_ff @(negedge clk or negedge reset) begin
        if (!reset) begin
            // Reset all registers
            for (int i = 0; i < `MAX_VEC_REGISTERS; i++) begin
                vec_regfile[i] <= 'h0;
            end
            wrong_addr <= 0;
        end else begin          
            if (wr_en) begin
                // Check for valid write addresses
                case (lmul)
                    4'b0001: begin
                        if (waddr >= `MAX_VEC_REGISTERS) begin
                            wrong_addr <= 1;
                        end else begin
                            vec_regfile[waddr] <= wdata[`VLEN-1:0];
                        end
                    end
                    4'b0010: begin
                        if (waddr >= `MAX_VEC_REGISTERS - 1 || waddr % 2 != 0) begin
                            wrong_addr <= 1;
                        end else begin
                            vec_regfile[waddr]     <= wdata[`VLEN-1:0];
                            vec_regfile[waddr + 1] <= wdata[2*`VLEN-1:`VLEN];
                        end
                    end
                    4'b0100: begin
                        if (waddr >= `MAX_VEC_REGISTERS - 3 || waddr % 4 != 0) begin
                            wrong_addr <= 1;
                        end else begin
                            vec_regfile[waddr]     <= wdata[`VLEN-1:0];
                            vec_regfile[waddr + 1] <= wdata[2*`VLEN-1:`VLEN];
                            vec_regfile[waddr + 2] <= wdata[3*`VLEN-1:2*`VLEN];
                            vec_regfile[waddr + 3] <= wdata[4*`VLEN-1:3*`VLEN];
                        end
                    end
                    4'b1000: begin
                        if (waddr >= `MAX_VEC_REGISTERS - 7 || waddr % 8 != 0) begin
                            wrong_addr <= 1;
                        end else begin
                            vec_regfile[waddr]     <= wdata[`VLEN-1:0];
                            vec_regfile[waddr + 1] <= wdata[2*`VLEN-1:`VLEN];
                            vec_regfile[waddr + 2] <= wdata[3*`VLEN-1:2*`VLEN];
                            vec_regfile[waddr + 3] <= wdata[4*`VLEN-1:3*`VLEN];
                            vec_regfile[waddr + 4] <= wdata[5*`VLEN-1:4*`VLEN];
                            vec_regfile[waddr + 5] <= wdata[6*`VLEN-1:5*`VLEN];
                            vec_regfile[waddr + 6] <= wdata[7*`VLEN-1:6*`VLEN];
                            vec_regfile[waddr + 7] <= wdata[8*`VLEN-1:7*`VLEN];
                        end
                    end
                    default: wrong_addr <= 1;
                endcase
            end
            else begin
                wrong_addr <= addr_error;  // Capture address error during read
            end
        end
    end

endmodule
