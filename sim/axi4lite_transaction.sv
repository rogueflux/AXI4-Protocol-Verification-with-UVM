// AXI4-Lite Transaction Class

class axi4lite_transaction extends uvm_sequence_item;
    
    // Transaction attributes
    rand bit [31:0] awaddr;      // Write address
    rand bit [31:0] wdata;       // Write data
    rand bit [3:0]  wstrb;       // Write strobes
    rand bit [31:0] araddr;      // Read address
    bit      [31:0] rdata;       // Read data (not randomized)
    bit      [1:0]  bresp;       // Write response
    bit      [1:0]  rresp;       // Read response
    rand bit        write_not_read;  // 1: write, 0: read
    rand int        delay_cycles;    // Delay between transactions
    bit             transaction_id;  // Unique transaction ID
    
    // Response codes
    typedef enum bit [1:0] {
        OKAY   = 2'b00,
        SLVERR = 2'b10,
        DECERR = 2'b11
    } resp_code_e;
    
    // Address alignment constraint
    constraint addr_alignment {
        awaddr[1:0] == 2'b00;
        araddr[1:0] == 2'b00;
    }
    
    // Write strobe validity constraint
    constraint wstrb_valid {
        wstrb != 4'b0000;
        if (write_not_read) {
            wstrb inside {4'b0001, 4'b0010, 4'b0100, 4'b1000,
                          4'b0011, 4'b0110, 4'b1100, 4'b1111};
        }
    }
    
    // Address range constraint (4KB memory)
    constraint addr_range {
        awaddr < 32'h00001000;
        araddr < 32'h00001000;
    }
    
    // Delay constraint
    constraint delay_range {
        delay_cycles inside {[0:10]};
    }
    
    // Transaction type distribution
    constraint transaction_type {
        write_not_read dist {1'b1 := 50, 1'b0 := 50};
    }
    
    // Control knobs for sequences
    static int transaction_count = 0;
    
    // UVM field automation
    `uvm_object_utils_begin(axi4lite_transaction)
        `uvm_field_int(awaddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(wdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(wstrb, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(araddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(bresp, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(rresp, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(write_not_read, UVM_ALL_ON)
        `uvm_field_int(delay_cycles, UVM_ALL_ON)
        `uvm_field_int(transaction_id, UVM_ALL_ON)
    `uvm_object_utils_end
    
    // Constructor
    function new(string name = "axi4lite_transaction");
        super.new(name);
        transaction_id = transaction_count++;
    endfunction
    
    // Convert to string for debugging
    virtual function string convert2string();
        string str;
        str = {super.convert2string(), $sformatf(
            "\nTransaction ID: %0d\nType: %s\n",
            transaction_id,
            (write_not_read ? "WRITE" : "READ")
        )};
        
        if (write_not_read) begin
            str = {str, $sformatf(
                "Write Address: 0x%08h\nWrite Data: 0x%08h\nWrite Strobe: %4b\nWrite Response: %2b\nDelay: %0d cycles",
                awaddr, wdata, wstrb, bresp, delay_cycles
            )};
        end
        else begin
            str = {str, $sformatf(
                "Read Address: 0x%08h\nRead Data: 0x%08h\nRead Response: %2b\nDelay: %0d cycles",
                araddr, rdata, rresp, delay_cycles
            )};
        end
        
        return str;
    endfunction
    
    // Clone function
    virtual function uvm_object clone();
        axi4lite_transaction tx;
        tx = axi4lite_transaction::type_id::create(get_name());
        tx.copy(this);
        return tx;
    endfunction
    
    // Copy function
    virtual function void copy(axi4lite_transaction rhs);
        awaddr = rhs.awaddr;
        wdata = rhs.wdata;
        wstrb = rhs.wstrb;
        araddr = rhs.araddr;
        rdata = rhs.rdata;
        bresp = rhs.bresp;
        rresp = rhs.rresp;
        write_not_read = rhs.write_not_read;
        delay_cycles = rhs.delay_cycles;
        transaction_id = rhs.transaction_id;
    endfunction
    
    // Compare function
    virtual function bit compare(axi4lite_transaction rhs);
        compare = 1;
        
        // Only compare relevant fields based on transaction type
        if (write_not_read != rhs.write_not_read) begin
            `uvm_error("COMPARE", "Transaction type mismatch")
            compare = 0;
        end
        
        if (write_not_read) begin
            // Compare write transaction
            if (awaddr !== rhs.awaddr) begin
                `uvm_error("COMPARE", $sformatf("Write address mismatch: %0h vs %0h", awaddr, rhs.awaddr))
                compare = 0;
            end
            if (wdata !== rhs.wdata) begin
                `uvm_error("COMPARE", $sformatf("Write data mismatch: %0h vs %0h", wdata, rhs.wdata))
                compare = 0;
            end
            if (wstrb !== rhs.wstrb) begin
                `uvm_error("COMPARE", $sformatf("Write strobe mismatch: %4b vs %4b", wstrb, rhs.wstrb))
                compare = 0;
            end
            if (bresp !== rhs.bresp) begin
                `uvm_error("COMPARE", $sformatf("Write response mismatch: %2b vs %2b", bresp, rhs.bresp))
                compare = 0;
            end
        end
        else begin
            // Compare read transaction
            if (araddr !== rhs.araddr) begin
                `uvm_error("COMPARE", $sformatf("Read address mismatch: %0h vs %0h", araddr, rhs.araddr))
                compare = 0;
            end
            if (rdata !== rhs.rdata) begin
                `uvm_error("COMPARE", $sformatf("Read data mismatch: %0h vs %0h", rdata, rhs.rdata))
                compare = 0;
            end
            if (rresp !== rhs.rresp) begin
                `uvm_error("COMPARE", $sformatf("Read response mismatch: %2b vs %2b", rresp, rhs.rresp))
                compare = 0;
            end
        end
        
        return compare;
    endfunction
    
    // Pack transaction for analysis
    virtual function void pack(ref byte unsigned bytes[]);
        bytes = new[20];  // Total bytes needed
        bytes[0] = write_not_read;
        
        if (write_not_read) begin
            // Pack write transaction (17 bytes)
            {bytes[1], bytes[2], bytes[3], bytes[4]} = awaddr;
            {bytes[5], bytes[6], bytes[7], bytes[8]} = wdata;
            bytes[9] = wstrb;
            bytes[10] = {6'b0, bresp};
            bytes[11] = delay_cycles[7:0];
            bytes[12] = delay_cycles[15:8];
        end
        else begin
            // Pack read transaction (17 bytes)
            {bytes[1], bytes[2], bytes[3], bytes[4]} = araddr;
            {bytes[5], bytes[6], bytes[7], bytes[8]} = rdata;
            bytes[9] = {6'b0, rresp};
            bytes[10] = delay_cycles[7:0];
            bytes[11] = delay_cycles[15:8];
        end
    endfunction
    
    // Unpack transaction from bytes
    virtual function void unpack(const ref byte unsigned bytes[]);
        write_not_read = bytes[0];
        
        if (write_not_read) begin
            awaddr = {bytes[1], bytes[2], bytes[3], bytes[4]};
            wdata = {bytes[5], bytes[6], bytes[7], bytes[8]};
            wstrb = bytes[9];
            bresp = bytes[10][1:0];
            delay_cycles = {bytes[12], bytes[11]};
        end
        else begin
            araddr = {bytes[1], bytes[2], bytes[3], bytes[4]};
            rdata = {bytes[5], bytes[6], bytes[7], bytes[8]};
            rresp = bytes[9][1:0];
            delay_cycles = {bytes[12], bytes[11]};
        end
    endfunction
    
    // Get transaction type as string
    virtual function string get_transaction_type();
        return (write_not_read ? "WRITE" : "READ");
    endfunction
    
    // Check if response is OK
    virtual function bit is_response_ok();
        if (write_not_read) begin
            return (bresp == OKAY);
        end
        else begin
            return (rresp == OKAY);
        end
    endfunction
    
    // Check if response is error
    virtual function bit is_response_error();
        if (write_not_read) begin
            return (bresp != OKAY);
        end
        else begin
            return (rresp != OKAY);
        end
    endfunction
    
endclass
