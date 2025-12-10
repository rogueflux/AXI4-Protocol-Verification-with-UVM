#!/usr/bin/env tclsh
# waveform_setup.tcl
# Waveform configuration for AXI4-Lite UVM Verification

# Create waveform groups
set wave_group_top "AXI4-Lite Top"
set wave_group_write "Write Channels"
set wave_group_read "Read Channels"
set wave_group_responses "Responses"
set wave_group_uvm "UVM Control"

# Add groups to waveform window
add_wave_group $wave_group_top
add_wave_group $wave_group_write
add_wave_group $wave_group_read
add_wave_group $wave_group_responses
add_wave_group $wave_group_uvm

# Add clock and reset
add_wave -into $wave_group_top \
    /axi4lite_tb/clk \
    /axi4lite_tb/aresetn

# Add write address channel signals
add_wave -into $wave_group_write \
    -label "Write Address" \
    /axi4lite_tb/axi_if/awaddr \
    /axi4lite_tb/axi_if/awvalid \
    /axi4lite_tb/axi_if/awready

# Add write data channel signals
add_wave -into $wave_group_write \
    -label "Write Data" \
    /axi4lite_tb/axi_if/wdata \
    /axi4lite_tb/axi_if/wstrb \
    /axi4lite_tb/axi_if/wvalid \
    /axi4lite_tb/axi_if/wready

# Add write response channel signals
add_wave -into $wave_group_write \
    -label "Write Response" \
    /axi4lite_tb/axi_if/bresp \
    /axi4lite_tb/axi_if/bvalid \
    /axi4lite_tb/axi_if/bready

# Add read address channel signals
add_wave -into $wave_group_read \
    -label "Read Address" \
    /axi4lite_tb/axi_if/araddr \
    /axi4lite_tb/axi_if/arvalid \
    /axi4lite_tb/axi_if/arready

# Add read data channel signals
add_wave -into $wave_group_read \
    -label "Read Data" \
    /axi4lite_tb/axi_if/rdata \
    /axi4lite_tb/axi_if/rresp \
    /axi4lite_tb/axi_if/rvalid \
    /axi4lite_tb/axi_if/rready

# Add response codes with meaningful names
add_wave -into $wave_group_responses \
    -label "Write Response Decoded" \
    [get_waves /axi4lite_tb/axi_if/bresp] \
    -radix symbolic

add_wave -into $wave_group_responses \
    -label "Read Response Decoded" \
    [get_waves /axi4lite_tb/axi_if/rresp] \
    -radix symbolic

# Create symbolic values for response codes
set_response_radix symbolic {
    2'b00 "OKAY"
    2'b01 "EXOKAY"
    2'b10 "SLVERR"
    2'b11 "DECERR"
}

# Add UVM control signals (if available)
if {[find signals -r /axi4lite_tb/* -filter {TYPE == uvm*} -quiet] != ""} {
    add_wave -into $wave_group_uvm \
        /axi4lite_tb/env/master_agent/driver/transaction_count \
        /axi4lite_tb/env/slave_agent/monitor/transaction_count \
        /axi4lite_tb/env/scoreboard/match_count \
        /axi4lite_tb/env/scoreboard/mismatch_count
}

# Set waveform divider position
set_property visible_divider_names { \
    $wave_group_top \
    $wave_group_write \
    $wave_group_read \
    $wave_group_responses \
    $wave_group_uvm \
} [current_wave_config]

# Configure waveform display
set_property display_limit 1000 [current_wave_config]
set_property needs_save false [current_wave_config]

puts "Waveform configuration loaded successfully"
puts "Signals organized into logical groups for easy debugging"
