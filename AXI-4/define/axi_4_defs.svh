`ifndef axi_4_defs
`define axi_4_defs

`define XLEN            32
`define DATA_BUS_WIDTH  512
`define MEM_DEPTH       4096

parameter BURST_MAX = 256;  // or 256 if max len = 255
parameter STROBE_WIDTH = (`DATA_BUS_WIDTH/8);

typedef enum logic [2:0]{  
    MASTER_IDLE,
    WAIT_ARREADY,
    WAIT_RVALID,
    WAIT_AWREADY_WREADY,
    WAIT_AWREADY,
    WAIT_WREADY,
    WAIT_WLAST,
    WAIT_BVALID
} axi_4_master_states_e;

typedef enum logic [3:0]{  
    SLAVE_IDLE,
    WAIT_ARVALID,
    DATA_FETCH,
    WAIT_RREADY,
    WAIT_AWVALID_WVALID,
    WAIT_AWVALID,
    WAIT_WVALID,
    DATA_STORE,
    WAIT_BREADY
} axi_4_slave_states_e;


// Parameters for burst type
parameter BURST_FIXED = 2'b00;
parameter BURST_INCR  = 2'b01;
parameter BURST_WRAP  = 2'b10;

// Parameters for the response 
parameter RESP_OKAY   = 2'b00;
parameter RESP_SLVERR = 2'b10;
parameter RESP_DECERR = 2'b11;

`endif
