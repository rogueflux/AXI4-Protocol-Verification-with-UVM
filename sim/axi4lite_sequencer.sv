// AXI4-Lite UVM Sequencer

class axi4lite_sequencer extends uvm_sequencer #(axi4lite_transaction);
    
    // Configuration
    axi4lite_config cfg;
    
    // Virtual interface
    virtual axi4lite_if vif;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_sequencer)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration from database
        if (!uvm_config_db#(axi4lite_config)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("CFG_WARN", "No configuration found for sequencer, creating default")
            cfg = axi4lite_config::type_id::create("cfg");
        end
        
        // Get virtual interface
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("VIF_FATAL", "Virtual interface not found in config database")
        end
    endfunction
    
    // Run phase
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info("SEQR", "AXI4-Lite Sequencer started", UVM_MEDIUM)
    endtask
    
    // Stop sequences
    function void stop_sequences();
        `uvm_info("SEQR", "Stopping all sequences", UVM_MEDIUM)
        stop_sequences();
    endfunction
    
    // Get configuration
    virtual function axi4lite_config get_config();
        return cfg;
    endfunction
    
    // Check if sequencer is idle
    virtual function bit is_idle();
        return (m_req_fifo.size() == 0 && m_wait_for_item_sequences.size() == 0);
    endfunction
    
    // Get number of pending requests
    virtual function int get_pending_requests();
        return m_req_fifo.size();
    endfunction
    
    // Print sequencer status
    virtual function void print_status(string prefix = "");
        `uvm_info("SEQR_STATUS", $sformatf("%sSequencer '%s' status:", prefix, get_name()), UVM_LOW)
        `uvm_info("SEQR_STATUS", $sformatf("%s  Pending requests: %0d", prefix, get_pending_requests()), UVM_LOW)
        `uvm_info("SEQR_STATUS", $sformatf("%s  Is idle: %0d", prefix, is_idle()), UVM_LOW)
        `uvm_info("SEQR_STATUS", $sformatf("%s  Configuration: %s", prefix, cfg.agent_name), UVM_LOW)
    endfunction
    
    // End of elaboration
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        print_status();
    endfunction
    
endclass
