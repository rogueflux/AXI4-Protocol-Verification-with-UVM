// AXI4-Lite UVM Driver

class axi4lite_driver extends uvm_driver #(axi4lite_transaction);
    
    // Virtual interface
    virtual axi4lite_if vif;
    
    // Configuration
    axi4lite_config cfg;
    
    // Transaction queue for pipelining
    axi4lite_transaction tx_queue[$];
    
    // Statistics
    int transaction_count = 0;
    int write_count = 0;
    int read_count = 0;
    int error_count = 0;
    
    // UVM component utilities
    `uvm_component_utils(axi4lite_driver)
    
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    // Build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        if (!uvm_config_db#(axi4lite_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("CFG_FATAL", "Configuration not found for driver")
        end
        
        // Get virtual interface
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("VIF_FATAL", "Virtual interface not found for driver")
        end
    endfunction
    
    // Run phase
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        `uvm_info("DRIVER", "AXI4-Lite Driver started", UVM_MEDIUM)
        
        // Initialize interface
        initialize_if();
        
        // Main driver loop
        forever begin
            seq_item_port.get_next_item(req);
            tx_queue.push_back(req);
            seq_item_port.item_done();
            
            // Process transactions from queue
            while (tx_queue.size() > 0) begin
                axi4lite_transaction tx = tx_queue.pop_front();
                drive_transaction(tx);
            end
        end
    endtask
    
    // Initialize interface signals
    virtual task initialize_if();
        vif.driver_cb.awaddr <= '0;
        vif.driver_cb.awvalid <= 1'b0;
        vif.driver_cb.wdata <= '0;
        vif.driver_cb.wstrb <= 4'b0000;
        vif.driver_cb.wvalid <= 1'b0;
        vif.driver_cb.bready <= 1'b0;
        vif.driver_cb.araddr <= '0;
        vif.driver_cb.arvalid <= 1'b0;
        vif.driver_cb.rready <= 1'b0;
        
        // Wait for reset deassertion
        @(posedge vif.clk iff vif.aresetn == 1'b1);
        `uvm_info("DRIVER", "Interface initialized after reset", UVM_HIGH)
    endtask
    
    // Drive transaction
    virtual task drive_transaction(axi4lite_transaction tx);
        transaction_count++;
        
        if (tx.write_not_read) begin
            write_count++;
            drive_write_transaction(tx);
        end
        else begin
            read_count++;
            drive_read_transaction(tx);
        end
        
        // Apply delay between transactions
        repeat (tx.delay_cycles) @(posedge vif.clk);
        
        `uvm_info("DRIVER", $sformatf("Transaction %0d completed: %s", 
            transaction_count, tx.get_transaction_type()), UVM_HIGH)
    endtask
    
    // Drive write transaction
    virtual task drive_write_transaction(axi4lite_transaction tx);
        `uvm_info("DRIVER", $sformatf("Driving WRITE transaction to address 0x%08h", 
            tx.awaddr), UVM_HIGH)
        
        // Write Address Channel
        @(posedge vif.clk);
        vif.driver_cb.awaddr <= tx.awaddr;
        vif.driver_cb.awvalid <= 1'b1;
        
        // Wait for slave ready
        while (vif.driver_cb.awready != 1'b1) begin
            @(posedge vif.clk);
            // Keep signals stable
        end
        
        @(posedge vif.clk);
        vif.driver_cb.awvalid <= 1'b0;
        vif.driver_cb.awaddr <= '0;
        
        // Write Data Channel
        vif.driver_cb.wdata <= tx.wdata;
        vif.driver_cb.wstrb <= tx.wstrb;
        vif.driver_cb.wvalid <= 1'b1;
        
        // Wait for slave ready
        while (vif.driver_cb.wready != 1'b1) begin
            @(posedge vif.clk);
            // Keep signals stable
        end
        
        @(posedge vif.clk);
        vif.driver_cb.wvalid <= 1'b0;
        vif.driver_cb.wdata <= '0;
        vif.driver_cb.wstrb <= 4'b0000;
        
        // Write Response Channel
        vif.driver_cb.bready <= 1'b1;
        
        // Wait for response
        while (vif.driver_cb.bvalid != 1'b1) begin
            @(posedge vif.clk);
        end
        
        @(posedge vif.clk);
        vif.driver_cb.bready <= 1'b0;
        
        // Store response
        tx.bresp = vif.driver_cb.bresp;
        
        // Check response
        if (tx.bresp != 2'b00) begin
            error_count++;
            `uvm_warning("DRIVER", $sformatf("Write transaction got error response: %2b", tx.bresp))
        end
        
        `uvm_info("DRIVER", $sformatf("WRITE transaction completed with response %2b", 
            tx.bresp), UVM_MEDIUM)
    endtask
    
    // Drive read transaction
    virtual task drive_read_transaction(axi4lite_transaction tx);
        `uvm_info("DRIVER", $sformatf("Driving READ transaction from address 0x%08h", 
            tx.araddr), UVM_HIGH)
        
        // Read Address Channel
        @(posedge vif.clk);
        vif.driver_cb.araddr <= tx.araddr;
        vif.driver_cb.arvalid <= 1'b1;
        
        // Wait for slave ready
        while (vif.driver_cb.arready != 1'b1) begin
            @(posedge vif.clk);
            // Keep signals stable
        end
        
        @(posedge vif.clk);
        vif.driver_cb.arvalid <= 1'b0;
        vif.driver_cb.araddr <= '0;
        
        // Read Data Channel
        vif.driver_cb.rready <= 1'b1;
        
        // Wait for data
        while (vif.driver_cb.rvalid != 1'b1) begin
            @(posedge vif.clk);
        end
        
        @(posedge vif.clk);
        vif.driver_cb.rready <= 1'b0;
        
        // Store response and data
        tx.rdata = vif.driver_cb.rdata;
        tx.rresp = vif.driver_cb.rresp;
        
        // Check response
        if (tx.rresp != 2'b00) begin
            error_count++;
            `uvm_warning("DRIVER", $sformatf("Read transaction got error response: %2b", tx.rresp))
        end
        
        `uvm_info("DRIVER", $sformatf("READ transaction completed: data=0x%08h, response=%2b", 
            tx.rdata, tx.rresp), UVM_MEDIUM)
    endtask
    
    // Reset driver
    virtual task reset();
        `uvm_info("DRIVER", "Resetting driver", UVM_MEDIUM)
        initialize_if();
        transaction_count = 0;
        write_count = 0;
        read_count = 0;
        error_count = 0;
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
        `uvm_info("DRIVER_STATS", $sformatf("%sDriver '%s' statistics:", prefix, get_name()), UVM_LOW)
        `uvm_info("DRIVER_STATS", $sformatf("%s  Total transactions: %0d", prefix, transaction_count), UVM_LOW)
        `uvm_info("DRIVER_STATS", $sformatf("%s  Write transactions: %0d", prefix, write_count), UVM_LOW)
        `uvm_info("DRIVER_STATS", $sformatf("%s  Read transactions: %0d", prefix, read_count), UVM_LOW)
        `uvm_info("DRIVER_STATS", $sformatf("%s  Error transactions: %0d", prefix, error_count), UVM_LOW)
        `uvm_info("DRIVER_STATS", $sformatf("%s  Error rate: %0.2f%%", 
            prefix, (transaction_count > 0) ? (100.0 * error_count / transaction_count) : 0.0), UVM_LOW)
    endfunction
    
    // End of elaboration
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        print_statistics();
    endfunction
    
endclass
