// Author       : Zawaher Bin Asim , UET Lahore  <zawaherbinasim.333@gmail.com>
// Date         : 11 Nov 2024
// Description  : This file contain the controller for the axi 4 that is used for the throughput/pushback control between the memory and vlsu  

`include "../define/axi_4_defs.svh"

module axi_4_controller (
    
    input   logic       clk,
    input   logic       reset,

    // vector_processor vlsu  --> axi_4_controller
    input   logic       ld_req,                     // signal for the load request
    input   logic       st_req,                     // signal for the store request
    

    //===================== axi_4 read address channel signals =========================//
 
    // slave(memory) --> axi_4_controller 
    input   logic       arready,                    // tells that slave(memory) is ready to take address for the read

    // axi_4_conntroller --> slave(memory) 
    output  logic       arvalid,                    // tells that address coming from master for the read is valid
    
    //===================== axi_4 read data channel signals =========================//
    
    // slave(memory) --> axi_4_controller
    input   logic       rvalid,                     // tells that loaded data and response coming from the slave(memory) is valid
    
    // axi_4_conntroller --> slave(memory)
    output  logic       rready,                     // tells that master(vlsu) is ready to take the valid loaded data response from the slave(memory)

    //===================== axi_4 write address channel signals =========================//
 
    // slave(memory) --> axi_4_controller 
    input   logic       awready,                    // tells that slave(memory) is ready to take address for the write

    // axi_4_conntroller --> slave(memory) 
    output  logic       awvalid,                    // tells that address coming from master for the write is valid

    //===================== axi_4 write data channel signals =========================//
 
    // slave(memory) --> axi_4_controller 
    input   logic       wready,                     // tells that slave(memory) is ready to take data for the write

    // axi_4_conntroller --> slave(memory) 
    output  logic       wvalid,                     // tells that data coming from master for the write is valid


    //===================== axi_4 write response channel signals =========================//
    
    // slave(memory) --> axi_4_controller
    input   logic       bvalid,                     // tells that response coming from the slave(memory) is valid
    
    // axi_4_conntroller --> slave(memory)
    output  logic       bready                      // tells that master(vlsu) is ready to take the valid response from the slave(memory)

);

axi_4_states_e  c_state,n_state;

always_ff @( posedge clk or negedge reset) begin 
    if (!reset)begin
        c_state <= IDLE;
    end
    else begin
        c_state <= n_state; 
    end
end


// Next State  Logic Block

always_comb begin

    n_state = c_state;

    case (c_state)
        IDLE: begin
            if (ld_req) begin
                if (arready)            n_state = WAIT_RVALID;
                else                    n_state = WAIT_ARREADY;
            end
            else if (st_req) begin
                if (awready && wready)  n_state = WAIT_BVALID;
                else if (awready)       n_state = WAIT_WREADY;
                else if (wready)        n_state = WAIT_AWREADY;
                else                    n_state = WAIT_AWREADY_WREADY;
            end
            else begin
                n_state = IDLE;
            end
        end


        WAIT_ARREADY  :   begin
            if (arready) n_state = WAIT_RVALID;
            else         n_state = WAIT_ARREADY;
        end

        WAIT_RVALID : begin
            if (rvalid) n_state = IDLE;
            else        n_state = WAIT_RVALID;
        end

        WAIT_AWREADY_WREADY : begin
            if      (!awready && !wready)   n_state = WAIT_AWREADY_WREADY;
            else if (!awready && wready )   n_state = WAIT_AWREADY;
            else if (awready && !wready )   n_state = WAIT_WREADY;
            else if (awready && wready  )   n_state = WAIT_BVALID;
        end

        WAIT_AWREADY : begin
            if (awready) n_state = WAIT_BVALID;
            else         n_state = WAIT_AWREADY; 
        end

        WAIT_WREADY : begin
            if (wready) n_state = WAIT_BVALID;
            else        n_state = WAIT_WREADY; 
        end

        WAIT_BVALID : begin
            if (bvalid) n_state = IDLE;
            else        n_state = WAIT_BVALID;
        end

        default: n_state = IDLE; 
    endcase    
end

// Next State Output Logic Block

always_comb begin 
    
    arvalid = 1'b0;
    rready  = 1'b0;
    awvalid = 1'b0;
    wvalid  = 1'b0;
    bready  = 1'b0;

    case (c_state)
        IDLE : begin
            if (!ld_req || !st_req) begin
                arvalid = 1'b0;
                rready  = 1'b0;
                awvalid = 1'b0;
                wvalid  = 1'b0;
                bready  = 1'b0;
            end     
            if (ld_req)begin
                arvalid = 1'b1;
                rready  = 1'b1;
            end
            else if (st_req)begin
                awvalid = 1'b1;
                wvalid  = 1'b1;
                bready  = 1'b1;
            end
        end

        WAIT_ARREADY  :   begin
           arvalid  = 1'b1;
           rready   = 1'b1;
        end

        WAIT_RVALID : begin
            rready  = 1'b1;
        end

        WAIT_AWREADY_WREADY : begin
            awvalid = 1'b1;
            wvalid  = 1'b1;
            bready  = 1'b1;
        end

        WAIT_AWREADY : begin
            awvalid = 1'b1;
            bready  = 1'b1; 
        end

        WAIT_WREADY : begin
            wvalid  = 1'b1;
            bready  = 1'b1;
        end

        WAIT_BVALID : begin
            bready  = 1'b1;
        end

        default: begin
            arvalid = 1'b0;
            rready  = 1'b0;
            awvalid = 1'b0;
            wvalid  = 1'b0;
            bready  = 1'b0;
        end
    endcase
    
end



endmodule

