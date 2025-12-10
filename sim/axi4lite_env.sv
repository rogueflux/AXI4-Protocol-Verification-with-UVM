// AXI4-Lite UVM Environment

class axi4lite_env extends uvm_env;
    
    // Agents
    axi4lite_agent master_agent;
    axi4lite_agent slave_agent;
    
    // Verification components
    axi4lite_scoreboard scoreboard;
    axi4lite_coverage   coverage;
    
    // Configurations
    axi4lite_config master_cfg;
    axi4lite_config slave_cfg;
    
    // Virtual interface
    virtual axi4lite_if vif;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_env)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        `uvm_info("ENV", "Building AXI4-Lite UVM Environment", UVM_MEDIUM)
        
        // Get virtual interface
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("VIF_FATAL", "Virtual interface not found in config database")
        end
        
        // Create configurations
        master_cfg = axi4lite_config::type_id::create("master_cfg");
        master_cfg.is_active = 1;  // Master is active (driver + sequencer)
        master_cfg.agent_id = 0;
        master_cfg.agent_name = "master_agent";
        master_cfg.vif = vif;
        
        slave_cfg = axi4lite_config::type_id::create("slave_cfg");
        slave_cfg.is_active = 0;   // Slave is passive (monitor only)
        slave_cfg.agent_id = 1;
        slave_cfg.agent_name = "slave_agent";
        slave_cfg.vif = vif;
        
        // Store configurations in database
        uvm_config_db#(axi4lite_config)::set(this, "master_agent", "cfg", master_cfg);
        uvm_config_db#(axi4lite_config)::set(this, "slave_agent", "cfg", slave_cfg);
        
        // Create agents
        master_agent = axi4lite_agent::type_id::create("master_agent", this);
        slave_agent = axi4lite_agent::type_id::create("slave_agent", this);
        
        // Create scoreboard if enabled
        if (master_cfg.scoreboard_enable) begin
            scoreboard = axi4lite_scoreboard::type_id::create("scoreboard", this);
        end
        
        // Create coverage collector if enabled
        if (master_cfg.coverage_enable) begin
            coverage = axi4lite_coverage::type_id::create("coverage", this);
        end
    endfunction
    
    // Connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        `uvm_info("ENV", "Connecting AXI4-Lite UVM Environment components", UVM_MEDIUM)
        
        // Connect master agent monitor to scoreboard
        if (master_cfg.scoreboard_enable) begin
            master_agent.analysis_port.connect(scoreboard.master_imp);
            `uvm_info("ENV", "Connected master agent to scoreboard", UVM_HIGH)
        end
        
        // Connect slave agent monitor to scoreboard
        if (slave_cfg.scoreboard_enable) begin
            slave_agent.analysis_port.connect(scoreboard.slave_imp);
            `uvm_info("ENV", "Connected slave agent to scoreboard", UVM_HIGH)
        end
        
        // Connect agents to coverage collector
        if (master_cfg.coverage_enable) begin
            master_agent.analysis_port.connect(coverage.analysis_export);
            slave_agent.analysis_port.connect(coverage.analysis_export);
            `uvm_info("ENV", "Connected agents to coverage collector", UVM_HIGH)
        end
        
        // Pass virtual interface to coverage
        if (master_cfg.coverage_enable && coverage != null) begin
            uvm_config_db#(virtual axi4lite_if)::set(this, "coverage", "vif", vif);
        end
    endfunction
    
    // Start of simulation
    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        
        `uvm_info("ENV", "AXI4-Lite UVM Environment started", UVM_MEDIUM)
        print_configuration();
    endfunction
    
    // Print environment configuration
    virtual function void print_configuration(string prefix = "");
        `uvm_info("ENV_CONFIG", $sformatf("%sEnvironment Configuration:", prefix), UVM_LOW)
        `uvm_info("ENV_CONFIG", $sformatf("%s  Master Agent: %s (%s)", 
            prefix, master_cfg.agent_name, master_cfg.is_active ? "ACTIVE" : "PASSIVE"), UVM_LOW)
        `uvm_info("ENV_CONFIG", $sformatf("%s  Slave Agent: %s (%s)", 
            prefix, slave_cfg.agent_name, slave_cfg.is_active ? "ACTIVE" : "PASSIVE"), UVM_LOW)
        `uvm_info("ENV_CONFIG", $sformatf("%s  Scoreboard enabled: %0d", 
            prefix, master_cfg.scoreboard_enable), UVM_LOW)
        `uvm_info("ENV_CONFIG", $sformatf("%s  Coverage enabled: %0d", 
            prefix, master_cfg.coverage_enable), UVM_LOW)
        `uvm_info("ENV_CONFIG", $sformatf("%s  Memory size: %0d KB", 
            prefix, master_cfg.memory_size_kb), UVM_LOW)
        `uvm_info("ENV_CONFIG", $sformatf("%s  Max transactions: %0d", 
            prefix, master_cfg.max_transactions), UVM_LOW)
    endfunction
    
    // Reset environment
    virtual task reset();
        `uvm_info("ENV", "Resetting environment", UVM_MEDIUM)
        
        // Reset agents
        master_agent.reset();
        slave_agent.reset();
        
        // Reset verification components
        if (scoreboard != null) begin
            scoreboard.reset();
        end
        
        if (coverage != null) begin
            coverage.reset_coverage();
        end
    endtask
    
    // Get environment statistics
    virtual function void get_statistics(ref int stats[8]);
        int master_stats[4];
        int slave_stats[4];
        
        // Get agent statistics
        master_agent.get_statistics(master_stats);
        slave_agent.get_statistics(slave_stats);
        
        // Combine statistics
        for (int i = 0; i < 4; i++) begin
            stats[i] = master_stats[i];
            stats[i+4] = slave_stats[i];
        end
    endfunction
    
    // Print environment statistics
    virtual function void print_statistics(string prefix = "");
        int stats[8];
        get_statistics(stats);
        
        `uvm_info("ENV_STATS", $sformatf("%sEnvironment Statistics:", prefix), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s  MASTER AGENT:", prefix), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Transactions: %0d", prefix, stats[0]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Writes: %0d", prefix, stats[1]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Reads: %0d", prefix, stats[2]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Errors: %0d", prefix, stats[3]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s  SLAVE AGENT:", prefix), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Transactions: %0d", prefix, stats[4]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Writes: %0d", prefix, stats[5]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Reads: %0d", prefix, stats[6]), UVM_LOW)
        `uvm_info("ENV_STATS", $sformatf("%s    Errors: %0d", prefix, stats[7]), UVM_LOW)
        
        // Print scoreboard statistics if enabled
        if (scoreboard != null) begin
            scoreboard.print_statistics(prefix);
        end
        
        // Print coverage statistics if enabled
        if (coverage != null) begin
            coverage.print_coverage_report(prefix);
        end
    endfunction
    
    // Check if environment verification passed
    virtual function bit verification_passed();
        bit passed = 1;
        
        // Check scoreboard
        if (scoreboard != null && !scoreboard.passed()) begin
            passed = 0;
        end
        
        // Check for UVM errors
        if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) > 0) begin
            passed = 0;
        end
        
        return passed;
    endfunction
    
    // End of elaboration
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        print_configuration();
    endfunction
    
    // Extract phase
    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        print_statistics("FINAL ");
        
        // Report overall verification result
        if (verification_passed()) begin
            `uvm_info("ENV_FINAL", "AXI4-LITE VERIFICATION PASSED!", UVM_NONE)
        end
        else begin
            `uvm_error("ENV_FINAL", "AXI4-LITE VERIFICATION FAILED!")
        end
    endfunction
    
endclass
