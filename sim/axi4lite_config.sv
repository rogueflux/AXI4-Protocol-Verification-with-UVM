// AXI4-Lite Configuration Class

class axi4lite_config extends uvm_object;
    
    // Agent configuration
    bit is_active = 1;           // 1: ACTIVE, 0: PASSIVE
    int agent_id = 0;            // Agent identifier
    string agent_name = "";      // Agent name
    
    // Interface handle
    virtual axi4lite_if vif;
    
    // Verification components enable
    bit coverage_enable = 1;     // Enable coverage collection
    bit scoreboard_enable = 1;   // Enable scoreboard
    bit assertion_enable = 1;    // Enable assertions
    
    // Simulation control
    time timeout_ns = 100_000;   // 100us default timeout
    int max_transactions = 1000; // Maximum transactions per test
    bit stop_on_error = 1;       // Stop simulation on error
    
    // Protocol parameters
    int data_width = 32;         // Data bus width
    int addr_width = 32;         // Address bus width
    int memory_size_kb = 4;      // Memory size in KB
    
    // Verbosity control
    uvm_verbosity verbosity = UVM_MEDIUM;
    
    // Randomization seed
    int random_seed = 12345;
    
    // UVM field automation
    `uvm_object_utils_begin(axi4lite_config)
        `uvm_field_int(is_active, UVM_ALL_ON)
        `uvm_field_int(agent_id, UVM_ALL_ON)
        `uvm_field_string(agent_name, UVM_ALL_ON)
        `uvm_field_int(coverage_enable, UVM_ALL_ON)
        `uvm_field_int(scoreboard_enable, UVM_ALL_ON)
        `uvm_field_int(assertion_enable, UVM_ALL_ON)
        `uvm_field_int(timeout_ns, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(max_transactions, UVM_ALL_ON)
        `uvm_field_int(stop_on_error, UVM_ALL_ON)
        `uvm_field_int(data_width, UVM_ALL_ON)
        `uvm_field_int(addr_width, UVM_ALL_ON)
        `uvm_field_int(memory_size_kb, UVM_ALL_ON)
        `uvm_field_int(random_seed, UVM_ALL_ON)
    `uvm_object_utils_end
    
    // Constructor
    function new(string name = "axi4lite_config");
        super.new(name);
        if (name == "") begin
            agent_name = $sformatf("axi4lite_agent_%0d", agent_id);
        end
        else begin
            agent_name = name;
        end
    endfunction
    
    // Print configuration
    virtual function void print_config(string prefix = "");
        `uvm_info("CONFIG", $sformatf("%sConfiguration for %s:", prefix, agent_name), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Agent ID: %0d", prefix, agent_id), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Active: %0d", prefix, is_active), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Coverage enabled: %0d", prefix, coverage_enable), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Scoreboard enabled: %0d", prefix, scoreboard_enable), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Timeout: %0t ns", prefix, timeout_ns), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Max transactions: %0d", prefix, max_transactions), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Data width: %0d", prefix, data_width), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Address width: %0d", prefix, addr_width), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Memory size: %0d KB", prefix, memory_size_kb), UVM_LOW)
        `uvm_info("CONFIG", $sformatf("%s  Random seed: %0d", prefix, random_seed), UVM_LOW)
    endfunction
    
    // Validate configuration
    virtual function bit validate();
        bit valid = 1;
        
        // Check interface
        if (vif == null) begin
            `uvm_error("CONFIG", "Virtual interface not set")
            valid = 0;
        end
        
        // Check parameters
        if (data_width != 32) begin
            `uvm_warning("CONFIG", $sformatf("Data width is %0d, AXI4-Lite requires 32", data_width))
        end
        
        if (addr_width != 32) begin
            `uvm_warning("CONFIG", $sformatf("Address width is %0d, AXI4-Lite requires 32", addr_width))
        end
        
        if (memory_size_kb <= 0) begin
            `uvm_error("CONFIG", $sformatf("Invalid memory size: %0d KB", memory_size_kb))
            valid = 0;
        end
        
        if (timeout_ns <= 0) begin
            `uvm_error("CONFIG", $sformatf("Invalid timeout: %0t ns", timeout_ns))
            valid = 0;
        end
        
        if (max_transactions <= 0) begin
            `uvm_error("CONFIG", $sformatf("Invalid max transactions: %0d", max_transactions))
            valid = 0;
        end
        
        return valid;
    endfunction
    
    // Set random seed
    virtual function void set_random_seed(int seed);
        random_seed = seed;
        // Actually set the seed if randomization is about to happen
        // This would be called before randomization in tests
    endfunction
    
    // Get memory size in bytes
    virtual function int get_memory_size_bytes();
        return memory_size_kb * 1024;
    endfunction
    
    // Get memory size in words (32-bit)
    virtual function int get_memory_size_words();
        return get_memory_size_bytes() / 4;
    endfunction
    
    // Get base address (typically 0x0)
    virtual function bit [31:0] get_base_address();
        return 32'h0;
    endfunction
    
    // Get end address
    virtual function bit [31:0] get_end_address();
        return get_base_address() + get_memory_size_bytes() - 1;
    endfunction
    
    // Check if address is valid
    virtual function bit is_address_valid(bit [31:0] addr);
        return (addr >= get_base_address() && addr <= get_end_address());
    endfunction
    
    // Clone configuration
    virtual function axi4lite_config clone_config();
        axi4lite_config cfg;
        cfg = axi4lite_config::type_id::create(this.get_name());
        cfg.copy(this);
        return cfg;
    endfunction
    
    // Copy configuration
    virtual function void copy(axi4lite_config rhs);
        is_active = rhs.is_active;
        agent_id = rhs.agent_id;
        agent_name = rhs.agent_name;
        vif = rhs.vif;
        coverage_enable = rhs.coverage_enable;
        scoreboard_enable = rhs.scoreboard_enable;
        assertion_enable = rhs.assertion_enable;
        timeout_ns = rhs.timeout_ns;
        max_transactions = rhs.max_transactions;
        stop_on_error = rhs.stop_on_error;
        data_width = rhs.data_width;
        addr_width = rhs.addr_width;
        memory_size_kb = rhs.memory_size_kb;
        verbosity = rhs.verbosity;
        random_seed = rhs.random_seed;
    endfunction
    
endclass
