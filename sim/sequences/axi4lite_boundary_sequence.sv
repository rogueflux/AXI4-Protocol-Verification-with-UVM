// AXI4-Lite Boundary Sequence - Tests boundary conditions

class axi4lite_boundary_sequence extends axi4lite_sequence;
    
    `uvm_object_utils(axi4lite_boundary_sequence)
    
    // Boundary address list
    bit [31:0] boundary_addresses[$] = {
        32'h0000_0000,  // Start of memory
        32'h0000_0004,  // Second word
        32'h0000_0FFC,  // Last valid word (4KB - 4)
        32'h0000_0FF8,  // Second last word
        32'h0000_1000,  // Just outside memory (should error)
        32'hFFFF_FFFC   // Max 32-bit address (should error)
    };
    
    // Boundary data patterns
    bit [31:0] boundary_data[$] = {
        32'h0000_0000,  // All zeros
        32'hFFFF_FFFF,  // All ones
        32'hAAAA_AAAA,  // Alternating 1010
        32'h5555_5555,  // Alternating 0101
        32'h1234_5678,  // Incremental pattern
        32'h8765_4321   // Decremental pattern
    };
    
    // Boundary strobe patterns
    bit [3:0] boundary_strobes[$] = {
        4'b0001,  // Byte 0 only
        4'b0010,  // Byte 1 only
        4'b0100,  // Byte 2 only
        4'b1000,  // Byte 3 only
        4'b0011,  // Bytes 0-1
        4'b1100,  // Bytes 2-3
        4'b1111   // All bytes
    };
    
    // Control knobs
    rand bit test_valid_addresses = 1;
    rand bit test_invalid_addresses = 1;
    rand bit test_all_data_patterns = 0;
    rand bit test_all_strobe_patterns = 0;
    rand int transactions_per_address = 1;
    
    // Constructor
    function new(string name = "axi4lite_boundary_sequence");
        super.new(name);
        // Calculate number of transactions
        update_transaction_count();
    endfunction
    
    // Update transaction count based on settings
    function void update_transaction_count();
        int addr_count = 0;
        int data_count = 0;
        int strobe_count = 0;
        
        // Count addresses to test
        foreach (boundary_addresses[i]) begin
            if (test_valid_addresses && boundary_addresses[i] < 32'h0000_1000) begin
                addr_count++;
            end
            if (test_invalid_addresses && boundary_addresses[i] >= 32'h0000_1000) begin
                addr_count++;
            end
        end
        
        // Count data patterns
        if (test_all_data_patterns) begin
            data_count = boundary_data.size();
        end
        else begin
            data_count = 1;
        end
        
        // Count strobe patterns
        if (test_all_strobe_patterns) begin
            strobe_count = boundary_strobes.size();
        end
        else begin
            strobe_count = 1;
        end
        
        // Calculate total transactions
        num_transactions = addr_count * data_count * strobe_count * transactions_per_address * 2;
        // Multiply by 2 for both read and write
        
        `uvm_info("BOUNDARY_SEQ", $sformatf(
            "Calculated %0d boundary transactions (Addrs:%0d, Data:%0d, Strobes:%0d, PerAddr:%0d)", 
            num_transactions, addr_count, data_count, strobe_count, transactions_per_address), UVM_MEDIUM)
    endfunction
    
    // Body task
    virtual task body();
        `uvm_info("BOUNDARY_SEQ", "Starting boundary condition sequence", UVM_MEDIUM)
        
        // Test each boundary address
        foreach (boundary_addresses[addr_idx]) begin
            bit [31:0] addr = boundary_addresses[addr_idx];
            bit address_is_valid = (addr < 32'h0000_1000);
            
            // Skip addresses based on settings
            if ((address_is_valid && !test_valid_addresses) || 
                (!address_is_valid && !test_invalid_addresses)) begin
                continue;
            end
            
            // Test each data pattern
            for (int data_idx = 0; data_idx < (test_all_data_patterns ? boundary_data.size() : 1); data_idx++) begin
                bit [31:0] data = test_all_data_patterns ? boundary_data[data_idx] : 32'hB0UNDARY;
                
                // Test each strobe pattern
                for (int strobe_idx = 0; strobe_idx < (test_all_strobe_patterns ? boundary_strobes.size() : 1); strobe_idx++) begin
                    bit [3:0] strobe = test_all_strobe_patterns ? boundary_strobes[strobe_idx] : 4'b1111;
                    
                    // Run multiple transactions per combination
                    for (int trans_per_addr = 0; trans_per_addr < transactions_per_address; trans_per_addr++) begin
                        // Test both read and write
                        test_write_transaction(addr, data, strobe, address_is_valid);
                        test_read_transaction(addr, address_is_valid);
                    end
                end
            end
        end
        
        `uvm_info("BOUNDARY_SEQ", "Boundary sequence completed", UVM_MEDIUM)
    endtask
    
    // Test write transaction
    virtual task test_write_transaction(bit [31:0] addr, bit [31:0] data, 
                                        bit [3:0] strobe, bit address_is_valid);
        axi4lite_transaction tx;
        
        tx = axi4lite_transaction::type_id::create("tx");
        
        if (!tx.randomize() with {
            write_not_read == 1;
            awaddr == addr;
            wdata == data;
            wstrb == strobe;
            delay_cycles == 0; // No delay for boundary testing
        }) begin
            `uvm_error("BOUNDARY_SEQ", "Failed to randomize write transaction")
            return;
        end
        
        start_item(tx);
        `uvm_info("BOUNDARY_SEQ", $sformatf(
            "Testing WRITE boundary: Addr=0x%08h, Data=0x%08h, Strobe=%4b, Valid=%0d",
            addr, data, strobe, address_is_valid), UVM_HIGH)
        finish_item(tx);
    endtask
    
    // Test read transaction
    virtual task test_read_transaction(bit [31:0] addr, bit address_is_valid);
        axi4lite_transaction tx;
        
        tx = axi4lite_transaction::type_id::create("tx");
        
        if (!tx.randomize() with {
            write_not_read == 0;
            araddr == addr;
            delay_cycles == 0; // No delay for boundary testing
        }) begin
            `uvm_error("BOUNDARY_SEQ", "Failed to randomize read transaction")
            return;
        end
        
        start_item(tx);
        `uvm_info("BOUNDARY_SEQ", $sformatf(
            "Testing READ boundary: Addr=0x%08h, Valid=%0d",
            addr, address_is_valid), UVM_HIGH)
        finish_item(tx);
    endtask
    
    // Constraint for transactions per address
    constraint transactions_per_address_constraint {
        transactions_per_address inside {[1:5]};
    }
    
    // Print sequence information
    virtual function void print_info(string prefix = "");
        super.print_info(prefix);
        `uvm_info("BOUNDARY_SEQ_INFO", $sformatf("%s  Test valid addresses: %0d", 
            prefix, test_valid_addresses), UVM_LOW)
        `uvm_info("BOUNDARY_SEQ_INFO", $sformatf("%s  Test invalid addresses: %0d", 
            prefix, test_invalid_addresses), UVM_LOW)
        `uvm_info("BOUNDARY_SEQ_INFO", $sformatf("%s  Test all data patterns: %0d", 
            prefix, test_all_data_patterns), UVM_LOW)
        `uvm_info("BOUNDARY_SEQ_INFO", $sformatf("%s  Test all strobe patterns: %0d", 
            prefix, test_all_strobe_patterns), UVM_LOW)
        `uvm_info("BOUNDARY_SEQ_INFO", $sformatf("%s  Transactions per address: %0d", 
            prefix, transactions_per_address), UVM_LOW)
        `uvm_info("BOUNDARY_SEQ_INFO", $sformatf("%s  Number of boundary addresses: %0d", 
            prefix, boundary_addresses.size()), UVM_LOW)
    endfunction
    
endclass
