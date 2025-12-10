#!/usr/bin/env tclsh
# add_files.tcl
# Add files to Vivado project for AXI4-Lite UVM Verification

# Set project paths
set project_name "axi4lite_uvm_verification"
set project_dir "./$project_name"

# Open project if not already open
if {[get_projects -quiet] eq ""} {
    open_project $project_dir/${project_name}.xpr
}

puts "Adding files to project: $project_name"
puts "Current working directory: [pwd]"

# ------------------------------------------------------------------
# Add RTL source files
# ------------------------------------------------------------------
puts "Adding RTL source files..."

# Add AXI4-Lite slave DUT
add_files -norecurse -fileset [get_filesets sources_1] \
    ./rtl/axi4lite_slave.v

# Set top module for RTL
set_property top axi4lite_slave [get_filesets sources_1]

# ------------------------------------------------------------------
# Add simulation files
# ------------------------------------------------------------------
puts "Adding simulation files..."

# Add interface
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_if.sv

# Add transaction class
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_transaction.sv

# Add configuration
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_config.sv

# Add sequencer
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_sequencer.sv

# Add driver
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_driver.sv

# Add monitor
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_monitor.sv

# Add agent
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_agent.sv

# Add coverage collector
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_coverage.sv

# Add scoreboard
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_scoreboard.sv

# Add environment
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_env.sv

# Add top-level testbench
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_tb.sv

# Add package (must be added last for proper compilation order)
add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/axi4lite_pkg.sv

# ------------------------------------------------------------------
# Add sequence files
# ------------------------------------------------------------------
puts "Adding sequence files..."

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/sequences/axi4lite_sequence.sv

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/sequences/axi4lite_random_sequence.sv

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/sequences/axi4lite_boundary_sequence.sv

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/sequences/axi4lite_error_sequence.sv

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/sequences/axi4lite_write_read_sequence.sv

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/sequences/axi4lite_backpressure_sequence.sv

# ------------------------------------------------------------------
# Add test files
# ------------------------------------------------------------------
puts "Adding test files..."

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/tests/axi4lite_base_test.sv

add_files -norecurse -fileset [get_filesets sim_1] \
    ./sim/tests/axi4lite_write_read_test.sv

# ------------------------------------------------------------------
# Add constraint files (if any)
# ------------------------------------------------------------------
if {[file exists ./constraints/timing.xdc]} {
    puts "Adding constraint files..."
    add_files -norecurse -fileset [get_filesets constrs_1] \
        ./constraints/timing.xdc
}

# ------------------------------------------------------------------
# Set compilation order for UVM files
# ------------------------------------------------------------------
puts "Setting compilation order..."

# Define compilation order for proper dependency resolution
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]

# Set top module for simulation
set_property top axi4lite_tb [get_filesets sim_1]

# Set simulation runtime arguments
set_property -name {xsim.simulate.xsim.more_options} \
    -value {-testplusarg UVM_TESTNAME=axi4lite_write_read_test} \
    [get_filesets sim_1]

# Enable UVM messages in simulation
set_property -name {xsim.simulate.xsim.more_options} \
    -value {+UVM_TESTNAME=axi4lite_write_read_test +UVM_VERBOSITY=UVM_MEDIUM} \
    [get_filesets sim_1]

# ------------------------------------------------------------------
# Update compilation order
# ------------------------------------------------------------------
update_compile_order -fileset [get_filesets sim_1]
update_compile_order -fileset [get_filesets sources_1]

# ------------------------------------------------------------------
# Report file status
# ------------------------------------------------------------------
puts ""
puts "File addition completed!"
puts ""
puts "RTL files added:"
foreach file [get_files -of_objects [get_filesets sources_1]] {
    puts "  [file tail $file]"
}

puts ""
puts "Simulation files added:"
set sim_files [get_files -of_objects [get_filesets sim_1]]
puts "  Total simulation files: [llength $sim_files]"

puts ""
puts "Current simulation top: [get_property top [get_filesets sim_1]]"
puts "Current RTL top: [get_property top [get_filesets sources_1]]"

# Save project
save_project

puts ""
puts "Project saved successfully!"
puts ""
puts "To compile and run simulation:"
puts "  source scripts/compile_all.tcl"
puts "  source scripts/run_simulation.tcl"
