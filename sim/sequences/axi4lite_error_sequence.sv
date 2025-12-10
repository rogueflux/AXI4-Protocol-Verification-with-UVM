// AXI4-Lite Error Sequence - Tests error scenarios

class axi4lite_error_sequence extends axi4lite_sequence;
    
    `uvm_object_utils(axi4lite_error_sequence)
    
    // Error types
    typedef enum {
        ERR_NONE,
        ERR_UNALIGNED_ADDRESS,
        ERR_INVALID_STROBE,
        ERR_OUT_OF_RANGE,
        ERR_SLAVE_ERROR,
        ERR_DECODE_ERROR,
        ERR_PROTOCOL_VIOLATION
    } error_type_e;
    
    // Error injection control
    rand error_type_e error_type;
    rand int error_frequency = 20; // Percentage of transactions with errors
    
    // Specific error parameters
    rand bit [1:0] force_unaligned;
    rand bit [3:0] force_invalid_strobe;
    rand bit [31:0] force_out_of_range_addr;
    
    // Statistics
    int error_injected_count = 0;
    int total_errors_injected = 0;
    
    // Constructor
    function new(string name = "axi4lite_error_sequence");
        super.new(name);
    endfunction
    
    // Body task
    virtual task body();
        `uvm_info("ERROR_SEQ", $sformatf(
            "Starting error sequence with %0d transactions, error frequency: %0d%%", 
            num_transactions, error_frequency), UVM_MEDIUM)
        
        for (int i = 0; i < num_transactions; i++) begin
            axi4lite_transaction tx;
            bit inject_error;
            error_type_e this_error_type;
            
            // Decide if we inject an error
            inject_error = ($urandom_range(0, 99) < error_frequency);
            
            if (inject_error) begin
                // Randomly select error type
                if (!std::randomize(this_error_type) with {
                    this_error_type dist {
                        ERR_UNALIGNED_ADDRESS := 20,
                        ERR_INVALID_STROBE := 20,
                        ERR_OUT_OF_RANGE := 20,
                        ERR_SLAVE_ERROR := 20,
                        ERR_DECODE_ERROR := 20
                    };
                }) begin
                    this_error_type = ERR_UNALIGNED_ADDRESS;
                end
                error_injected_count++;
            end
            else begin
                this_error_type = ERR_NONE;
            }
            
            // Create and randomize transaction with error injection
            tx = axi4lite_transaction::type_id::create("tx");
            
            if (!inject_error || this_error_type == ERR_NONE) begin
                // Normal transaction
                if (!tx.randomize()) begin
                    `uvm_error("ERROR_SEQ", "Failed to randomize normal transaction")
                    continue;
                end
            end
            else begin
                // Error injection based on type
                case (this_error_type)
                    ERR_UNALIGNED_ADDRESS: begin
                        if (!tx.randomize() with {
                            // Force unaligned address (lower 2 bits non-zero)
                            if (write_not_read) {
                                awaddr[1:0] != 2'b00;
                            }
                            else {
                                araddr[1:0] != 2'b00;
                            }
                        }) begin
                            `uvm_warning("ERROR_SEQ", "Could not force unaligned address")
                            if (!tx.randomize()) continue;
                        end
                        total_errors_injected++;
                    end
                    
                    ERR_INVALID_STROBE: begin
                        if (!tx.randomize() with {
                            write_not_read == 1; // Only for writes
                            wstrb == 4'b0000;    // Invalid strobe
                        }) begin
                            `uvm_warning("ERROR_SEQ", "Could not force invalid strobe")
                            if (!tx.randomize()) continue;
                        end
                        total_errors_injected++;
                    end
                    
                    ERR_OUT_OF_RANGE: begin
                        if (!tx.randomize() with {
                            // Force address outside 4KB range
                            if (write_not_read) {
                                awaddr[31:12] == 20'hFFFFF;
                            }
                            else {
                                araddr[31:12] == 20'hFFFFF;
                            }
                        }) begin
                            `uvm_warning("ERROR_SEQ", "Could not force out of range address")
                            if (!tx.randomize()) continue;
                        end
                        total_errors_injected++;
                    end
                    
                    ERR_SLAVE_ERROR: begin
                        // This would require DUT to return SLVERR
                        // We can't force response from sequence, but we can target
                        // addresses that should trigger slave error
                        if (!tx.randomize() with {
                            // Target a specific address that should cause slave error
                            if (write_not_read) {
                                awaddr == 32'h0000_2000;
                            }
                            else {
                                araddr == 32'h0000_2000;
                            }
                        }) begin
                            `uvm_warning("ERROR_SEQ", "Could not set slave error address")
                            if (!tx.randomize()) continue;
                        end
                        total_errors_injected++;
                    end
                    
                    ERR_DECODE_ERROR: begin
                        // Target non-existent address space
                        if (!tx.randomize() with {
                            if (write_not_read) {
                                awaddr[31:28] == 4'hF; // High address space
                            }
                            else {
                                araddr[31:28] == 4'hF;
                            }
                        }) begin
                            `uvm_warning("ERROR_SEQ", "Could not set decode error address")
                            if (!tx.randomize()) continue;
                        end
                        total_errors_injected++;
                    end
                    
                    default: begin
                        if (!tx.randomize()) continue;
                    end
                endcase
            end
            
            // Start and finish item
            start_item(tx);
            if (inject_error) begin
                `uvm_info("ERROR_SEQ", $sformatf(
                    "Sending ERROR transaction %0d: Type=%s, %s to address 0x%08h", 
                    i, this_error_type.name(), tx.get_transaction_type(),
                    tx.write_not_read ? tx.awaddr : tx.araddr), UVM_HIGH)
            end
            else begin
                `uvm_info("ERROR_SEQ", $sformatf(
                    "Sending NORMAL transaction %0d: %s to address 0x%08h", 
                    i, tx.get_transaction_type(),
                    tx.write_not_read ? tx.awaddr : tx.araddr), UVM_HIGH)
            end
            finish_item(tx);
        end
        
        `uvm_info("ERROR_SEQ", $sformatf(
            "Error sequence completed. Errors injected: %0d/%0d", 
            total_errors_injected, num_transactions), UVM_MEDIUM)
    endtask
    
    // Constraint for error frequency
    constraint error_frequency_constraint {
        error_frequency inside {[0:100]};
    }
    
    // Get error statistics
    virtual function void get_error_stats(ref int injected, ref int total);
        injected = error_injected_count;
        total = total_errors_injected;
    endfunction
    
    // Print sequence information
    virtual function void print_info(string prefix = "");
        super.print_info(prefix);
        `uvm_info("ERROR_SEQ_INFO", $sformatf("%s  Error frequency: %0d%%", 
            prefix, error_frequency), UVM_LOW)
        `uvm_info("ERROR_SEQ_INFO", $sformatf("%s  Default error type: %s", 
            prefix, error_type.name()), UVM_LOW)
        `uvm_info("ERROR_SEQ_INFO", $sformatf("%s  Errors injected so far: %0d", 
            prefix, error_injected_count), UVM_LOW)
    endfunction
    
endclass
