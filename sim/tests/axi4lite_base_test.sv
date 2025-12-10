// AXI4-Lite Base Test Class

class axi4lite_base_test extends uvm_test;
    
    `uvm_component_utils(axi4lite_base_test)
    
    // Testbench environment
    axi4lite_env env;
    
    // Virtual interface
    virtual axi4lite_if vif;
    
    // Test configuration
    axi4lite_config env_cfg;
    
    // Test control
    string test_name = "axi4lite_base_test";
    int seed = 12345;
    bit passed = 1;
    time simulation_timeout = 100_000; // 100us default
    
    // Statistics
    int start_time;
    int end_time;
    int simulation_cycles = 0;
    
    // Constructor
    function new(string name = "axi4lite_base_test", uvm_component parent = null);
        super.new(name, parent);
        if (name != "") test_name = name;
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        `uvm_info("TEST", $sformatf("Building test: %s", test_name), UVM_MEDIUM)
        
        // Get virtual interface from config database
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("TEST", "Virtual interface not found in config database")
        end
        
        // Create environment
        env = axi4lite_env::type_id::create("env", this);
        
        // Create and configure environment configuration
        env_cfg = axi4lite_config::type_id::create("env_cfg");
        env_cfg.agent_name = "axi4lite_env";
        env_cfg.vif = vif;
        env_cfg.random_seed = seed;
        env_cfg.timeout_ns = simulation_timeout;
        
        // Configure coverage and scoreboard
        env_cfg.coverage_enable = 1;
        env_cfg.scoreboard_enable = 1;
        env_cfg.assertion_enable = 1;
        
        // Set max transactions for this test
        env_cfg.max_transactions = 100;
        
        // Store configuration in database
        uvm_config_db#(axi4lite_config)::set(this, "env", "cfg", env_cfg);
        
        // Set random seed
        srandom(seed);
        `uvm_info("TEST", $sformatf("Random seed set to: %0d", seed), UVM_HIGH)
        
        // Print test configuration
        print_test_configuration();
    endfunction
    
    // Connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("TEST", $sformatf("Connecting test: %s", test_name), UVM_MEDIUM)
    endfunction
    
    // Start of simulation
    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        start_time = $time;
        `uvm_info("TEST", $sformatf("Starting simulation for test: %s", test_name), UVM_MEDIUM)
    endfunction
    
    // Run phase
    task run_phase(uvm_phase phase);
        `uvm_info("TEST", $sformatf("Running test: %s", test_name), UVM_MEDIUM)
        
        // Raise objection to keep test running
        phase.raise_objection(this, $sformatf("Running test %s", test_name));
        
        // Apply reset
        apply_reset();
        
        // Run main test sequence
        run_test_sequence();
        
        // Wait for completion
        wait_for_completion();
        
        // Drop objection
        phase.drop_objection(this, $sformatf("Completed test %s", test_name));
    endtask
    
    // Apply reset
    virtual task apply_reset();
        `uvm_info("TEST", "Applying reset...", UVM_MEDIUM)
        
        // Assert reset
        vif.aresetn <= 1'b0;
        
        // Wait for some cycles
        repeat (10) @(posedge vif.clk);
        
        // Deassert reset
        vif.aresetn <= 1'b1;
        
        // Wait for reset to propagate
        repeat (5) @(posedge vif.clk);
        
        `uvm_info("TEST", "Reset complete", UVM_MEDIUM)
    endtask
    
    // Run test sequence (to be overridden by derived tests)
    virtual task run_test_sequence();
        `uvm_info("TEST", "Running base test sequence", UVM_MEDIUM)
        
        // Default: run random sequence
        run_random_sequence();
    endtask
    
    // Run random sequence
    virtual task run_random_sequence();
        axi4lite_random_sequence rand_seq;
        
        `uvm_info("TEST", "Running random sequence", UVM_MEDIUM)
        
        // Create random sequence
        rand_seq = axi4lite_random_sequence::type_id::create("rand_seq");
        
        // Configure sequence
        if (!rand_seq.randomize() with {
            num_transactions == env_cfg.max_transactions;
            include_errors == 1;
            error_percentage == 10;
        }) begin
            `uvm_error("TEST", "Failed to randomize random sequence")
            return;
        end
        
        // Start sequence on master sequencer
        rand_seq.start(env.master_agent.sequencer);
        
        `uvm_info("TEST", "Random sequence completed", UVM_MEDIUM)
    endtask
    
    // Wait for completion
    virtual task wait_for_completion();
        `uvm_info("TEST", "Waiting for completion...", UVM_MEDIUM)
        
        // Wait for all transactions to complete
        // In a real test, we might wait for scoreboard to be empty
        // or wait for a timeout
        #(simulation_timeout * 1ns);
        
        // Monitor simulation cycles
        fork
            begin
                forever begin
                    @(posedge vif.clk);
                    simulation_cycles++;
                end
            end
        join_none
        
        `uvm_info("TEST", $sformatf("Completed waiting after %0t ns", $time), UVM_MEDIUM)
    endtask
    
    // Extract phase - collect results
    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        end_time = $time;
        
        `uvm_info("TEST", $sformatf("Extracting results for test: %s", test_name), UVM_MEDIUM)
        
        // Check verification results
        check_verification_results();
        
        // Print test summary
        print_test_summary();
    endfunction
    
    // Check verification results
    virtual function void check_verification_results();
        int error_count;
        
        // Check UVM error count
        error_count = uvm_report_server::get_server().get_severity_count(UVM_ERROR);
        
        // Check scoreboard if enabled
        if (env_cfg.scoreboard_enable && env.scoreboard != null) begin
            if (!env.scoreboard.passed()) begin
                error_count++;
                `uvm_error("TEST", "Scoreboard reported mismatches")
            end
        end
        
        // Check environment verification
        if (!env.verification_passed()) begin
            error_count++;
            `uvm_error("TEST", "Environment verification failed")
        end
        
        // Determine if test passed
        passed = (error_count == 0);
        
        if (passed) begin
            `uvm_info("TEST", "VERIFICATION PASSED!", UVM_NONE)
        end
        else begin
            `uvm_error("TEST", $sformatf("VERIFICATION FAILED with %0d errors", error_count))
        end
    endfunction
    
    // Print test configuration
    virtual function void print_test_configuration(string prefix = "");
        `uvm_info("TEST_CONFIG", $sformatf("%sTest Configuration:", prefix), UVM_LOW)
        `uvm_info("TEST_CONFIG", $sformatf("%s  Test Name: %s", prefix, test_name), UVM_LOW)
        `uvm_info("TEST_CONFIG", $sformatf("%s  Random Seed: %0d", prefix, seed), UVM_LOW)
        `uvm_info("TEST_CONFIG", $sformatf("%s  Timeout: %0t ns", prefix, simulation_timeout), UVM_LOW)
        `uvm_info("TEST_CONFIG", $sformatf("%s  Max Transactions: %0d", prefix, env_cfg.max_transactions), UVM_LOW)
        `uvm_info("TEST_CONFIG", $sformatf("%s  Coverage Enabled: %0d", prefix, env_cfg.coverage_enable), UVM_LOW)
        `uvm_info("TEST_CONFIG", $sformatf("%s  Scoreboard Enabled: %0d", prefix, env_cfg.scoreboard_enable), UVM_LOW)
    endfunction
    
    // Print test summary
    virtual function void print_test_summary(string prefix = "");
        real simulation_time_ns = (end_time - start_time);
        real clock_frequency_mhz = (simulation_cycles > 0) ? 
            (simulation_cycles / (simulation_time_ns / 1000.0)) : 0;
        
        `uvm_info("TEST_SUMMARY", $sformatf("%sTest Summary for %s:", prefix, test_name), UVM_LOW)
        `uvm_info("TEST_SUMMARY", $sformatf("%s  Start Time: %0t ns", prefix, start_time), UVM_LOW)
        `uvm_info("TEST_SUMMARY", $sformatf("%s  End Time: %0t ns", prefix, end_time), UVM_LOW)
        `uvm_info("TEST_SUMMARY", $sformatf("%s  Simulation Time: %0.2f ns", prefix, simulation_time_ns), UVM_LOW)
        `uvm_info("TEST_SUMMARY", $sformatf("%s  Simulation Cycles: %0d", prefix, simulation_cycles), UVM_LOW)
        `uvm_info("TEST_SUMMARY", $sformatf("%s  Effective Clock Frequency: %0.2f MHz", 
            prefix, clock_frequency_mhz), UVM_LOW)
        `uvm_info("TEST_SUMMARY", $sformatf("%s  Result: %s", 
            prefix, passed ? "PASSED" : "FAILED"), UVM_LOW)
        
        // Print environment statistics
        if (env != null) begin
            env.print_statistics(prefix + "  ");
        end
    endfunction
    
    // Get test result
    virtual function bit get_test_result();
        return passed;
    endfunction
    
    // Set random seed
    virtual function void set_random_seed(int new_seed);
        seed = new_seed;
        srandom(seed);
    endfunction
    
    // Set test name
    virtual function void set_test_name(string name);
        test_name = name;
    endfunction
    
    // Set simulation timeout
    virtual function void set_simulation_timeout(time timeout_ns);
        simulation_timeout = timeout_ns;
    endfunction
    
    // Report phase - final reporting
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        
        `uvm_info("TEST_REPORT", "========================================", UVM_NONE)
        if (passed) begin
            `uvm_info("TEST_REPORT", $sformatf("TEST %s: PASSED", test_name), UVM_NONE)
        end
        else begin
            `uvm_error("TEST_REPORT", $sformatf("TEST %s: FAILED", test_name))
        end
        `uvm_info("TEST_REPORT", "========================================", UVM_NONE)
    endfunction
    
endclass
