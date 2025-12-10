// AXI4-Lite Write-Read Sequence - Tests write followed by read

class axi4lite_write_read_sequence extends axi4lite_sequence;
    
    `uvm_object_utils(axi4lite_write_read_sequence)
    
    // Write-read pair control
    rand int num_pairs = 5;
    rand bit verify_data = 1;           // Verify read returns written data
    rand bit same_address = 1;          // Read same address as write
    rand bit back_to_back = 0;          // No delay between write and read
    rand bit interleaved = 0;           // Interleave writes and reads
    
    // Address and data for verification
    bit [31:0] write_addresses[$];
    bit [31:0] write_data[$];
    bit [3:0]  write_strobes[$];
    
    // Constructor
    function new(string name = "axi4lite_write_read_sequence");
        super.new(name);
        num_transactions = num_pairs * 2; // Each pair has write + read
    endfunction
    
    // Body task
    virtual task body();
        `uvm_info("WRITE_READ_SEQ", $sformatf(
            "Starting write-read sequence with %0d pairs", num_pairs), UVM_MEDIUM)
        
        clear_verification_data();
        
        if (interleaved) begin
            // Interleaved mode: write0, read0, write1, read1, ...
            for (int i = 0; i < num_pairs; i++) begin
                axi4lite_transaction write_tx, read_tx;
                bit [31:0] addr, data;
                bit [3:0] strobe;
                
                // Create write transaction
                if (!create_write_transaction(write_tx, i)) continue;
                
                // Store for verification
                store_verification_data(write_tx);
                
                // Send write
                start_item(write_tx);
                `uvm_info("WRITE_READ_SEQ", $sformatf(
                    "Sending WRITE %0d: Addr=0x%08h, Data=0x%08h, Strobe=%4b",
                    i, write_tx.awaddr, write_tx.wdata, write_tx.wstrb), UVM_HIGH)
                finish_item(write_tx);
                
                // Get address for read
                addr = same_address ? write_tx.awaddr : 
                       get_read_address(write_tx.awaddr, i);
                
                // Create and send read
                if (!create_read_transaction(read_tx, addr, i)) continue;
                
                start_item(read_tx);
                `uvm_info("WRITE_READ_SEQ", $sformatf(
                    "Sending READ %0d: Addr=0x%08h%s",
                    i, read_tx.araddr, 
                    same_address ? " (same as write)" : ""), UVM_HIGH)
                finish_item(read_tx);
                
                if (!back_to_back) begin
                    // Add delay between pairs
                    repeat (write_tx.delay_cycles) @(posedge m_sequencer.vif.clk);
                end
            end
        end
        else begin
            // Sequential mode: all writes first, then all reads
            // Phase 1: All writes
            for (int i = 0; i < num_pairs; i++) begin
                axi4lite_transaction write_tx;
                
                if (!create_write_transaction(write_tx, i)) continue;
                
                // Store for verification
                store_verification_data(write_tx);
                
                start_item(write_tx);
                `uvm_info("WRITE_READ_SEQ", $sformatf(
                    "Sending WRITE %0d: Addr=0x%08h, Data=0x%08h, Strobe=%4b",
                    i, write_tx.awaddr, write_tx.wdata, write_tx.wstrb), UVM_HIGH)
                finish_item(write_tx);
                
                if (!back_to_back) begin
                    repeat (write_tx.delay_cycles) @(posedge m_sequencer.vif.clk);
                end
            end
            
            // Phase 2: All reads
            for (int i = 0; i < num_pairs; i++) begin
                axi4lite_transaction read_tx;
                bit [31:0] addr;
                
                // Get address for read
                addr = same_address ? write_addresses[i] : 
                       get_read_address(write_addresses[i], i);
                
                if (!create_read_transaction(read_tx, addr, i)) continue;
                
                start_item(read_tx);
                `uvm_info("WRITE_READ_SEQ", $sformatf(
                    "Sending READ %0d: Addr=0x%08h%s",
                    i, read_tx.araddr, 
                    same_address ? " (same as write)" : ""), UVM_HIGH)
                finish_item(read_tx);
                
                if (!back_to_back) begin
                    repeat (read_tx.delay_cycles) @(posedge m_sequencer.vif.clk);
                end
            end
        end
        
        `uvm_info("WRITE_READ_SEQ", "Write-read sequence completed", UVM_MEDIUM)
        
        // Print verification summary
        print_verification_summary();
    endtask
    
    // Create write transaction
    virtual function bit create_write_transaction(ref axi4lite_transaction tx, int index);
        tx = axi4lite_transaction::type_id::create($sformatf("write_tx_%0d", index));
        
        if (!tx.randomize() with {
            write_not_read == 1;
            // Use interesting data patterns
            wdata == (32'h12345678 + (index * 32'h11111111));
            // Ensure valid address
            awaddr inside {[32'h0000_0000:32'h0000_0FFC]};
            awaddr[1:0] == 2'b00;
            // Use different strobes
            wstrb dist {
                4'b0001 := 10,
                4'b0011 := 20,
                4'b1111 := 70
            };
            // Short delays for write-read pairs
            delay_cycles inside {[0:2]};
        }) begin
            `uvm_error("WRITE_READ_SEQ", $sformatf("Failed to randomize write transaction %0d", index))
            return 0;
        end
        
        return 1;
    endfunction
    
    // Create read transaction
    virtual function bit create_read_transaction(ref axi4lite_transaction tx, 
                                                 bit [31:0] addr, int index);
        tx = axi4lite_transaction::type_id::create($sformatf("read_tx_%0d", index));
        
        if (!tx.randomize() with {
            write_not_read == 0;
            araddr == addr;
            araddr[1:0] == 2'b00;
            delay_cycles inside {[0:2]};
        }) begin
            `uvm_error("WRITE_READ_SEQ", $sformatf("Failed to randomize read transaction %0d", index))
            return 0;
        end
        
        return 1;
    endfunction
    
    // Get read address (different from write if needed)
    virtual function bit [31:0] get_read_address(bit [31:0] write_addr, int index);
        if (same_address) begin
            return write_addr;
        end
        else begin
            // Return a different but valid address
            return (write_addr + 32'h4) & 32'h0000_0FFC;
        end
    endfunction
    
    // Store verification data
    virtual function void store_verification_data(axi4lite_transaction tx);
        write_addresses.push_back(tx.awaddr);
        write_data.push_back(tx.wdata);
        write_strobes.push_back(tx.wstrb);
    endfunction
    
    // Clear verification data
    virtual function void clear_verification_data();
        write_addresses.delete();
        write_data.delete();
        write_strobes.delete();
    endfunction
    
    // Print verification summary
    virtual function void print_verification_summary();
        `uvm_info("WRITE_READ_SUMMARY", "Write-Read Sequence Verification Data:", UVM_MEDIUM)
        for (int i = 0; i < write_addresses.size(); i++) begin
            `uvm_info("WRITE_READ_SUMMARY", $sformatf(
                "  Pair %0d: Write Addr=0x%08h, Data=0x%08h, Strobe=%4b",
                i, write_addresses[i], write_data[i], write_strobes[i]), UVM_MEDIUM)
        end
        `uvm_info("WRITE_READ_SUMMARY", $sformatf(
            "  Total pairs: %0d, Verify data: %0d, Same address: %0d",
            num_pairs, verify_data, same_address), UVM_MEDIUM)
    endfunction
    
    // Constraint for number of pairs
    constraint num_pairs_constraint {
        num_pairs inside {[1:50]};
    }
    
    // Print sequence information
    virtual function void print_info(string prefix = "");
        super.print_info(prefix);
        `uvm_info("WRITE_READ_SEQ_INFO", $sformatf("%s  Number of pairs: %0d", 
            prefix, num_pairs), UVM_LOW)
        `uvm_info("WRITE_READ_SEQ_INFO", $sformatf("%s  Verify data: %0d", 
            prefix, verify_data), UVM_LOW)
        `uvm_info("WRITE_READ_SEQ_INFO", $sformatf("%s  Same address: %0d", 
            prefix, same_address), UVM_LOW)
        `uvm_info("WRITE_READ_SEQ_INFO", $sformatf("%s  Back-to-back: %0d", 
            prefix, back_to_back), UVM_LOW)
        `uvm_info("WRITE_READ_SEQ_INFO", $sformatf("%s  Interleaved: %0d", 
            prefix, interleaved), UVM_LOW)
        `uvm_info("WRITE_READ_SEQ_INFO", $sformatf("%s  Stored verification pairs: %0d", 
            prefix, write_addresses.size()), UVM_LOW)
    endfunction
    
endclass
