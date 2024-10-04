`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: FINAL YEAR PROGECT (Dept of EE, U.E.T Lahore)
// Engineer: Muhammad Bilal Matloob
// Create Date: 09/26/2024
// Design Name: Mask Unit
// Module Name: vector_mask_unit
// Project Name: RISC_V VPU (Vector Processing Unit) 
//////////////////////////////////////////////////////////////////////////////////


// Mask Unit Main Module

module vector_mask_unit(

    ////////////////////////////////////// INPUT SIGNALS ////////////////////////////////////////

    // output data from lanes to be store at the destination, if correspoding bit is unmasked
    input logic [4095:0] lanes_data_out,
    
    // currently present data at the destination
    input logic [4095:0] destination_data,
    
    // mask operations for updating v0 (mask register)
    input logic [2:0] mask_op,
    
    // either masking is enabled or not e.g. vm = v.instr[25] = (1 or 0)?
    input logic mask_en,
    
    // Signal to order whether to update mask register or not
    input logic mask_reg_en,
    
    // tail agnostic bit
    input logic vta,
    
    // mask agnostic bit
    input logic vma,
    
    // vector start index
    input logic [9:0] vstart,
    
    // number of elements in the (current) vector
    input logic [9:0] vl,
    
    // single element width [8, 16, 32, 64]
    input logic [6:0] sew,
    
    // Vector Mask Registers
    input logic [511:0] vs1,  // vs1.mask
    input logic [511:0] vs2,  // vs2.mask
    input logic [511:0] v0,
    
    ////////////////////////////////////// OUTPUT SIGNALS ///////////////////////////////////////
    
    // Mask Unit output
    output logic [4095:0] mask_unit_output,

    // Updated value of mask register
    output logic [511:0] mask_reg_updated 
);
    
    comb_for_vsew_08 UUT01(
        .lanes_data_out(lanes_data_out),
        .destination_data(destination_data),
        .mask_reg(mask_reg),        
        .prestart_check(prestart_check),  
        .body_check(body_check),      
        .tail_check(tail_check),      
        .vta(vta),                     
        .vma(vma),                     
        .mask_output_01(mask_output_01)

    );

    comb_for_vsew_16 UUT02(
        .lanes_data_out(lanes_data_out),
        .destination_data(destination_data),
        .mask_reg(mask_reg),        
        .prestart_check(prestart_check),  
        .body_check(body_check),      
        .tail_check(tail_check),      
        .vta(vta),                     
        .vma(vma),                     
        .mask_output_02(mask_output_02)

    );

    comb_for_vsew_32 UUT03(
        .lanes_data_out(lanes_data_out),
        .destination_data(destination_data),
        .mask_reg(mask_reg),        
        .prestart_check(prestart_check),  
        .body_check(body_check),      
        .tail_check(tail_check),      
        .vta(vta),                     
        .vma(vma),                     
        .mask_output_03(mask_output_03)

    );

    comb_for_vsew_64 UUT04(
        .lanes_data_out(lanes_data_out),
        .destination_data(destination_data),
        .mask_reg(mask_reg),        
        .prestart_check(prestart_check),  
        .body_check(body_check),      
        .tail_check(tail_check),      
        .vta(vta),                     
        .vma(vma),                     
        .mask_output_04(mask_output_04)

    );

    comb_mask_operations UUT05(
        .vs1(vs1),  // vs1.mask
        .vs2(vs2),  // vs2.mask
        .mask_op(mask_op),     // Operation selection
        .mask_reg_updated(mask_reg_updated)   // Result
    );

    sew_encoder UUT06(
        .sew(sew),
        .sew_sel(sew_sel)
    );

    mux4x1 UUT07(
        .mask_output_01(mask_output_01),
        .mask_output_02(mask_output_02),
        .mask_output_03(mask_output_03),
        .mask_output_04(mask_output_04),
    
        .sew_sel(sew_sel),
    
        .selected_output(selected_output)
    );

    mux_output UUT08(
        .selected_output(selected_output),       // Input 0
        .lanes_data_out(lanes_data_out),       // Input 1
        .mask_en(mask_en),     // Select line
        .mask_unit_output(mask_unit_output)       // Output
    );

    mux2x1 UUT09(
        .v0(v0),       // Input 0
        .mask_reg_updated(mask_reg_updated),       // Input 1
        .mask_reg_en(mask_reg_en),     // Select line
        .v0_updated(v0_updated)       // Output
    );

    check_generator UUT10(
        .vl(vl),
        .vstart(vstart),
        .v0_updated(v0_updated),
    
        .mask_reg(mask_reg),        // mask register value corresponding to each element
        .prestart_check(prestart_check),  // prestart(x) = (0 <= x < vstart) 
        .body_check(body_check),      // body(x) = (vstart <= x < vl)
        .tail_check(tail_check)       // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))

    );
    
endmodule


//////////////////////////////////////////////////////////////////////////////////

module comb_mask_operations (
    input logic [511:0] vs1,  // vs1.mask
    input logic [511:0] vs2,  // vs2.mask
    input logic [2:0] mask_op,     // Operation selection
    output logic [511:0] mask_reg_updated   // Result
);

    always_comb begin
        case (mask_op)
            3'b000: mask_reg_updated = vs2 & vs1;                     // vmand.mm
            3'b001: mask_reg_updated = ~(vs2 & vs1);                  // vmnand.mm
            3'b010: mask_reg_updated = vs2 & ~vs1;                    // vmandn.mm
            3'b011: mask_reg_updated = vs2 ^ vs1;                     // vmxor.mm
            3'b100: mask_reg_updated = vs2 | vs1;                     // vmor.mm
            3'b101: mask_reg_updated = ~(vs2 | vs1);                  // vmnor.mm
            3'b110: mask_reg_updated = vs2 | ~vs1;                    // vmorn.mm
            3'b111: mask_reg_updated = ~(vs2 ^ vs1);                  // vmxnor.mm
        endcase
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module sew_encoder (
    input logic [6:0] sew,
    output logic [1:0] sew_sel
);
    always_comb begin
        case (sew)
            7'b0001000: sew_sel = 2'b00;                    
            7'b0010000: sew_sel = 2'b01;                  
            7'b0100000: sew_sel = 2'b10;                    
            7'b1000000: sew_sel = 2'b11;                    
        endcase
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////

module comb_for_vsew_08 #(parameter SEW = 8, parameter VAR = 512) (
    input logic [4095:0] lanes_data_out,
    input logic [4095:0] destination_data,
    input logic [511:0] mask_reg,        // mask register value corresponding to each element
    input logic [511:0] prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic [511:0] body_check,      // body(x) = (vstart <= x < vl)
    input logic [511:0] tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,                     // tail_agnostic bit
    input logic vma,                     // mask_agnostic bit
    
    output logic [4095:0] mask_output_01
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin
            mux_logics_for_sew_08 #(.SEW(SEW)) MUX_UNIT(
                .lanes_data_out( lanes_data_out [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .destination_data( destination_data [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .mask_reg( mask_reg [i] ),        
                .prestart_check( prestart_check [i] ),  
                .body_check( body_check [i] ),      
                .tail_check( tail_check [i] ),      
                .vta(vta),            
                .vma(vma),            
                .mux_sew_08_out( mask_output_01 [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ) 
            );
        end
    endgenerate

endmodule

// mini block used for instantiation in 'comb_for_vsew_08'

module mux_logics_for_sew_08 #(parameter SEW = 8) (

    input logic [SEW-1:0] lanes_data_out,
    input logic [SEW-1:0] destination_data,
    input logic mask_reg,        // mask register bit corresponding to each element
    input logic prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic body_check,      // body(x) = (vstart <= x < vl)
    input logic tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,             // tail_agnostic bit
    input logic vma,             // mask_agnostic bit
    output logic [SEW-1:0] mux_sew_08_out 
);

    always_comb begin
        if (prestart_check == 1'b1) begin
            mux_sew_08_out = destination_data;
        end else if ((body_check == 1'b1) && (mask_reg == 1'b0)) begin
            mux_sew_08_out = lanes_data_out;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b0)) begin
            mux_sew_08_out = destination_data;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b1)) begin
            mux_sew_08_out = '1;  // All bits set to 1
        end else if ((tail_check == 1'b1) && (vta == 1'b0)) begin
            mux_sew_08_out = destination_data;
        end else if ((tail_check == 1'b1) && (vta == 1'b1)) begin 
            mux_sew_08_out = '1;  // All bits set to 1
        end else begin
            mux_sew_08_out = destination_data;  // Default case
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module comb_for_vsew_16 #(parameter SEW = 16, parameter VAR = 256) (
    input logic [4095:0] lanes_data_out,
    input logic [4095:0] destination_data,
    input logic [511:0] mask_reg,        // mask register value corresponding to each element
    input logic [511:0] prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic [511:0] body_check,      // body(x) = (vstart <= x < vl)
    input logic [511:0] tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,                     // tail_agnostic bit
    input logic vma,                     // mask_agnostic bit
    
    output logic [4095:0] mask_output_02
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin
            mux_logics_for_sew_16 MUX_UNIT(
                .lanes_data_out( lanes_data_out [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .destination_data( destination_data [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .mask_reg( mask_reg [i] ),        
                .prestart_check( prestart_check [i] ),  
                .body_check( body_check [i] ),      
                .tail_check( tail_check [i] ),      
                .vta(vta),            
                .vma(vma),            
                .mux_sew_16_out( mask_output_02 [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ) 
            );
        end
    endgenerate

endmodule

// mini block used for instantiation in 'comb_for_vsew_16'

module mux_logics_for_sew_16 #(parameter SEW = 16) (

    input logic [SEW-1:0] lanes_data_out,
    input logic [SEW-1:0] destination_data,
    input logic mask_reg,        // mask register bit corresponding to each element
    input logic prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic body_check,      // body(x) = (vstart <= x < vl)
    input logic tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,             // tail_agnostic bit
    input logic vma,             // mask_agnostic bit
    output logic [SEW-1:0] mux_sew_16_out 
);

    always_comb begin
        if (prestart_check == 1'b1) begin
            mux_sew_16_out = destination_data;
        end else if ((body_check == 1'b1) && (mask_reg == 1'b0)) begin
            mux_sew_16_out = lanes_data_out;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b0)) begin
            mux_sew_16_out = destination_data;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b1)) begin
            mux_sew_16_out = '1;  // All bits set to 1
        end else if ((tail_check == 1'b1) && (vta == 1'b0)) begin
            mux_sew_16_out = destination_data;
        end else if ((tail_check == 1'b1) && (vta == 1'b1)) begin 
            mux_sew_16_out = '1;  // All bits set to 1
        end else begin
            mux_sew_16_out = destination_data;  // Default case
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module comb_for_vsew_32 #(parameter SEW = 32, parameter VAR = 128) (
    input logic [4095:0] lanes_data_out,
    input logic [4095:0] destination_data,
    input logic [511:0] mask_reg,        // mask register value corresponding to each element
    input logic [511:0] prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic [511:0] body_check,      // body(x) = (vstart <= x < vl)
    input logic [511:0] tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,                     // tail_agnostic bit
    input logic vma,                     // mask_agnostic bit
    
    output logic [4095:0] mask_output_03
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin
            mux_logics_for_sew_32 MUX_UNIT(
                .lanes_data_out( lanes_data_out [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .destination_data( destination_data [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .mask_reg( mask_reg [i] ),        
                .prestart_check( prestart_check [i] ),  
                .body_check( body_check [i] ),      
                .tail_check( tail_check [i] ),      
                .vta(vta),            
                .vma(vma),            
                .mux_sew_32_out( mask_output_03 [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ) 
            );
        end
    endgenerate

endmodule

// mini block used for instantiation in 'comb_for_vsew_32'

module mux_logics_for_sew_32 #(parameter SEW = 32) (

    input logic [SEW-1:0] lanes_data_out,
    input logic [SEW-1:0] destination_data,
    input logic mask_reg,        // mask register bit corresponding to each element
    input logic prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic body_check,      // body(x) = (vstart <= x < vl)
    input logic tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,             // tail_agnostic bit
    input logic vma,             // mask_agnostic bit
    output logic [SEW-1:0] mux_sew_32_out 
);

    always_comb begin
        if (prestart_check == 1'b1) begin
            mux_sew_32_out = destination_data;
        end else if ((body_check == 1'b1) && (mask_reg == 1'b0)) begin
            mux_sew_32_out = lanes_data_out;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b0)) begin
            mux_sew_32_out = destination_data;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b1)) begin
            mux_sew_32_out = '1;  // All bits set to 1
        end else if ((tail_check == 1'b1) && (vta == 1'b0)) begin
            mux_sew_32_out = destination_data;
        end else if ((tail_check == 1'b1) && (vta == 1'b1)) begin 
            mux_sew_32_out = '1;  // All bits set to 1
        end else begin
            mux_sew_32_out = destination_data;  // Default case
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module comb_for_vsew_64 #(parameter SEW = 64, parameter VAR = 64) (
    input logic [4095:0] lanes_data_out,
    input logic [4095:0] destination_data,
    input logic [511:0] mask_reg,        // mask register value corresponding to each element
    input logic [511:0] prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic [511:0] body_check,      // body(x) = (vstart <= x < vl)
    input logic [511:0] tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,                     // tail_agnostic bit
    input logic vma,                     // mask_agnostic bit
    
    output logic [4095:0] mask_output_04
);

    generate
        genvar i;
        for (i = 0; i < VAR; i++) begin
            mux_logics_for_sew_64 MUX_UNIT(
                .lanes_data_out( lanes_data_out [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .destination_data( destination_data [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ),
                .mask_reg( mask_reg [i] ),        
                .prestart_check( prestart_check [i] ),  
                .body_check( body_check [i] ),      
                .tail_check( tail_check [i] ),      
                .vta(vta),            
                .vma(vma),            
                .mux_sew_64_out( mask_output_04 [ ( (SEW - 1) + (i * SEW) ) : (i * SEW) ] ) 
            );
        end
    endgenerate

endmodule

// mini block used for instantiation in 'comb_for_vsew_64'

module mux_logics_for_sew_64 #(parameter SEW = 64) (

    input logic [SEW-1:0] lanes_data_out,
    input logic [SEW-1:0] destination_data,
    input logic mask_reg,        // mask register bit corresponding to each element
    input logic prestart_check,  // prestart(x) = (0 <= x < vstart) 
    input logic body_check,      // body(x) = (vstart <= x < vl)
    input logic tail_check,      // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))
    input logic vta,             // tail_agnostic bit
    input logic vma,             // mask_agnostic bit
    output logic [SEW-1:0] mux_sew_64_out 
);

    always_comb begin
        if (prestart_check == 1'b1) begin
            mux_sew_64_out = destination_data;
        end else if ((body_check == 1'b1) && (mask_reg == 1'b0)) begin
            mux_sew_64_out = lanes_data_out;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b0)) begin
            mux_sew_64_out = destination_data;
        end else if (((body_check & mask_reg) == 1'b1) && (vma == 1'b1)) begin
            mux_sew_64_out = '1;  // All bits set to 1
        end else if ((tail_check == 1'b1) && (vta == 1'b0)) begin
            mux_sew_64_out = destination_data;
        end else if ((tail_check == 1'b1) && (vta == 1'b1)) begin 
            mux_sew_64_out = '1;  // All bits set to 1
        end else begin
            mux_sew_64_out = destination_data;  // Default case
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module mux2x1 (
    input logic [511:0] v0,       // Input 0
    input logic [511:0] mask_reg_updated,       // Input 1
    input logic mask_reg_en,     // Select line
    output logic [511:0] v0_updated       // Output
);

    // Behavioral description using an always block with if-else
    always_comb begin
        if (mask_reg_en == 1'b0) begin
            v0_updated = v0;  // If sel is 0, output is a
        end else begin
            v0_updated = mask_reg_updated;  // If sel is 1, output is b
        end
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module mux4x1 (
    input logic [4095:0] mask_output_01,
    input logic [4095:0] mask_output_02,
    input logic [4095:0] mask_output_03,
    input logic [4095:0] mask_output_04,
    
    input logic [1:0] sew_sel,
    
    output logic [4095:0] selected_output
);

    // Behavioral description using an always_comb block
    always_comb begin
        case (sew_sel)
            2'b00: selected_output = mask_output_01;  // Select input 1
            2'b01: selected_output = mask_output_02;  // Select input 2
            2'b10: selected_output = mask_output_03;  // Select input 3
            2'b11: selected_output = mask_output_04;  // Select input 4
        endcase
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module check_generator (
    input logic [9:0] vl,
    input logic [9:0] vstart,
    input logic [511:0] v0_updated,
    
    output logic [511:0] mask_reg,        // mask register value corresponding to each element
    output logic [511:0] prestart_check,  // prestart(x) = (0 <= x < vstart) 
    output logic [511:0] body_check,      // body(x) = (vstart <= x < vl)
    output logic [511:0] tail_check       // tail(x) = (vl <= x < max(VLMAX, VLEN/SEW))

);

    always_comb begin
        mask_reg = v0_updated << vstart;
        prestart_check = ~({512{1'b1}} << vstart);
        body_check = ({512{1'b1}} << vstart) & ({512{1'b1}} << (vstart + vl));
        tail_check = ({512{1'b1}} << (vstart + vl));
        
    end

endmodule

//////////////////////////////////////////////////////////////////////////////////

module mux_output (
    input logic [4095:0] selected_output,       // Input 0
    input logic [4095:0] lanes_data_out,       // Input 1
    input logic mask_en,     // Select line
    output logic [4095:0] mask_unit_output       // Output
);

    // Behavioral description using an always block with if-else
    always_comb begin
        if (mask_en == 1'b0) begin
            mask_unit_output = lanes_data_out;  // If sel is 0, output is a
        end else begin
            mask_unit_output = selected_output;  // If sel is 1, output is b
        end
    end

endmodule
