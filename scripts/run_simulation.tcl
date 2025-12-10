#!/usr/bin/env tclsh
# run_simulation.tcl
# Run simulation for AXI4-Lite UVM Verification

# Set project paths
set project_name "axi4lite_uvm_verification"
set project_dir "./$project_name"

# Simulation parameters
set test_name "axi4lite_write_read_test"
set simulation_time "100us"
set waveform_depth "1000"
set uvm_verbosity "UVM_MEDIUM"
set coverage_enable 1
set wave_enable 1

puts "=============================================="
puts "AXI4-Lite UVM Verification Simulation"
puts "=============================================="
puts "Project: $project_name"
puts "Test: $test_name"
puts "Simulation time: $simulation_time"
puts "UVN Verbosity: $uvm_verbosity"
puts ""

# Open project if not already open
if {[get_projects -quiet] eq ""} {
    open_project $project_dir/${project_name}.xpr
    puts "Opened project: $project_name"
}

# Set current simulation fileset
current_fileset -simset [get_filesets sim_1]

# ------------------------------------------------------------------
# Configure simulation settings
# ------------------------------------------------------------------
puts "Configuring simulation settings..."

# Set simulation runtime
set_property -name {xsim.simulate.runtime} -value $simulation_time [get_filesets sim_1]

# Set UVM test name
set_property -name {xsim.simulate.xsim.more_options} \
    -value "+UVM_TESTNAME=$test_name +UVM_VERBOSITY=$uvm_verbosity" \
    [get_filesets sim_1]

# Enable logging
set_property -name {xsim.simulate.log_all_signals} -value {true} [get_filesets sim_1]

# Enable waveform if requested
if {$wave_enable} {
    set_property -name {xsim.simulate.custom_wave_do} -value "./scripts/waveform_setup.tcl" [get_filesets sim_1]
    puts "  Waveform enabled with depth: $waveform_depth"
}

# Enable coverage if requested
if {$coverage_enable} {
    set_property -name {xsim.simulate.xsim.more_options} \
        -value "+UVM_TESTNAME=$test_name +UVM_VERBOSITY=$uvm_verbosity -coverage" \
        [get_filesets sim_1]
    puts "  Code coverage enabled"
}

# ------------------------------------------------------------------
# Launch simulation
# ------------------------------------------------------------------
puts ""
puts "Launching simulation..."
puts ""

# Get current time for performance measurement
set start_time [clock seconds]

# Launch behavioral simulation
launch_simulation -mode behavioral

# Wait for simulation to complete
puts "Simulation running..."
puts ""

# Monitor simulation progress
set sim_active 1
while {$sim_active} {
    # Check if simulation is still running
    set sim_status [get_property -quiet STATUS [current_sim]]
    
    if {[regexp {stopped|finished|error} $sim_status]} {
        set sim_active 0
        break
    }
    
    # Wait a bit before checking again
    after 1000
    
    # Get current simulation time
    set current_time [get_property -quiet TIME [current_sim]]
    if {$current_time != ""} {
        puts "  Simulation time: $current_time"
    }
}

# Get simulation end time
set end_time [clock seconds]
set elapsed_time [expr {$end_time - $start_time}]

# ------------------------------------------------------------------
# Generate reports
# ------------------------------------------------------------------
puts ""
puts "Simulation completed!"
puts "Elapsed time: ${elapsed_time}s"
puts ""

# Generate coverage report if enabled
if {$coverage_enable} {
    puts "Generating coverage report..."
    
    # Open coverage database
    if {[catch {open_coverage_db -load ${project_dir}/reports/coverage.ucd} result]} {
        puts "  Warning: Could not open coverage database: $result"
    } else {
        # Generate HTML coverage report
        report_coverage -file ${project_dir}/reports/coverage_report.html -html
        puts "  Coverage report saved: ${project_dir}/reports/coverage_report.html"
        
        # Generate text coverage report
        report_coverage -file ${project_dir}/reports/coverage_summary.txt
        puts "  Coverage summary saved: ${project_dir}/reports/coverage_summary.txt"
        
        # Get coverage statistics
        set overall_coverage [get_property -quiet OVERALL_COVERAGE [current_coverage_db]]
        if {$overall_coverage != ""} {
            puts "  Overall coverage: ${overall_coverage}%"
        }
    }
}

# Save waveform configuration
if {$wave_enable} {
    puts "Saving waveform configuration..."
    save_wave_config ${project_dir}/waveforms/${test_name}_wave.wcfg
    puts "  Waveform saved: ${project_dir}/waveforms/${test_name}_wave.wcfg"
}

# Generate simulation log summary
puts ""
puts "Generating simulation log summary..."
set log_file "${project_dir}/reports/${test_name}_simulation.log"

if {[file exists $log_file]} {
    # Count UVM messages
    set uvm_info_count [exec grep -c "UVM_INFO" $log_file]
    set uvm_warning_count [exec grep -c "UVM_WARNING" $log_file]
    set uvm_error_count [exec grep -c "UVM_ERROR" $log_file]
    set uvm_fatal_count [exec grep -c "UVM_FATAL" $log_file]
    
    puts "  UVM Messages Summary:"
    puts "    INFO:    $uvm_info_count"
    puts "    WARNING: $uvm_warning_count"
    puts "    ERROR:   $uvm_error_count"
    puts "    FATAL:   $uvm_fatal_count"
    
    # Check for test pass/fail
    set test_result [exec grep -c "TEST.*PASSED" $log_file]
    if {$test_result > 0} {
        puts ""
        puts "  =========================================="
        puts "    TEST PASSED SUCCESSFULLY!"
        puts "  =========================================="
    } else {
        set test_fail [exec grep -c "TEST.*FAILED" $log_file]
        if {$test_fail > 0} {
            puts ""
            puts "  =========================================="
            puts "    TEST FAILED!"
            puts "  =========================================="
        }
    }
}

# Save project
save_project

puts ""
puts "=============================================="
puts "Simulation completed!"
puts "Reports saved in: ${project_dir}/reports/"
puts "Waveforms saved in: ${project_dir}/waveforms/"
puts "=============================================="

# Close simulation if still open
if {[current_sim -quiet] != ""} {
    close_sim
    puts "Simulation closed."
}
