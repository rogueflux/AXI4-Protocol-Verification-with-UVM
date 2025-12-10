#!/usr/bin/env tclsh
# compile_all.tcl
# Batch compilation script for AXI4-Lite UVM Verification

# Set project paths
set project_name "axi4lite_uvm_verification"
set project_dir "./$project_name"

# Compilation parameters
set compile_clean 1          # Clean before compiling
set compile_verbose 1        # Verbose compilation output
set compile_optimize 1       # Enable optimization
set compile_debug 1          # Enable debug information

puts "=============================================="
puts "AXI4-Lite UVM Verification - Batch Compilation"
puts "=============================================="
puts "Project: $project_name"
puts ""

# Open project if not already open
if {[get_projects -quiet] eq ""} {
    open_project $project_dir/${project_name}.xpr
    puts "Opened project: $project_name"
}

# Set current simulation fileset
current_fileset -simset [get_filesets sim_1]

# ------------------------------------------------------------------
# Clean previous compilation (if requested)
# ------------------------------------------------------------------
if {$compile_clean} {
    puts "Cleaning previous compilation..."
    
    # Delete previous simulation files
    if {[file exists ${project_dir}/.Xil]} {
        file delete -force ${project_dir}/.Xil
        puts "  Deleted: ${project_dir}/.Xil"
    }
    
    if {[file exists ${project_dir}/xsim.dir]} {
        file delete -force ${project_dir}/xsim.dir
        puts "  Deleted: ${project_dir}/xsim.dir"
    }
    
    # Reset simulation state
    reset_simulation -simset [get_filesets sim_1]
    puts "  Reset simulation state"
}

# ------------------------------------------------------------------
# Configure compilation options
# ------------------------------------------------------------------
puts ""
puts "Configuring compilation options..."

# Set UVM library path
set_property -name {xsim.compile.xvlog.more_options} -value {-L uvm} [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} [get_filesets sim_1]

# Set optimization level
if {$compile_optimize} {
    set_property -name {xsim.compile.xvlog.more_options} \
        -value {-L uvm -O2} [get_filesets sim_1]
    set_property -name {xsim.elaborate.xelab.more_options} \
        -value {-L uvm -O2} [get_filesets sim_1]
    puts "  Optimization enabled (O2)"
}

# Set debug options
if {$compile_debug} {
    set_property -name {xsim.compile.xvlog.more_options} \
        -value {-L uvm -d SV_COV -d UVM_NO_DEPRECATED} [get_filesets sim_1]
    set_property -name {xsim.elaborate.xelab.more_options} \
        -value {-L uvm -debug all} [get_filesets sim_1]
    puts "  Debug information enabled"
}

# Set verbose output
if {$compile_verbose} {
    set_property -name {xsim.compile.xvlog.more_options} \
        -value {-L uvm -v} [get_filesets sim_1]
    set_property -name {xsim.elaborate.xelab.more_options} \
        -value {-L uvm -v} [get_filesets sim_1]
    puts "  Verbose output enabled"
}

# ------------------------------------------------------------------
# Update compile order
# ------------------------------------------------------------------
puts ""
puts "Updating compile order..."

# Update compile order for simulation files
update_compile_order -fileset [get_filesets sim_1]

# Check for compilation order issues
set compile_order_problems [get_property -quiet COMPILE_ORDER_PROBLEMS [get_filesets sim_1]]
if {$compile_order_problems != ""} {
    puts "  Warning: Compile order problems detected:"
    puts "  $compile_order_problems"
} else {
    puts "  Compile order OK"
}

# ------------------------------------------------------------------
# Compile RTL sources
# ------------------------------------------------------------------
puts ""
puts "Compiling RTL sources..."

set rtl_files [get_files -of_objects [get_filesets sources_1]]
puts "  RTL files to compile: [llength $rtl_files]"

foreach rtl_file $rtl_files {
    puts "    Compiling: [file tail $rtl_file]"
}

# Compile RTL
if {[catch {compile -force -simpack rtl_sources} result]} {
    puts "  ERROR: RTL compilation failed!"
    puts "  $result"
    return -code error
} else {
    puts "  RTL compilation successful"
}

# ------------------------------------------------------------------
# Compile simulation sources
# ------------------------------------------------------------------
puts ""
puts "Compiling simulation sources..."

set sim_files [get_files -of_objects [get_filesets sim_1]]
puts "  Simulation files to compile: [llength $sim_files]"

# Get compilation order
set compile_order [get_files -compile_order sources -used_in simulation -of_objects [get_filesets sim_1]]
puts "  Files in compile order: [llength $compile_order]"

# Start compilation
set start_time [clock seconds]

puts ""
puts "Starting SystemVerilog compilation..."

# Compile using xvlog
if {[catch {compile_simlib -force -verbose -simulator xsim -family virtex7 -language all -library all} result]} {
    puts "  ERROR: UVM library compilation failed!"
    puts "  $result"
} else {
    puts "  UVM library compilation successful"
}

# Compile simulation sources
if {[catch {xsim compile_sim -force -verbose -simulator xsim -library unisim -library unimacro -library secureip} result]} {
    puts "  ERROR: Simulation compilation failed!"
    puts "  $result"
    return -code error
} else {
    puts "  Simulation compilation successful"
}

# ------------------------------------------------------------------
# Elaborate design
# ------------------------------------------------------------------
puts ""
puts "Elaborating design..."

set elaboration_start [clock seconds]

# Elaborate the design
if {[catch {elaborate -force -verbose -simulator xsim -top axi4lite_tb} result]} {
    puts "  ERROR: Elaboration failed!"
    puts "  $result"
    return -code error
} else {
    set elaboration_end [clock seconds]
    set elaboration_time [expr {$elaboration_end - $elaboration_start}]
    puts "  Elaboration successful (${elaboration_time}s)"
}

# ------------------------------------------------------------------
# Create simulation snapshot
# ------------------------------------------------------------------
puts ""
puts "Creating simulation snapshot..."

set snapshot_name "${project_name}_snapshot"

if {[catch {create_snapshot -force -name $snapshot_name -simulator xsim -directory ${project_dir}/xsim.dir} result]} {
    puts "  ERROR: Snapshot creation failed!"
    puts "  $result"
} else {
    puts "  Snapshot created: $snapshot_name"
}

# ------------------------------------------------------------------
# Performance statistics
# ------------------------------------------------------------------
set end_time [clock seconds]
set total_time [expr {$end_time - $start_time}]

puts ""
puts "=============================================="
puts "Compilation Summary"
puts "=============================================="
puts "Total compilation time: ${total_time}s"
puts "RTL files compiled: [llength $rtl_files]"
puts "Simulation files compiled: [llength $sim_files]"
puts "Snapshot created: $snapshot_name"
puts ""

# Check for warnings
set warning_count [get_msg_config -quiet -severity {Warning} -count]
if {$warning_count > 0} {
    puts "Warnings detected: $warning_count"
    # List warnings if verbose
    if {$compile_verbose} {
        puts "Warning messages:"
        foreach msg [get_msg_config -quiet -severity {Warning}] {
            puts "  $msg"
        }
    }
} else {
    puts "No warnings detected"
}

# Check for errors
set error_count [get_msg_config -quiet -severity {Error} -count]
if {$error_count > 0} {
    puts "ERRORS detected: $error_count"
    puts "Compilation failed!"
    # List errors
    puts "Error messages:"
    foreach msg [get_msg_config -quiet -severity {Error}] {
        puts "  $msg"
    }
    return -code error
} else {
    puts "No errors detected"
    puts ""
    puts "=============================================="
    puts "COMPILATION SUCCESSFUL!"
    puts "=============================================="
    puts ""
    puts "Next steps:"
    puts "  1. Run simulation: source scripts/run_simulation.tcl"
    puts "  2. Or run specific test:"
    puts "     set_property -name {xsim.simulate.xsim.more_options} \\"
    puts "       -value {+UVM_TESTNAME=axi4lite_write_read_test} \\"
    puts "       [get_filesets sim_1]"
    puts "     launch_simulation"
}

# Save project
save_project

puts ""
puts "Project saved: $project_dir/${project_name}.xpr"
