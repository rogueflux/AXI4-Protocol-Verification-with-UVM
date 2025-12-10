#!/usr/bin/env tclsh
# create_project.tcl
# Vivado project creation script for AXI4-Lite UVM Verification

# Set project variables
set project_name "axi4lite_uvm_verification"
set project_dir "./$project_name"
set part_name "xc7z020clg484-1"  # Zynq-7000 device
set simulator_language "SystemVerilog"
set target_language "Verilog"

# Create project
create_project -force $project_name $project_dir -part $part_name

# Set project properties
set_property simulator_language $simulator_language [current_project]
set_property target_language $target_language [current_project]
set_property default_lib work [current_project]
set_property simulator "XSim" [current_project]

puts "Created project: $project_name"
puts "Project directory: $project_dir"
puts "Target part: $part_name"

# Create directory structure
file mkdir "$project_dir/rtl"
file mkdir "$project_dir/sim"
file mkdir "$project_dir/sim/sequences"
file mkdir "$project_dir/sim/tests"
file mkdir "$project_dir/scripts"
file mkdir "$project_dir/constraints"
file mkdir "$project_dir/reports"
file mkdir "$project_dir/waveforms"

# Set up source filesets
# Create RTL fileset
create_fileset -blockset -define_from sources_1 rtl_sources
set_property top axi4lite_slave [get_filesets rtl_sources]

# Create simulation fileset
create_fileset -simset sim_1
set_property top axi4lite_tb [get_filesets sim_1]

# Create constraints fileset
create_fileset -constrset constrs_1

# Enable UVM support
set_property -name {xsim.compile.xvlog.more_options} -value {-L uvm} [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} [get_filesets sim_1]

# Enable better simulation visibility
set_property -name {xsim.simulate.log_all_signals} -value {true} [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {100us} [get_filesets sim_1]

# Enable code coverage
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg UVM_TESTNAME=axi4lite_write_read_test} [get_filesets sim_1]

puts "Project structure created successfully"

# Save project
save_project_as -force $project_dir/${project_name}.xpr

puts "Project saved: $project_dir/${project_name}.xpr"
puts ""
puts "Next steps:"
puts "1. Add RTL files: add_files -fileset sources_1 ./rtl/*.v"
puts "2. Add simulation files: add_files -fileset sim_1 ./sim/*.sv"
puts "3. Add sequences: add_files -fileset sim_1 ./sim/sequences/*.sv"
puts "4. Add tests: add_files -fileset sim_1 ./sim/tests/*.sv"
puts "5. Run: source scripts/add_files.tcl"
