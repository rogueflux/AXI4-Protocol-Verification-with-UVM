// AXI4-Lite Interface with SystemVerilog Assertions

interface axi4lite_if(input logic clk, input logic aresetn);
    
    // Write Address Channel
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;
    
    // Write Data Channel
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    
    // Write Response Channel
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    
    // Read Address Channel
    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;
    
    // Read Data Channel
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;
    
    // Clocking block for driver
    clocking driver_cb @(posedge clk);
        default input #1step output #0;
        output awaddr, awvalid, araddr, arvalid, wdata, wstrb, wvalid, bready, rready;
        input awready, arready, wready, bresp, bvalid, rdata, rresp, rvalid;
    endclocking
    
    // Clocking block for monitor
    clocking monitor_cb @(posedge clk);
        default input #1step output #0;
        input awaddr, awvalid, awready, araddr, arvalid, arready, 
              wdata, wstrb, wvalid, wready, bresp, bvalid, bready,
              rdata, rresp, rvalid, rready;
    endclocking
    
    // Modports
    modport master (
        clocking driver_cb,
        input clk, aresetn
    );
    
    modport slave (
        clocking monitor_cb,
        input clk, aresetn
    );
    
    // ----------------------------
    // SYSTEMVERILOG ASSERTIONS (SVA)
    // ----------------------------
    
    // 1. Handshake stability properties
    
    // AW channel: VALID must remain stable until handshake
    property p_awvalid_stable;
        @(posedge clk) disable iff (!aresetn)
        (awvalid && !awready) |=> $stable(awaddr) && awvalid;
    endproperty
    ASSERT_AWVALID_STABLE: assert property (p_awvalid_stable)
        else $error("[SVA] AWVALID or AWADDR changed before AWREADY handshake");
    
    // W channel: VALID must remain stable until handshake
    property p_wvalid_stable;
        @(posedge clk) disable iff (!aresetn)
        (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb) && wvalid;
    endproperty
    ASSERT_WVALID_STABLE: assert property (p_wvalid_stable)
        else $error("[SVA] WVALID, WDATA or WSTRB changed before WREADY handshake");
    
    // AR channel: VALID must remain stable until handshake
    property p_arvalid_stable;
        @(posedge clk) disable iff (!aresetn)
        (arvalid && !arready) |=> $stable(araddr) && arvalid;
    endproperty
    ASSERT_ARVALID_STABLE: assert property (p_arvalid_stable)
        else $error("[SVA] ARVALID or ARADDR changed before ARREADY handshake");
    
    // 2. Address alignment properties
    property p_addr_alignment;
        @(posedge clk) disable iff (!aresetn)
        (awvalid) |-> (awaddr[1:0] == 2'b00);
    endproperty
    ASSERT_ADDR_ALIGNMENT: assert property (p_addr_alignment)
        else $error("[SVA] Unaligned address detected on AWADDR: %0h", awaddr);
    
    property p_raddr_alignment;
        @(posedge clk) disable iff (!aresetn)
        (arvalid) |-> (araddr[1:0] == 2'b00);
    endproperty
    ASSERT_RADDR_ALIGNMENT: assert property (p_raddr_alignment)
        else $error("[SVA] Unaligned address detected on ARADDR: %0h", araddr);
    
    // 3. Write strobe validity
    property p_wstrb_valid;
        @(posedge clk) disable iff (!aresetn)
        (wvalid) |-> (wstrb != 4'b0000);
    endproperty
    ASSERT_WSTRB_VALID: assert property (p_wstrb_valid)
        else $error("[SVA] Invalid write strobe: %4b", wstrb);
    
    // 4. Response ordering properties
    property p_write_response_order;
        @(posedge clk) disable iff (!aresetn)
        ((awvalid && awready) && (wvalid && wready)) |=> ##[1:10] (bvalid);
    endproperty
    ASSERT_WRITE_RESPONSE_ORDER: assert property (p_write_response_order)
        else $error("[SVA] Write response not generated after write data handshake");
    
    property p_read_response_order;
        @(posedge clk) disable iff (!aresetn)
        (arvalid && arready) |=> ##[1:10] (rvalid);
    endproperty
    ASSERT_READ_RESPONSE_ORDER: assert property (p_read_response_order)
        else $error("[SVA] Read response not generated after read address handshake");
    
    // 5. Response code validity
    property p_bresp_valid;
        @(posedge clk) disable iff (!aresetn)
        (bvalid) |-> (bresp inside {2'b00, 2'b10, 2'b11});
    endproperty
    ASSERT_BRESP_VALID: assert property (p_bresp_valid)
        else $error("[SVA] Invalid B response code: %2b", bresp);
    
    property p_rresp_valid;
        @(posedge clk) disable iff (!aresetn)
        (rvalid) |-> (rresp inside {2'b00, 2'b10, 2'b11});
    endproperty
    ASSERT_RRESP_VALID: assert property (p_rresp_valid)
        else $error("[SVA] Invalid R response code: %2b", rresp);
    
    // 6. Single transaction property (AXI4-Lite)
    property p_single_transaction;
        @(posedge clk) disable iff (!aresetn)
        (awvalid && awready) |=> !awvalid[*5];
    endproperty
    ASSERT_SINGLE_TRANSACTION: assert property (p_single_transaction)
        else $error("[SVA] Multiple write address transactions detected (AXI4-Lite supports single transfers only)");
    
    // Coverage properties (cover groups would be in separate coverage file)
    covergroup cg_axi4lite_handshakes @(posedge clk);
        cp_aw_handshake: coverpoint (awvalid && awready);
        cp_w_handshake: coverpoint (wvalid && wready);
        cp_ar_handshake: coverpoint (arvalid && arready);
        cp_b_handshake: coverpoint (bvalid && bready);
        cp_r_handshake: coverpoint (rvalid && rready);
        
        cross_aw_w: cross cp_aw_handshake, cp_w_handshake;
        cross_ar_r: cross cp_ar_handshake, cp_r_handshake;
    endgroup
    
    cg_axi4lite_handshakes handshake_cg = new();
    
    // Helper functions
    function bit is_write_handshake();
        return (awvalid && awready);
    endfunction
    
    function bit is_read_handshake();
        return (arvalid && arready);
    endfunction
    
    // Monitor task for logging
    task monitor_transactions();
        forever begin
            @(posedge clk);
            
            // Log write address handshake
            if (awvalid && awready) begin
                $display("[MONITOR] Write Address: AWADDR=%0h, AWVALID=1, AWREADY=1", awaddr);
            end
            
            // Log write data handshake
            if (wvalid && wready) begin
                $display("[MONITOR] Write Data: WDATA=%0h, WSTRB=%4b, WVALID=1, WREADY=1", wdata, wstrb);
            end
            
            // Log write response handshake
            if (bvalid && bready) begin
                $display("[MONITOR] Write Response: BRESP=%2b, BVALID=1, BREADY=1", bresp);
            end
            
            // Log read address handshake
            if (arvalid && arready) begin
                $display("[MONITOR] Read Address: ARADDR=%0h, ARVALID=1, ARREADY=1", araddr);
            end
            
            // Log read data handshake
            if (rvalid && rready) begin
                $display("[MONITOR] Read Data: RDATA=%0h, RRESP=%2b, RVALID=1, RREADY=1", rdata, rresp);
            end
        end
    endtask
    
endinterface
