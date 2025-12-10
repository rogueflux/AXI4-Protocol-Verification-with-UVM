// AXI4-Lite UVM Monitor

class axi4lite_monitor extends uvm_monitor;
    
    // Virtual interface
    virtual axi4lite_if vif;
    
    // Configuration
    axi4lite_config cfg;
    
    // Analysis port for sending transactions
    uvm_analysis_port #(axi4lite_transaction) mon_ap;
    
    // Transaction queue
    axi4lite_transaction tx_queue[$];
    
    // Statistics
    int transaction_count = 0;
    int write_count = 0;
    int read_count = 0;
    int error_count = 0;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_monitor)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        if (!uvm_config_db#(axi4lite_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("CFG_FATAL", "Configuration not found for monitor")
        end
        
        // Get virtual interface
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("VIF_FATAL", "Virtual interface not found for monitor")
        end
    endfunction
    
    // Run phase
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        `uvm_info("MONITOR", "AXI4-Lite Monitor started", UVM_MEDIUM)
        
        // Wait for reset deassertion
        wait(vif.aresetn == 1'b1);
        
        // Start monitoring tasks
        fork
            monitor_write_address_channel();
            monitor_write_data_channel();
            monitor_write_response_channel();
            monitor_read_address_channel();
            monitor_read_data_channel();
            process_transactions();
        join
    endtask
    
    // Monitor Write Address Channel
    virtual task monitor_write_address_channel();
        axi4lite_transaction tx;
        
        forever begin
            // Wait for write address handshake
            @(posedge vif.clk iff (vif.awvalid && vif.awready));
            
            tx = axi4lite_transaction::type_id::create("write_tx");
            tx.write_not_read = 1'b1;
            tx.awaddr = vif.awaddr;
            tx.transaction_id = transaction_count;
            
            // Push to queue for later processing
            tx_queue.push_back(tx);
            
            `uvm_info("MONITOR", $sformatf("Captured WRITE address: 0x%08h", 
                tx.awaddr), UVM_HIGH)
        end
    endtask
    
    // Monitor Write Data Channel
    virtual task monitor_write_data_channel();
        forever begin
            // Wait for write data handshake
            @(posedge vif.clk iff (vif.wvalid && vif.wready));
            
            // Find matching transaction in queue
            foreach (tx_queue[i]) begin
                if (tx_queue[i].write_not_read && tx_queue[i].wdata == 32'h0) begin
                    tx_queue[i].wdata = vif.wdata;
                    tx_queue[i].wstrb = vif.wstrb;
                    `uvm_info("MONITOR", $sformatf("Captured WRITE data: 0x%08h, strobe: %4b", 
                        vif.wdata, vif.wstrb), UVM_HIGH)
                    break;
                end
            end
        end
    endtask
    
    // Monitor Write Response Channel
    virtual task monitor_write_response_channel();
        axi4lite_transaction tx;
        
        forever begin
            // Wait for write response handshake
            @(posedge vif.clk iff (vif.bvalid && vif.bready));
            
            // Find matching write transaction in queue
            foreach (tx_queue[i]) begin
                if (tx_queue[i].write_not_read && tx_queue[i].bresp == 2'b00) begin
                    tx = tx_queue[i];
                    tx.bresp = vif.bresp;
                    
                    // Update statistics
                    transaction_count++;
                    write_count++;
                    if (tx.bresp != 2'b00) error_count++;
                    
                    // Send to analysis port
                    mon_ap.write(tx);
                    
                    // Remove from queue
                    tx_queue.delete(i);
                    
                    `uvm_info("MONITOR", $sformatf("Captured WRITE response: %2b for address 0x%08h", 
                        tx.bresp, tx.awaddr), UVM_HIGH)
                    break;
                end
            end
        end
    endtask
    
    // Monitor Read Address Channel
    virtual task monitor_read_address_channel();
        axi4lite_transaction tx;
        
        forever begin
            // Wait for read address handshake
            @(posedge vif.clk iff (vif.arvalid && vif.arready));
            
            tx = axi4lite_transaction::type_id::create("read_tx");
            tx.write_not_read = 1'b0;
            tx.araddr = vif.araddr;
            tx.transaction_id = transaction_count;
            
            // Push to queue for later processing
            tx_queue.push_back(tx);
            
            `uvm_info("MONITOR", $sformatf("Captured READ address: 0x%08h", 
                tx.araddr), UVM_HIGH)
        end
    endtask
    
    // Monitor Read Data Channel
    virtual task monitor_read_data_channel();
        axi4lite_transaction tx;
        
        forever begin
            // Wait for read data handshake
            @(posedge vif.clk iff (vif.rvalid && vif.rready));
            
            // Find matching read transaction in queue
            foreach (tx_queue[i]) begin
                if (!tx_queue[i].write_not_read && tx_queue[i].rdata == 32'h0) begin
                    tx = tx_queue[i];
                    tx.rdata = vif.rdata;
                    tx.rresp = vif.rresp;
                    
                    // Update statistics
                    transaction_count++;
                    read_count++;
                    if (tx.rresp != 2'b00) error_count++;
                    
                    // Send to analysis port
                    mon_ap.write(tx);
                    
                    // Remove from queue
                    tx_queue.delete(i);
                    
                    `uvm_info("MONITOR", $sformatf("Captured READ data: 0x%08h, response: %2b for address 0x%08h", 
                        tx.rdata, tx.rresp, tx.araddr), UVM_HIGH)
                    break;
                end
            end
        end
    endtask
    
    // Process transactions in queue (cleanup)
    virtual task process_transactions();
        forever begin
            // Check for stale transactions (timeout)
            foreach (tx_queue[i]) begin
                // If transaction is too old, remove it
                // This is a simplified timeout check
                #1000ns; // 1us timeout
                if (tx_queue.size() > 0) begin
                    `uvm_warning("MONITOR", $sformatf("Removing stale transaction from queue"))
                    tx_queue.delete(i);
                end
            end
            #100ns;
        end
    endtask
    
    // Get statistics
    virtual function void get_statistics(ref int stats[4]);
        stats[0] = transaction_count;
        stats[1] = write_count;
        stats[2] = read_count;
        stats[3] = error_count;
    endfunction
    
    // Print statistics
    virtual function void print_statistics(string prefix = "");
        `uvm_info("MONITOR_STATS", $sformatf("%sMonitor '%s' statistics:", prefix, get_name()), UVM_LOW)
        `uvm_info("MONITOR_STATS", $sformatf("%s  Total transactions: %0d", prefix, transaction_count), UVM_LOW)
        `uvm_info("MONITOR_STATS", $sformatf("%s  Write transactions: %0d", prefix, write_count), UVM_LOW)
        `uvm_info("MONITOR_STATS", $sformatf("%s  Read transactions: %0d", prefix, read_count), UVM_LOW)
        `uvm_info("MONITOR_STATS", $sformatf("%s  Error transactions: %0d", prefix, error_count), UVM_LOW)
        `uvm_info("MONITOR_STATS", $sformatf("%s  Queued transactions: %0d", prefix, tx_queue.size()), UVM_LOW)
        `uvm_info("MONITOR_STATS", $sformatf("%s  Error rate: %0.2f%%", 
            prefix, (transaction_count > 0) ? (100.0 * error_count / transaction_count) : 0.0), UVM_LOW)
    endfunction
    
    // End of elaboration
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        print_statistics();
    endfunction
    
endclass
