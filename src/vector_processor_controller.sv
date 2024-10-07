`include "../define/vec_de_csr_defs.svh"

`include "../define/vector_processor_defs.svh"

module vector_processor_controller (

    // scalar_processor -> vector_extension
    input logic [`XLEN-1:0]     vec_inst,

    // controller --> scaler_processor   //TODO
    output  logic               vec_pro_ready,      // tells that vector processor is ready to take the instruction


    // vec_control_signals -> vec_decode
    output  logic               vl_sel,             // selection for rs1_data or uimm
    output  logic               vtype_sel,          // selection for rs2_data or zimm
    output  logic               lumop_sel,          // selection lumop
    output  logic               rs1rd_de,           // selection for VLMAX or comparator
    output  logic               rs1_sel,            // selection for rs1_data

    // vec_control_signals -> vec_csr
    output  logic                csrwr_en,

  
    // Vec_control_signals -> vec_registerfile
    output  logic                vec_reg_wr_en,      // The enable signal to write in the vector register
    output  logic                mask_operation,     // This signal tell this instruction is going to perform mask register update
    output  logic                mask_wr_en,         // This the enable signal for updating the mask value
    output  logic   [1:0]        data_mux1_sel,      // This the selsction of the mux to select between vec_imm , scaler1 , and vec_data1
    output  logic                data_mux2_sel,      // This the selsction of the mux to select between scaler2 , and vec_data2

    // vec_control_signals -> vec_lsu
    output  logic                stride_sel,         // tells that  it is a unit stride or the indexed
    output  logic                ld_inst             // tells that it is load insruction or store one
);

v_opcode_e      vopcode;
v_func3_e       vfunc3;
logic [1:0]     mop;

assign vopcode  = v_opcode_e'(vec_inst[6:0]);

// vfunc3 for differentiate between arithematic and configuration instructions
assign vfunc3   = v_func3_e'(vec_inst[14:12]);

// vector load instruction
assign mop      = vec_inst[27:26];

assign rs1_addr = vec_inst[19:15];
assign rd_addr = vec_inst[11:7];

always_comb begin
    lumop_sel       = '0;
    rs1_sel         = '0;
    csrwr_en        = '0;
    vl_sel          = '0;
    vtype_sel       = '0;
    data_mux1_sel   = 2'b00;
    data_mux2_sel   = 1'b0;
    stride_sel      = 1'b0;
    ld_inst         = 1'b0;  
    case (vopcode)
    V_ARITH: begin
        case (vfunc3)
            CONF: 
            begin
                csrwr_en = 1;
                case(vec_inst[31])
                // VSETVLI
                    1'b0: begin
                        vl_sel    = '0;
                        vtype_sel =  1;     //zimm selection
                        if ((rs1_addr == '0) && (rd_addr == '0)) begin
                            rs1rd_de = '0;
                            rs1_sel  = 1;
                        end
                        else begin 
                            rs1rd_de = 1;
                            rs1_sel  = '0;
                        end
                    end
                    1'b1: begin
                        case (vec_inst[30])
                    // VSETIVLI
                        1'b1: begin
                            vl_sel    = 1;
                            vtype_sel = 1;
                            rs1rd_de  = 1;
                            rs1_sel   = 0;
                        end
                    // VSETIVL
                        1'b0: begin
                            vl_sel    = '0;
                            vtype_sel = '0;
                            if ((rs1_addr == '0) && (rd_addr == '0)) begin
                                rs1rd_de = 0;
                                rs1_sel  = 1;
                            end
                            else begin
                                rs1rd_de = 1;
                                rs1_sel  = 0;
                            end
                        end
                        default: begin
                            vl_sel    = 0;
                            vtype_sel = 0;
                            rs1rd_de  = 1;
                            rs1_sel   = 1;
                        end
                        endcase
                    end
                    default: begin
                        vl_sel    = 0;
                        vtype_sel = 0;
                        rs1rd_de  = 1;
                        rs1_sel   = 1;
                    end
                endcase
            end
            default: 
            begin
                csrwr_en  = '0;
                vl_sel    = '0;
                vtype_sel = '0;
                rs1rd_de  =  1;
                rs1_sel   =  1;
            end
        endcase
    end
    V_LOAD: begin
        rs1_sel         = 1;        // selection for base address
        vl_sel          = 0;
        rs1rd_de        = 1;
        vec_reg_wr_en   = 1;
        mask_operation  = 0;
        mask_wr_en      = 0;
        data_mux1_sel   = 2'b01;
        data_mux2_sel   = 1'b1;
        stride_sel      = 1'b1;
        ld_inst         = 1'b1;
        
        case (mop)
            2'b00: begin
                stride_sel      = 1;        // unit stride
                vtype_sel       = 1;        // 1 or 0 don't care
                lumop_sel       = 1; 
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b1;     // scaler2      
            end
            2'b01: begin
                
                vtype_sel       = 1;        // 1 or 0 don't care
                lumop_sel       = 1;        // 1 or 0 don't care    
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;     // vec_data_2 
            end
            2'b10: begin
                vtype_sel = '0;
                lumop_sel = '0;
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b1;     // scaler2
            end
            2'b11: begin
                
                vtype_sel       = 1;        // 1 or 0 don't care
                lumop_sel       = 1;        // 1 or 0 don't care
                data_mux1_sel   = 2'b01;    // scaler1
                data_mux2_sel   = 1'b0;     // vec_data_2
            end
            default: begin
                rs1_sel         = 1;
                vl_sel          = 1;
                rs1rd_de        = 1;
                vtype_sel       = 1;
                lumop_sel       = 0;
                vec_reg_wr_en   = 1;
                mask_operation  = 0;
                mask_wr_en      = 0;
                data_mux1_sel   = 2'b01;   
                data_mux2_sel   = 1'b1;
                stride_sel      = 1'b1;
                ld_inst         = 1'b1;
    
            end
        endcase
    end
    default: begin
        csrwr_en        = 0;
        vl_sel          = 0;
        vtype_sel       = 0;
        rs1rd_de        = 1;
        lumop_sel       = 0;
        rs1_sel         = 1;
        vec_reg_wr_en   = 1;
        mask_operation  = 0;
        mask_wr_en      = 0;
        data_mux1_sel   = 2'b00;   
        data_mux2_sel   = 1'b0;
        stride_sel      = 1'b0;
        ld_inst         = 1'b0;
    
    end
    endcase    
end

endmodule