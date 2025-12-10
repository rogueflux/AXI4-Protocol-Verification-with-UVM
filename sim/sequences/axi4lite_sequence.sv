// AXI4-Lite Base Sequence

class axi4lite_sequence extends uvm_sequence #(axi4lite_transaction);
    
    `uvm_object_utils(axi4lite_sequence)
    
    // Control knobs
    rand int num_transactions = 10;
    rand int min_delay = 0;
    rand int max_delay = 5;
    rand bit randomize_address = 1;
    rand bit randomize_data = 1;
    rand bit randomize_strobe = 1;
    
    // Sequence statistics
    int sequence_id;
    static int sequence_counter = 0;
    
    // Response queue
    axi4lite_transaction response_q[$];
    
    // Constructor
    function new(string name = "axi4lite_sequence");
        super.new(name);
        sequence_id = sequence_counter++;
    endfunction
    
    // Body task
    virtual task body();
        `uvm_info("SEQ", $sformatf("Starting sequence %0d with %0d transactions", 
            sequence_id, num_transactions), UVM_MEDIUM)
        
        for (int i = 0; i < num_transactions; i++) begin
            axi4lite_transaction tx;
            
            // Create transaction
            tx = axi4lite_transaction::type_id::create("tx");
            
            // Randomize transaction with constraints
            if (!tx.randomize() with {
                delay_cycles inside {[min_delay:max_delay]};
                if (!randomize_address) {
                    awaddr == 32'h0;
                    araddr == 32'h0;
                }
                if (!randomize_data) {
                    wdata == 32'h0;
                }
                if (!randomize_strobe) {
                    wstrb == 4'b1111;
                }
            }) begin
                `uvm_error("SEQ", "Failed to randomize transaction")
                continue;
            end
            
            // Start and finish item
            start_item(tx);
            `uvm_info("SEQ", $sformatf("Sending transaction %0d: %s to address 0x%08h", 
                i, tx.get_transaction_type(), 
                tx.write_not_read ? tx.awaddr : tx.araddr), UVM_HIGH)
            finish_item(tx);
            
            // Get response (optional)
            // get_response(rsp);
            
            // Store response if needed
            // response_q.push_back(rsp);
        end
        
        `uvm_info("SEQ", $sformatf("Sequence %0d completed", sequence_id), UVM_MEDIUM)
    endtask
    
    // Pre-body callback
    virtual task pre_body();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this, $sformatf("Starting sequence %0s", get_name()));
        end
    endtask
    
    // Post-body callback
    virtual task post_body();
        if (starting_phase != null) begin
            starting_phase.drop_objection(this, $sformatf("Completed sequence %0s", get_name()));
        end
    endtask
    
    // Constraint to limit number of transactions
    constraint num_transactions_constraint {
        num_transactions inside {[1:100]};
    }
    
    // Constraint for delay range
    constraint delay_constraint {
        min_delay >= 0;
        max_delay <= 10;
        max_delay >= min_delay;
    }
    
    // Get sequence statistics
    virtual function void get_stats(ref int seq_id, ref int trans_count);
        seq_id = sequence_id;
        trans_count = num_transactions;
    endfunction
    
    // Print sequence information
    virtual function void print_info(string prefix = "");
        `uvm_info("SEQ_INFO", $sformatf("%sSequence %0d:", prefix, sequence_id), UVM_LOW)
        `uvm_info("SEQ_INFO", $sformatf("%s  Name: %s", prefix, get_name()), UVM_LOW)
        `uvm_info("SEQ_INFO", $sformatf("%s  Transactions: %0d", prefix, num_transactions), UVM_LOW)
        `uvm_info("SEQ_INFO", $sformatf("%s  Delay range: %0d-%0d cycles", 
            prefix, min_delay, max_delay), UVM_LOW)
        `uvm_info("SEQ_INFO", $sformatf("%s  Randomize address: %0d", prefix, randomize_address), UVM_LOW)
        `uvm_info("SEQ_INFO", $sformatf("%s  Randomize data: %0d", prefix, randomize_data), UVM_LOW)
        `uvm_info("SEQ_INFO", $sformatf("%s  Randomize strobe: %0d", prefix, randomize_strobe), UVM_LOW)
    endfunction
    
endclass
