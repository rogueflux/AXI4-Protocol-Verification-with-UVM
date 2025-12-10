// AXI4-Lite UVM Agent

class axi4lite_agent extends uvm_agent;
    
    // Components
    axi4lite_sequencer sequencer;
    axi4lite_driver    driver;
    axi4lite_monitor   monitor;
    
    // Configuration
    axi4lite_config cfg;
    
    // Analysis port (from monitor)
    uvm_analysis_port #(axi4lite_transaction) analysis_port;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_agent)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        if (!uvm_config_db#(axi4lite_config)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("CFG_WARN", $sformatf("No configuration found for agent %s, creating default", get_name()))
            cfg = axi4lite_config::type_id::create("cfg");
            cfg.agent_name = get_name();
        end
        
        // Create monitor (always present)
        monitor = axi4lite_monitor::type_id::create("monitor", this);
        
        // Create active components if agent is active
        if (cfg.is_active) begin
            sequencer = axi4lite_sequencer::type_id::create("sequencer", this);
            driver = axi4lite_driver::type_id::create("driver", this);
        end
        
        // Store configuration in sub-components
        uvm_config_db#(axi4lite_config)::set(this, "monitor", "cfg", cfg);
        
        if (cfg.is_active) begin
            uvm_config_db#(axi4lite_config)::set(this, "sequencer", "cfg", cfg);
            uvm_config_db#(axi4lite_config)::set(this, "driver", "cfg", cfg);
        end
    endfunction
    
    // Connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect monitor analysis port to agent analysis port
        monitor.mon_ap.connect(analysis_port);
        
        // Connect driver to sequencer if agent is active
        if (cfg.is_active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
        
        // Pass virtual interface to components
        if (cfg.vif != null) begin
            uvm_config_db#(virtual axi4lite_if)::set(this, "monitor", "vif", cfg.vif);
            
            if (cfg.is_active) begin
                uvm_config_db#(virtual axi4lite_if)::set(this, "sequencer", "vif", cfg.vif);
                uvm_config_db#(virtual axi4lite_if)::set(this, "driver", "vif", cfg.vif);
            end
        end
        else begin
            `uvm_error("AGENT", $sformatf("Virtual interface not set for agent %s", get_name()))
        end
    endfunction
    
    // Start of simulation
    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        `uvm_info("AGENT", $sformatf("AXI4-Lite Agent '%s' started (Active: %0d)", 
            get_name(), cfg.is_active), UVM_MEDIUM)
    endfunction
    
    // Get configuration
    virtual function axi4lite_config get_config();
        return cfg;
    endfunction
    
    // Set configuration
    virtual function void set_config(axi4lite_config new_cfg);
        cfg = new_cfg;
    endfunction
    
    // Set virtual interface
    virtual function void set_virtual_interface(virtual axi4lite_if vif);
        cfg.vif = vif;
    endfunction
    
    // Get agent type
    virtual function string get_agent_type();
        return (cfg.is_active ? "ACTIVE" : "PASSIVE");
    endfunction
    
    // Reset agent
    virtual task reset();
        `uvm_info("AGENT", $sformatf("Resetting agent %s", get_name()), UVM_MEDIUM)
        
        if (cfg.is_active) begin
            driver.reset();
            // Could also reset sequencer if needed
        end
    endtask
    
    // Get statistics from components
    virtual function void get_statistics(ref int stats[4]);
        int driver_stats[4];
        int monitor_stats[4];
        
        // Get driver statistics if active
        if (cfg.is_active) begin
            driver.get_statistics(driver_stats);
        end
        else begin
            driver_stats = '{0, 0, 0, 0};
        end
        
        // Get monitor statistics
        monitor.get_statistics(monitor_stats);
        
        // Combine statistics
        for (int i = 0; i < 4; i++) begin
            stats[i] = driver_stats[i] + monitor_stats[i];
        end
    endfunction
    
    // Print agent statistics
    virtual function void print_statistics(string prefix = "");
        int stats[4];
        
        get_statistics(stats);
        
        `uvm_info("AGENT_STATS", $sformatf("%sAgent '%s' (%s) statistics:", 
            prefix, get_name(), get_agent_type()), UVM_LOW)
        `uvm_info("AGENT_STATS", $sformatf("%s  Total transactions: %0d", prefix, stats[0]), UVM_LOW)
        `uvm_info("AGENT_STATS", $sformatf("%s  Write transactions: %0d", prefix, stats[1]), UVM_LOW)
        `uvm_info("AGENT_STATS", $sformatf("%s  Read transactions: %0d", prefix, stats[2]), UVM_LOW)
        `uvm_info("AGENT_STATS", $sformatf("%s  Error transactions: %0d", prefix, stats[3]), UVM_LOW)
        `uvm_info("AGENT_STATS", $sformatf("%s  Error rate: %0.2f%%", 
            prefix, (stats[0] > 0) ? (100.0 * stats[3] / stats[0]) : 0.0), UVM_LOW)
    endfunction
    
    // End of elaboration
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        print_statistics();
    endfunction
    
endclass
