// AXI4-Lite UVM Coverage Collector

class axi4lite_coverage extends uvm_subscriber #(axi4lite_transaction);
    
    // Virtual interface (optional, for protocol coverage)
    virtual axi4lite_if vif;
    
    // Configuration
    axi4lite_config cfg;
    
    // Coverage groups
    covergroup cg_axi4lite_transaction;
        
        // Transaction type
        cp_transaction_type: coverpoint item.write_not_read {
            bins write = {1'b1};
            bins read = {1'b0};
        }
        
        // Write strobe patterns
        cp_wstrb_pattern: coverpoint item.wstrb {
            bins byte_0_only = {4'b0001};
            bins byte_1_only = {4'b0010};
            bins byte_2_only = {4'b0100};
            bins byte_3_only = {4'b1000};
            bins bytes_0_1 = {4'b0011};
            bins bytes_1_2 = {4'b0110};
            bins bytes_2_3 = {4'b1100};
            bins all_bytes = {4'b1111};
            bins other = default;
        }
        
        // Address ranges (4KB memory)
        cp_address_range: coverpoint (item.write_not_read ? item.awaddr : item.araddr) {
            bins low_range = {[32'h0000_0000:32'h0000_0FFF]};
            illegal_bins out_of_range = {[32'h0000_1000:32'hFFFF_FFFF]};
        }
        
        // Address alignment (should always be aligned)
        cp_address_alignment: coverpoint (item.write_not_read ? item.awaddr[1:0] : item.araddr[1:0]) {
            bins aligned = {2'b00};
            illegal_bins unaligned = {[0:3]} diff {2'b00};
        }
        
        // Response codes
        cp_response_code: coverpoint (item.write_not_read ? item.bresp : item.rresp) {
            bins okay = {2'b00};
            bins slverr = {2'b10};
            bins decerr = {2'b11};
            illegal_bins invalid = default;
        }
        
        // Data patterns (interesting values)
        cp_data_pattern: coverpoint (item.write_not_read ? item.wdata : item.rdata) {
            bins all_zeros = {32'h0000_0000};
            bins all_ones = {32'hFFFF_FFFF};
            bins alternating = {32'hAAAA_AAAA, 32'h5555_5555};
            bins walking_ones = {32'h0000_0001, 32'h0000_0002, 32'h0000_0004, 32'h0000_0008,
                                32'h0000_0010, 32'h0000_0020, 32'h0000_0040, 32'h0000_0080,
                                32'h0000_0100, 32'h0000_0200, 32'h0000_0400, 32'h0000_0800,
                                32'h0000_1000, 32'h0000_2000, 32'h0000_4000, 32'h0000_8000,
                                32'h0001_0000, 32'h0002_0000, 32'h0004_0000, 32'h0008_0000,
                                32'h0010_0000, 32'h0020_0000, 32'h0040_0000, 32'h0080_0000,
                                32'h0100_0000, 32'h0200_0000, 32'h0400_0000, 32'h0800_0000,
                                32'h1000_0000, 32'h2000_0000, 32'h4000_0000, 32'h8000_0000};
            bins other = default;
        }
        
        // Delay between transactions
        cp_delay: coverpoint item.delay_cycles {
            bins zero_delay = {0};
            bins short_delay = {[1:3]};
            bins medium_delay = {[4:7]};
            bins long_delay = {[8:10]};
        }
        
        // Cross coverage
        cross_type_wstrb: cross cp_transaction_type, cp_wstrb_pattern {
            ignore_bins read_wstrb = binsof(cp_transaction_type.read) && binsof(cp_wstrb_pattern);
        }
        
        cross_type_response: cross cp_transaction_type, cp_response_code;
        
        cross_address_response: cross cp_address_range, cp_response_code;
        
    endgroup
    
    // Protocol coverage (separate from transaction coverage)
    covergroup cg_axi4lite_protocol @(posedge vif.clk iff vif.aresetn);
        
        // Handshake coverage
        cp_aw_handshake: coverpoint (vif.awvalid && vif.awready) {
            bins handshake = {1'b1};
        }
        
        cp_w_handshake: coverpoint (vif.wvalid && vif.wready) {
            bins handshake = {1'b1};
        }
        
        cp_b_handshake: coverpoint (vif.bvalid && vif.bready) {
            bins handshake = {1'b1};
        }
        
        cp_ar_handshake: coverpoint (vif.arvalid && vif.arready) {
            bins handshake = {1'b1};
        }
        
        cp_r_handshake: coverpoint (vif.rvalid && vif.rready) {
            bins handshake = {1'b1};
        }
        
        // Back-pressure coverage
        cp_aw_backpressure: coverpoint (vif.awvalid && !vif.awready) {
            bins backpressure = {1'b1};
        }
        
        cp_w_backpressure: coverpoint (vif.wvalid && !vif.wready) {
            bins backpressure = {1'b1};
        }
        
        // Cross coverage for protocol scenarios
        cross_write_flow: cross cp_aw_handshake, cp_w_handshake, cp_b_handshake;
        
        cross_read_flow: cross cp_ar_handshake, cp_r_handshake;
        
    endgroup
    
    // Statistics
    int transaction_count = 0;
    int coverage_hits = 0;
    real coverage_percentage = 0.0;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_coverage)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_axi4lite_transaction = new();
        cg_axi4lite_protocol = new();
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        if (!uvm_config_db#(axi4lite_config)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("CFG_WARN", "No configuration found for coverage collector")
        end
        
        // Get virtual interface for protocol coverage
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif)) begin
            `uvm_warning("VIF_WARN", "Virtual interface not found for protocol coverage")
        end
    endfunction
    
    // Write function (called when transaction is received)
    virtual function void write(axi4lite_transaction t);
        transaction_count++;
        
        // Sample transaction coverage
        cg_axi4lite_transaction.sample();
        
        // Update coverage statistics
        update_coverage();
        
        `uvm_info("COVERAGE", $sformatf("Coverage sampled for transaction %0d", 
            transaction_count), UVM_HIGH)
    endfunction
    
    // Update coverage statistics
    virtual function void update_coverage();
        int total_bins = cg_axi4lite_transaction.get_inst_coverage(coverage_hits, coverage_percentage);
        
        // Can also check protocol coverage
        int protocol_hits;
        real protocol_percentage;
        cg_axi4lite_protocol.get_inst_coverage(protocol_hits, protocol_percentage);
        
        // Log coverage progress periodically
        if (transaction_count % 100 == 0) begin
            `uvm_info("COVERAGE_PROGRESS", $sformatf(
                "Transaction coverage: %0.1f%% (%0d hits)\nProtocol coverage: %0.1f%%",
                coverage_percentage, coverage_hits, protocol_percentage), UVM_MEDIUM)
        end
    endfunction
    
    // Get coverage report
    virtual function void get_coverage_report(ref real transaction_cov, ref real protocol_cov);
        int hits;
        cg
