// AXI4-Lite Random Sequence - Fully randomized transactions

class axi4lite_random_sequence extends axi4lite_sequence;
    
    `uvm_object_utils(axi4lite_random_sequence)
    
    // Additional random control
    rand bit include_errors = 0;
    rand int error_percentage = 10; // 10% chance of error injection
    
    // Address distribution weights
    rand bit uniform_address = 1;
    rand int low_addr_weight = 30;
    rand int mid_addr_weight = 40;
    rand int high_addr_weight = 30;
    
    // Constructor
    function new(string name = "axi4lite_random_sequence");
        super.new(name);
    endfunction
    
    // Body task
    virtual task body();
        `uvm_info("RAND_SEQ", $sformatf("Starting random sequence with %0d transactions", 
            num_transactions), UVM_MEDIUM)
        
        for (int i = 0; i < num_transactions; i++) begin
            axi4lite_transaction tx;
            bit inject_error;
            
            // Create transaction
            tx = axi4lite_transaction::type_id::create("tx");
            
            // Randomize error injection
            if (include_errors) begin
                inject_error = ($urandom_range(0, 99) < error_percentage);
            end
            else begin
                inject_error = 0;
            end
            
            // Randomize with special constraints
            if (!tx.randomize() with {
                // Force address distribution if not uniform
                if (!uniform_address) {
                    // Weighted address distribution
                    solve awaddr before write_not_read;
                    solve araddr before write_not_read;
                    
                    (awaddr[31:12] dist {
                        20'h00000 := low_addr_weight,
                        20'h00001 := mid_addr_weight,
                        [20'h00002:20'hFFFFF] := high_addr_weight
                    });
                    
                    (araddr[31:12] dist {
                        20'h00000 := low_addr_weight,
                        20'h00001 := mid_addr_weight,
                        [20'h00002:20'hFFFFF] := high_addr_weight
                    });
                }
                
                // Error injection for write transactions
                if (write_not_read && inject_error) {
                    // Force error response by accessing invalid address
                    awaddr[31:12] == 20'hFFFFF;
                    bresp != 2'b00;
                }
                
                // Error injection for read transactions
                if (!write_not_read && inject_error) {
                    // Force error response by accessing invalid address
                    araddr[31:12] == 20'hFFFFF;
                    rresp != 2'b00;
                }
                
                // Wide delay range for random sequence
                delay_cycles inside {[0:20]};
                
                // Random data patterns
                wdata dist {
                    32'h00000000 := 5,
                    32'hFFFFFFFF := 5,
                    32'hAAAAAAAA := 5,
                    32'h55555555 := 5,
                    [32'h00000001:32'hFFFFFFFE] := 80
                };
                
                // All possible strobe patterns
                wstrb inside {
                    4'b0001, 4'b0010, 4'b0100, 4'b1000,
                    4'b0011, 4'b0110, 4'b1100,
                    4'b0111, 4'b1110,
                    4'b1111
                };
            }) begin
                `uvm_error("RAND_SEQ", "Failed to randomize transaction")
                continue;
            end
            
            // Start and finish item
            start_item(tx);
            `uvm_info("RAND_SEQ", $sformatf("Sending random transaction %0d: %s to address 0x%08h%s", 
                i, tx.get_transaction_type(), 
                tx.write_not_read ? tx.awaddr : tx.araddr,
                inject_error ? " (ERROR INJECTED)" : ""), UVM_HIGH)
            finish_item(tx);
        end
        
        `uvm_info("RAND_SEQ", "Random sequence completed", UVM_MEDIUM)
    endtask
    
    // Constraint for error percentage
    constraint error_percentage_constraint {
        error_percentage inside {[0:50]}; // Max 50% errors
    }
    
    // Print sequence information
    virtual function void print_info(string prefix = "");
        super.print_info(prefix);
        `uvm_info("RAND_SEQ_INFO", $sformatf("%s  Include errors: %0d", prefix, include_errors), UVM_LOW)
        `uvm_info("RAND_SEQ_INFO", $sformatf("%s  Error percentage: %0d%%", prefix, error_percentage), UVM_LOW)
        `uvm_info("RAND_SEQ_INFO", $sformatf("%s  Uniform address: %0d", prefix, uniform_address), UVM_LOW)
        if (!uniform_address) begin
            `uvm_info("RAND_SEQ_INFO", $sformatf("%s  Address weights - Low:%0d, Mid:%0d, High:%0d", 
                prefix, low_addr_weight, mid_addr_weight, high_addr_weight), UVM_LOW)
        end
    endfunction
    
endclass
