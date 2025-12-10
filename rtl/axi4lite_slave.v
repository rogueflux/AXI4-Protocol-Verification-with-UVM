// AXI4-Lite Slave DUT Implementation
// Simple memory-mapped slave with 4KB address space

module axi4lite_slave (
    // Clock and Reset
    input wire aclk,
    input wire aresetn,
    
    // Write Address Channel
    input wire [31:0] awaddr,
    input wire awvalid,
    output reg awready,
    
    // Write Data Channel
    input wire [31:0] wdata,
    input wire [3:0] wstrb,
    input wire wvalid,
    output reg wready,
    
    // Write Response Channel
    output reg [1:0] bresp,
    output reg bvalid,
    input wire bready,
    
    // Read Address Channel
    input wire [31:0] araddr,
    input wire arvalid,
    output reg arready,
    
    // Read Data Channel
    output reg [31:0] rdata,
    output reg [1:0] rresp,
    output reg rvalid,
    input wire rready
);

    // Internal memory (4KB = 1024 x 32-bit words)
    reg [31:0] memory [0:1023];
    
    // Internal registers
    reg [31:0] write_addr;
    reg [31:0] read_addr;
    reg write_in_progress;
    reg read_in_progress;
    
    // Response codes
    localparam OKAY   = 2'b00;
    localparam SLVERR = 2'b10;
    localparam DECERR = 2'b11;
    
    // Address validation
    wire write_addr_valid = (awaddr < 32'h00001000); // Within 4KB range
    wire read_addr_valid = (araddr < 32'h00001000);  // Within 4KB range
    
    // State machine states
    typedef enum logic [1:0] {
        IDLE,
        WRITE_DATA,
        WRITE_RESP,
        READ_DATA
    } state_t;
    
    state_t state;
    
    // Main FSM
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // Reset state
            state <= IDLE;
            awready <= 1'b0;
            wready <= 1'b0;
            arready <= 1'b0;
            bvalid <= 1'b0;
            rvalid <= 1'b0;
            write_addr <= 32'h0;
            read_addr <= 32'h0;
            write_in_progress <= 1'b0;
            read_in_progress <= 1'b0;
            bresp <= OKAY;
            rresp <= OKAY;
            rdata <= 32'h0;
        end
        else begin
            // Default outputs
            awready <= 1'b0;
            wready <= 1'b0;
            arready <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Accept write address
                    if (awvalid && !write_in_progress) begin
                        awready <= 1'b1;
                        write_addr <= awaddr;
                        write_in_progress <= 1'b1;
                        state <= WRITE_DATA;
                    end
                    // Accept read address
                    else if (arvalid && !read_in_progress) begin
                        arready <= 1'b1;
                        read_addr <= araddr;
                        read_in_progress <= 1'b1;
                        state <= READ_DATA;
                    end
                end
                
                WRITE_DATA: begin
                    // Accept write data
                    if (wvalid) begin
                        wready <= 1'b1;
                        
                        // Write to memory if address is valid
                        if (write_addr_valid) begin
                            // Handle byte strobes
                            if (wstrb[0]) memory[write_addr[11:2]][7:0] <= wdata[7:0];
                            if (wstrb[1]) memory[write_addr[11:2]][15:8] <= wdata[15:8];
                            if (wstrb[2]) memory[write_addr[11:2]][23:16] <= wdata[23:16];
                            if (wstrb[3]) memory[write_addr[11:2]][31:24] <= wdata[31:24];
                            bresp <= OKAY;
                        end
                        else begin
                            bresp <= DECERR; // Decode error for invalid address
                        end
                        
                        write_in_progress <= 1'b0;
                        state <= WRITE_RESP;
                    end
                end
                
                WRITE_RESP: begin
                    // Send write response
                    bvalid <= 1'b1;
                    
                    if (bready) begin
                        bvalid <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                READ_DATA: begin
                    // Read from memory and send response
                    if (read_addr_valid) begin
                        rdata <= memory[read_addr[11:2]];
                        rresp <= OKAY;
                    end
                    else begin
                        rdata <= 32'hDEADBEEF; // Error pattern
                        rresp <= DECERR; // Decode error for invalid address
                    end
                    
                    rvalid <= 1'b1;
                    
                    if (rready) begin
                        rvalid <= 1'b0;
                        read_in_progress <= 1'b0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Memory initialization for simulation
    initial begin
        for (int i = 0; i < 1024; i = i + 1) begin
            memory[i] = 32'h0;
        end
        // Initialize some test values
        memory[0] = 32'h12345678;
        memory[1] = 32'h9ABCDEF0;
        memory[2] = 32'hFEDCBA98;
        memory[3] = 32'h76543210;
    end
    
endmodule
