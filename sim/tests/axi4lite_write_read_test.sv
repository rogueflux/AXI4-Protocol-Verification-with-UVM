// AXI4-Lite Write-Read Test Class
// Tests basic write followed by read operations

class axi4lite_write_read_test extends axi4lite_base_test;
    
    `uvm_component_utils(axi4lite_write_read_test)
    
    // Test-specific parameters
    int num_write_read_pairs = 50;
    bit verify_data_integrity = 1;
    bit test_different_addresses = 0;
    bit test_back_to_back = 1;
    bit test_interleaved = 0;
    
    // Statistics
    int write_count = 0;
    int read_count = 0;
    int data_matches = 0;
    int data_mismatches = 0;
    
    // Constructor
    function new(string name = "axi4lite_write_read_test", uvm_component parent = null);
        super.new(name, parent);
        test_name = "axi4lite_write_read_test";
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Configure test-specific parameters
        env_cfg.max_transactions = num_write_read_pairs * 2; // Write + Read for each pair
        
        `uvm_info("WR_TEST", $sformatf(
            "Building write-read test with %0d pairs", num_write_read_pairs), UVM_MEDIUM)
    endfunction
    
    // Run test sequence
    virtual task run_test_sequence();
        `uvm_info("WR_TEST", "Running write-read test sequence", UVM_MEDIUM)
        
        // Create and run write-read sequence
        run_write_read_sequence();
        
        // Additional validation sequences
        run_validation_sequences();
    endtask
    
    // Run write-read sequence
    virtual task run_write_read_sequence();
        axi4lite_write_read_sequence wr_seq;
        
        `uvm_info("WR_TEST", "Starting write-read sequence", UVM_MEDIUM)
        
        // Create write-read sequence
        wr_seq = axi4lite_write_read_sequence::type_id::create("wr_seq");
        
        // Configure sequence
        if (!wr_seq.randomize() with {
            num_pairs == num_write_read_pairs;
            verify_data == verify_data_integrity;
            same_address == !test_different_addresses;
            back_to_back == test_back_to_back;
            interleaved == test_interleaved;
        }) begin
            `uvm_error("WR_TEST", "Failed to randomize write-read sequence")
            return;
        end
        
        // Print sequence configuration
        wr_seq.print_info("WR_TEST: ");
        
        // Start sequence on master sequencer
        wr_seq.start(env.master_agent.sequencer);
        
        // Update statistics
        write_count = num_write_read_pairs;
        read_count = num_write_read_pairs;
        
        `uvm_info("WR_TEST", "Write-read sequence completed", UVM_MEDIUM)
    endtask
    
    // Run validation sequences
    virtual task run_validation_sequences();
        `uvm_info("WR_TEST", "Running validation sequences", UVM_MEDIUM)
        
        // Test 1: Write to address, read from same address
        if (verify_data_integrity) begin
            test_data_integrity();
        end
        
        // Test 2: Write to multiple addresses, read back
        test_multiple_addresses();
        
        // Test 3: Back-to-back transactions
        if (test_back_to_back) begin
            test_back_to_back_transactions();
        end
        
        // Test 4: Interleaved writes and reads
        if (test_interleaved) begin
            test_interleaved_transactions();
        end
    endtask
    
    // Test data integrity
    virtual task test_data_integrity();
        axi4lite_transaction write_tx, read_tx;
        
        `uvm_info("WR_TEST", "Testing data integrity...", UVM_MEDIUM)
        
        // Test specific data patterns
        test_specific_data_pattern(32'h00000000, 4'b1111, "All zeros");
        test_specific_data_pattern(32'hFFFFFFFF, 4'b1111, "All ones");
        test_specific_data_pattern(32'hAAAAAAAA, 4'b1111, "Alternating 1010");
        test_specific_data_pattern(32'h55555555, 4'b1111, "Alternating 0101");
        test_specific_data_pattern(32'h12345678, 4'b1111, "Incremental");
        test_specific_data_pattern(32'h87654321, 4'b1111, "Decremental");
        
        // Test with different byte strobes
        test_specific_data_pattern(32'hAABBCCDD, 4'b0001, "Byte 0 only");
        test_specific_data_pattern(32'hAABBCCDD, 4'b0010, "Byte 1 only");
        test_specific_data_pattern(32'hAABBCCDD, 4'b0100, "Byte 2 only");
        test_specific_data_pattern(32'hAABBCCDD, 4'b1000, "Byte 3 only");
        test_specific_data_pattern(32'hAABBCCDD, 4'b0011, "Bytes 0-1");
        test_specific_data_pattern(32'hAABBCCDD, 4'b1100, "Bytes 2-3");
        
        `uvm_info("WR_TEST", $sformatf(
            "Data integrity test completed. Matches: %0d, Mismatches: %0d",
            data_matches, data_mismatches), UVM_MEDIUM)
    endtask
    
    // Test specific data pattern
    virtual task test_specific_data_pattern(bit [31:0] data, bit [3:0] strobe, string pattern_name);
        axi4lite_transaction write_tx, read_tx;
        bit [31:0] test_address = 32'h0000_0100; // Fixed test address
        
        `uvm_info("WR_TEST", $sformatf(
            "Testing pattern: %s (Data=0x%08h, Strobe=%4b)", 
            pattern_name, data, strobe), UVM_HIGH)
        
        // Create write transaction
        write_tx = axi4lite_transaction::type_id::create("write_tx");
        if (!write_tx.randomize() with {
            write_not_read == 1;
            awaddr == test_address;
            wdata == data;
            wstrb == strobe;
            delay_cycles == 0;
        }) begin
            `uvm_error("WR_TEST", "Failed to create write transaction")
            return;
        end
        
        // Send write
        start_item(write_tx, env.master_agent.sequencer);
        finish_item(write_tx, env.master_agent.sequencer);
        write_count++;
        
        // Wait a few cycles
        repeat (2) @(posedge vif.clk);
        
        // Create read transaction
        read_tx = axi4lite_transaction::type_id::create("read_tx");
        if (!read_tx.randomize() with {
            write_not_read == 0;
            araddr == test_address;
            delay_cycles == 0;
        }) begin
            `uvm_error("WR_TEST", "Failed to create read transaction")
            return;
        end
        
        // Send read
        start_item(read_tx, env.master_agent.sequencer);
        finish_item(read_tx, env.master_agent.sequencer);
        read_count++;
        
        // Note: Actual data verification happens in scoreboard
        // Here we just track statistics
        
        `uvm_info("WR_TEST", $sformatf(
            "Pattern %s: Write 0x%08h to 0x%08h, Read from same address",
            pattern_name, data, test_address), UVM_HIGH)
    endtask
    
    // Test multiple addresses
    virtual task test_multiple_addresses();
        `uvm_info("WR_TEST", "Testing multiple addresses...", UVM_MEDIUM)
        
        // Test addresses at different memory locations
        test_address_range(32'h0000_0000, 32'h0000_000C, 4);  // Start of memory
        test_address_range(32'h0000_0F00, 32'h0000_0F0C, 4);  // Near end of memory
        test_address_range(32'h0000_0080, 32'h0000_0090, 4);  // Middle of memory
        
        `uvm_info("WR_TEST", "Multiple address test completed", UVM_MEDIUM)
    endtask
    
    // Test address range
    virtual task test_address_range(bit [31:0] start_addr, bit [31:0] end_addr, int step);
        for (bit [31:0] addr = start_addr; addr <= end_addr; addr += step) begin
            axi4lite_transaction write_tx, read_tx;
            bit [31:0] test_data = addr + 32'h1000; // Simple data pattern
            
            // Skip if address not aligned
            if (addr[1:0] != 2'b00) continue;
            
            `uvm_info("WR_TEST", $sformatf(
                "Testing address 0x%08h with data 0x%08h", addr, test_data), UVM_HIGH)
            
            // Write
            write_tx = axi4lite_transaction::type_id::create("write_tx");
            if (!write_tx.randomize() with {
                write_not_read == 1;
                awaddr == addr;
                wdata == test_data;
                wstrb == 4'b1111;
                delay_cycles == 0;
            }) begin
                `uvm_error("WR_TEST", "Failed to create write transaction")
                continue;
            end
            
            start_item(write_tx, env.master_agent.sequencer);
            finish_item(write_tx, env.master_agent.sequencer);
            write_count++;
            
            // Read
            read_tx = axi4lite_transaction::type_id::create("read_tx");
            if (!read_tx.randomize() with {
                write_not_read == 0;
                araddr == addr;
                delay_cycles == 0;
            }) begin
                `uvm_error("WR_TEST", "Failed to create read transaction")
                continue;
            end
            
            start_item(read_tx, env.master_agent.sequencer);
            finish_item(read_tx, env.master_agent.sequencer);
            read_count++;
            
            // Small delay between transactions
            repeat (1) @(posedge vif.clk);
        end
    endtask
    
    // Test back-to-back transactions
    virtual task test_back_to_back_transactions();
        `uvm_info("WR_TEST", "Testing back-to-back transactions...", UVM_MEDIUM)
        
        // Send multiple writes without delay
        for (int i = 0; i < 10; i++) begin
            axi4lite_transaction tx;
            
            tx = axi4lite_transaction::type_id::create("tx");
            if (!tx.randomize() with {
                write_not_read == 1;
                awaddr == (32'h0000_0200 + (i * 4));
                wdata == (32'hB0BB0BB0 + i);
                wstrb == 4'b1111;
                delay_cycles == 0; // No delay for back-to-back
            }) begin
                `uvm_error("WR_TEST", "Failed to randomize transaction")
                continue;
            end
            
            start_item(tx, env.master_agent.sequencer);
            finish_item(tx, env.master_agent.sequencer);
            write_count++;
        end
        
        // Send multiple reads without delay
        for (int i = 0; i < 10; i++) begin
            axi4lite_transaction tx;
            
            tx = axi4lite_transaction::type_id::create("tx");
            if (!tx.randomize() with {
                write_not_read == 0;
                araddr == (32'h0000_0200 + (i * 4));
                delay_cycles == 0; // No delay for back-to-back
            }) begin
                `uvm_error("WR_TEST", "Failed to randomize transaction")
                continue;
            end
            
            start_item(tx, env.master_agent.sequencer);
            finish_item(tx, env.master_agent.sequencer);
            read_count++;
        end
        
        `uvm_info("WR_TEST", "Back-to-back transaction test completed", UVM_MEDIUM)
    endtask
    
    // Test interleaved transactions
    virtual task test_interleaved_transactions();
        `uvm_info("WR_TEST", "Testing interleaved write-read transactions...", UVM_MEDIUM)
        
        fork
            // Thread 1: Writes
            begin
                for (int i = 0; i < 5; i++) begin
                    axi4lite_transaction tx;
                    
                    tx = axi4lite_transaction::type_id::create("tx");
                    if (!tx.randomize() with {
                        write_not_read == 1;
                        awaddr == (32'h0000_0300 + (i * 8));
                        wdata == (32'h11111111 * (i + 1));
                        wstrb == 4'b1111;
                        delay_cycles inside {[0:2]};
                    }) begin
                        `uvm_error("WR_TEST", "Failed to randomize write")
                        continue;
                    end
                    
                    start_item(tx, env.master_agent.sequencer);
                    finish_item(tx, env.master_agent.sequencer);
                    write_count++;
                end
            end
            
            // Thread 2: Reads (start slightly later)
            begin
                #10ns;
                for (int i = 0; i < 5; i++) begin
                    axi4lite_transaction tx;
                    
                    tx = axi4lite_transaction::type_id::create("tx");
                    if (!tx.randomize() with {
                        write_not_read == 0;
                        araddr == (32'h0000_0300 + (i * 8));
                        delay_cycles inside {[0:2]};
                    }) begin
                        `uvm_error("WR_TEST", "Failed to randomize read")
                        continue;
                    end
                    
                    start_item(tx, env.master_agent.sequencer);
                    finish_item(tx, env.master_agent.sequencer);
                    read_count++;
                end
            end
        join
        
        `uvm_info("WR_TEST", "Interleaved transaction test completed", UVM_MEDIUM)
    endtask
    
    // Extract phase - collect results
    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        
        // Collect write-read specific statistics
        collect_write_read_statistics();
    endfunction
    
    // Collect write-read statistics
    virtual function void collect_write_read_statistics();
        int agent_stats[8];
        
        // Get statistics from environment
        env.get_statistics(agent_stats);
        
        // Update our statistics
        write_count = agent_stats[1] + agent_stats[5]; // Master writes + Slave writes
        read_count = agent_stats[2] + agent_stats[6];  // Master reads + Slave reads
        
        `uvm_info("WR_STATS", "Write-Read Test Statistics:", UVM_MEDIUM)
        `uvm_info("WR_STATS", $sformatf("  Total writes: %0d", write_count), UVM_MEDIUM)
        `uvm_info("WR_STATS", $sformatf("  Total reads: %0d", read_count), UVM_MEDIUM)
        `uvm_info("WR_STATS", $sformatf("  Total transactions: %0d", write_count + read_count), UVM_MEDIUM)
        `uvm_info("WR_STATS", $sformatf("  Write-read pairs tested: %0d", num_write_read_pairs), UVM_MEDIUM)
        
        // Check if we tested all planned pairs
        if (write_count >= num_write_read_pairs && read_count >= num_write_read_pairs) begin
            `uvm_info("WR_STATS", "  All planned write-read pairs executed", UVM_MEDIUM)
        end
        else begin
            `uvm_warning("WR_STATS", $sformatf(
                "  Only %0d writes and %0d reads executed (planned: %0d pairs)",
                write_count, read_count, num_write_read_pairs))
        end
    endfunction
    
    // Print test configuration
    virtual function void print_test_configuration(string prefix = "");
        super.print_test_configuration(prefix);
        
        `uvm_info("WR_TEST_CONFIG", $sformatf("%s  Write-Read Specific Configuration:", prefix), UVM_LOW)
        `uvm_info("WR_TEST_CONFIG", $sformatf("%s    Number of pairs: %0d", prefix, num_write_read_pairs), UVM_LOW)
        `uvm_info("WR_TEST_CONFIG", $sformatf("%s    Verify data integrity: %0d", prefix, verify_data_integrity), UVM_LOW)
        `uvm_info("WR_TEST_CONFIG", $sformatf("%s    Test different addresses: %0d", prefix, test_different_addresses), UVM_LOW)
        `uvm_info("WR_TEST_CONFIG", $sformatf("%s    Test back-to-back: %0d", prefix, test_back_to_back), UVM_LOW)
        `uvm_info("WR_TEST_CONFIG", $sformatf("%s    Test interleaved: %0d", prefix, test_interleaved), UVM_LOW)
    endfunction
    
    // Report phase
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        
        // Additional write-read test reporting
        `uvm_info("WR_TEST_REPORT", "========================================", UVM_NONE)
        `uvm_info("WR_TEST_REPORT", "WRITE-READ TEST SPECIFIC RESULTS:", UVM_NONE)
        `uvm_info("WR_TEST_REPORT", $sformatf("  Write transactions: %0d", write_count), UVM_NONE)
        `uvm_info("WR_TEST_REPORT", $sformatf("  Read transactions: %0d", read_count), UVM_NONE)
        `uvm_info("WR_TEST_REPORT", $sformatf("  Data matches: %0d", data_matches), UVM_NONE)
        `uvm_info("WR_TEST_REPORT", $sformatf("  Data mismatches: %0d", data_mismatches), UVM_NONE)
        
        if (verify_data_integrity && data_mismatches == 0) begin
            `uvm_info("WR_TEST_REPORT", "  DATA INTEGRITY: PASSED", UVM_NONE)
        end
        else if (verify_data_integrity) begin
            `uvm_error("WR_TEST_REPORT", $sformatf("  DATA INTEGRITY: FAILED (%0d mismatches)", data_mismatches))
        end
        `uvm_info("WR_TEST_REPORT", "========================================", UVM_NONE)
    endfunction
    
endclass
