// AXI4-Lite UVM Scoreboard

class axi4lite_scoreboard extends uvm_scoreboard;
    
    // Analysis imports for master and slave
    uvm_analysis_imp #(axi4lite_transaction, axi4lite_scoreboard) master_imp;
    uvm_analysis_imp #(axi4lite_transaction, axi4lite_scoreboard) slave_imp;
    
    // Transaction queues
    axi4lite_transaction master_q[$];
    axi4lite_transaction slave_q[$];
    
    // Expected memory model
    bit [31:0] expected_memory[1024];  // 4KB memory (1024 x 32-bit)
    
    // Statistics
    int match_count = 0;
    int mismatch_count = 0;
    int total_transactions = 0;
    int pending_transactions = 0;
    
    // Configuration
    axi4lite_config cfg;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_scoreboard)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
        master_imp = new("master_imp", this);
        slave_imp = new("slave_imp", this);
        
        // Initialize expected memory
        initialize_memory();
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        if (!uvm_config_db#(axi4lite_config)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("CFG_WARN", "No configuration found for scoreboard")
        end
    endfunction
    
    // Initialize expected memory
    virtual function void initialize_memory();
        for (int i = 0; i < 1024; i++) begin
            expected_memory[i] = 32'h0;
        end
        // Initialize with some test values
        expected_memory[0] = 32'h12345678;
        expected_memory[1] = 32'h9ABCDEF0;
        expected_memory[2] = 32'hFEDCBA98;
        expected_memory[3] = 32'h76543210;
        
        `uvm_info("SCOREBOARD", "Expected memory initialized", UVM_HIGH)
    endfunction
    
    // Write from master (expected transactions)
    virtual function void write(axi4lite_transaction tx);
        master_q.push_back(tx);
        pending_transactions++;
        total_transactions++;
        
        `uvm_info("SCOREBOARD", $sformatf("Received expected transaction from master: %s", 
            tx.get_transaction_type()), UVM_HIGH)
        
        // Try to compare if slave transaction is available
        compare_transactions();
    endfunction
    
    // Write from slave (actual transactions)
    virtual function void write_slave(axi4lite_transaction tx);
        slave_q.push_back(tx);
        
        `uvm_info("SCOREBOARD", $sformatf("Received actual transaction from slave: %s", 
            tx.get_transaction_type()), UVM_HIGH)
        
        // Try to compare if master transaction is available
        compare_transactions();
    endfunction
    
    // Compare transactions
    virtual function void compare_transactions();
        axi4lite_transaction master_tx, slave_tx;
        
        while (master_q.size() > 0 && slave_q.size() > 0) begin
            master_tx = master_q.pop_front();
            slave_tx = slave_q.pop_front();
            
            pending_transactions--;
            
            // Compare based on transaction type
            if (master_tx.write_not_read != slave_tx.write_not_read) begin
                `uvm_error("SCOREBOARD", $sformatf(
                    "Transaction type mismatch! Master: %s, Slave: %s",
                    master_tx.get_transaction_type(),
                    slave_tx.get_transaction_type()))
                mismatch_count++;
            end
            else if (master_tx.write_not_read) begin
                // Compare write transaction
                compare_write_transaction(master_tx, slave_tx);
            end
            else begin
                // Compare read transaction
                compare_read_transaction(master_tx, slave_tx);
            end
            
            // Log comparison result
            log_comparison_result(master_tx, slave_tx);
        end
    endfunction
    
    // Compare write transaction
    virtual function void compare_write_transaction(axi4lite_transaction master_tx,
                                                    axi4lite_transaction slave_tx);
        bit compare_result = 1;
        
        // Check address match
        if (master_tx.awaddr !== slave_tx.awaddr) begin
            `uvm_error("SCOREBOARD", $sformatf(
                "Write address mismatch! Expected: 0x%08h, Got: 0x%08h",
                master_tx.awaddr, slave_tx.awaddr))
            compare_result = 0;
        end
        
        // Check response
        if (master_tx.bresp !== slave_tx.bresp) begin
            `uvm_error("SCOREBOARD", $sformatf(
                "Write response mismatch! Expected: %2b, Got: %2b",
                master_tx.bresp, slave_tx.bresp))
            compare_result = 0;
        end
        
        // Update expected memory if write was successful
        if (slave_tx.bresp == 2'b00) begin
            int word_addr = master_tx.awaddr[11:2];
            
            // Apply byte strobes
            if (master_tx.wstrb[0]) expected_memory[word_addr][7:0] = master_tx.wdata[7:0];
            if (master_tx.wstrb[1]) expected_memory[word_addr][15:8] = master_tx.wdata[15:8];
            if (master_tx.wstrb[2]) expected_memory[word_addr][23:16] = master_tx.wdata[23:16];
            if (master_tx.wstrb[3]) expected_memory[word_addr][31:24] = master_tx.wdata[31:24];
            
            `uvm_info("SCOREBOARD", $sformatf(
                "Updated expected memory[%0d] = 0x%08h", 
                word_addr, expected_memory[word_addr]), UVM_HIGH)
        end
        
        if (compare_result) match_count++;
        else mismatch_count++;
    endfunction
    
    // Compare read transaction
    virtual function void compare_read_transaction(axi4lite_transaction master_tx,
                                                   axi4lite_transaction slave_tx);
        bit compare_result = 1;
        
        // Check address match
        if (master_tx.araddr !== slave_tx.araddr) begin
            `uvm_error("SCOREBOARD", $sformatf(
                "Read address mismatch! Expected: 0x%08h, Got: 0x%08h",
                master_tx.araddr, slave_tx.araddr))
            compare_result = 0;
        end
        
        // Check response
        if (master_tx.rresp !== slave_tx.rresp) begin
            `uvm_error("SCOREBOARD", $sformatf(
                "Read response mismatch! Expected: %2b, Got: %2b",
                master_tx.rresp, slave_tx.rresp))
            compare_result = 0;
        end
        
        // Check data if response is OKAY
        if (slave_tx.rresp == 2'b00) begin
            int word_addr = master_tx.araddr[11:2];
            bit [31:0] expected_data = expected_memory[word_addr];
            
            if (slave_tx.rdata !== expected_data) begin
                `uvm_error("SCOREBOARD", $sformatf(
                    "Read data mismatch! Addr: 0x%08h, Expected: 0x%08h, Got: 0x%08h",
                    master_tx.araddr, expected_data, slave_tx.rdata))
                compare_result = 0;
            end
        end
        
        if (compare_result) match_count++;
        else mismatch_count++;
    endfunction
    
    // Log comparison result
    virtual function void log_comparison_result(axi4lite_transaction master_tx,
                                                axi4lite_transaction slave_tx);
        if (master_tx.compare(slave_tx)) begin
            `uvm_info("SCOREBOARD_MATCH", $sformatf(
                "Transaction %0d matched: %s to address 0x%08h",
                master_tx.transaction_id,
                master_tx.get_transaction_type(),
                master_tx.write_not_read ? master_tx.awaddr : master_tx.araddr), UVM_HIGH)
        end
        else begin
            `uvm_error("SCOREBOARD_MISMATCH", $sformatf(
                "Transaction %0d MISMATCHED!", master_tx.transaction_id))
        end
    endfunction
    
    // Get memory value
    virtual function bit [31:0] get_memory_value(int word_addr);
        if (word_addr >= 0 && word_addr < 1024) begin
            return expected_memory[word_addr];
        end
        else begin
            `uvm_warning("SCOREBOARD", $sformatf("Invalid memory address: %0d", word_addr))
            return 32'hDEADBEEF;
        end
    endfunction
    
    // Set memory value
    virtual function void set_memory_value(int word_addr, bit [31:0] value);
        if (word_addr >= 0 && word_addr < 1024) begin
            expected_memory[word_addr] = value;
            `uvm_info("SCOREBOARD", $sformatf("Set memory[%0d] = 0x%08h", 
                word_addr, value), UVM_HIGH)
        end
        else begin
            `uvm_error("SCOREBOARD", $sformatf("Invalid memory address: %0d", word_addr))
        end
    endfunction
    
    // Get statistics
    virtual function void get_statistics(ref int stats[4]);
        stats[0] = total_transactions;
        stats[1] = match_count;
        stats[2] = mismatch_count;
        stats[3] = pending_transactions;
    endfunction
    
    // Print statistics
    virtual function void print_statistics(string prefix = "");
        real match_percentage;
        
        if (total_transactions > 0) begin
            match_percentage = 100.0 * match_count / total_transactions;
        end
        else begin
            match_percentage = 0.0;
        end
        
        `uvm_info("SCOREBOARD_STATS", $sformatf("%sScoreboard '%s' statistics:", 
            prefix, get_name()), UVM_LOW)
        `uvm_info("SCOREBOARD_STATS", $sformatf("%s  Total transactions: %0d", 
            prefix, total_transactions), UVM_LOW)
        `uvm_info("SCOREBOARD_STATS", $sformatf("%s  Matches: %0d", 
            prefix, match_count), UVM_LOW)
        `uvm_info("SCOREBOARD_STATS", $sformatf("%s  Mismatches: %0d", 
            prefix, mismatch_count), UVM_LOW)
        `uvm_info("SCOREBOARD_STATS", $sformatf("%s  Pending transactions: %0d", 
            prefix, pending_transactions), UVM_LOW)
        `uvm_info("SCOREBOARD_STATS", $sformatf("%s  Match rate: %0.2f%%", 
            prefix, match_percentage), UVM_LOW)
        
        // Check if scoreboard passed
        if (mismatch_count == 0) begin
            `uvm_info("SCOREBOARD_STATS", $sformatf("%s  SCOREBOARD PASSED!", prefix), UVM_HIGH)
        end
        else begin
            `uvm_error("SCOREBOARD_STATS", $sformatf("%s  SCOREBOARD FAILED! %0d mismatches", 
                prefix, mismatch_count))
        end
    endfunction
    
    // Reset scoreboard
    virtual function void reset();
        master_q.delete();
        slave_q.delete();
        initialize_memory();
        match_count = 0;
        mismatch_count = 0;
        total_transactions = 0;
        pending_transactions = 0;
        `uvm_info("SCOREBOARD", "Scoreboard reset", UVM_MEDIUM)
    endfunction
    
    // Check if scoreboard passed
    virtual function bit passed();
        return (mismatch_count == 0);
    endfunction
    
    // End of elaboration
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        print_statistics();
    endfunction
    
    // Extract phase - print final statistics
    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        print_statistics("FINAL ");
        
        // Report pass/fail
        if (passed()) begin
            `uvm_info("SCOREBOARD_FINAL", "SCOREBOARD VERIFICATION PASSED!", UVM_NONE)
        end
        else begin
            `uvm_error("SCOREBOARD_FINAL", "SCOREBOARD VERIFICATION FAILED!")
        end
    endfunction
    
endclass
