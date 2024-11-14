`ifndef axi_4_defs
`define axi_4_defs

typedef enum logic [2:0]{  
    IDLE,
    WAIT_ARREADY,
    WAIT_RVALID,
    WAIT_AWREADY_WREADY,
    WAIT_AWREADY,
    WAIT_WREADY,
    WAIT_BVALID
} axi_4_states_e;

`endif
