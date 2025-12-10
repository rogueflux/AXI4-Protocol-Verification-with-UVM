# AXI4-Lite Protocol Verification with UVM in Vivado

[![SystemVerilog](https://img.shields.io/badge/SystemVerilog-UVMFramework-blue.svg)](https://www.accellera.org/downloads/standards/uvm)
[![Vivado](https://img.shields.io/badge/Xilinx-Vivado-FF1010.svg)](https://www.xilinx.com/products/design-tools/vivado.html)
[![AXI4-Lite](https://img.shields.io/badge/ARM-AXI4--Lite-0091BD.svg)](https://developer.arm.com/documentation/ihi0022/latest/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A comprehensive UVM-based verification environment for the AMBA AXI4-Lite protocol, implemented using Xilinx Vivado and SystemVerilog. This project provides a scalable, reusable testbench for verifying AXI4-Lite slave peripherals with professional-grade verification methodology.

## Table of Contents
- [Overview](#overview)
- [Project Architecture](#project-architecture)
- [Features](#features)
- [Directory Structure](#directory-structure)
- [Setup Instructions](#setup-instructions)
- [Running Simulations](#running-simulations)
- [Verification Components](#verification-components)
- [Coverage Metrics](#coverage-metrics)
- [Key Test Scenarios](#key-test-scenarios)
- [Results and Reports](#results-and-reports)
- [References](#references)

## Overview

The AXI4-Lite Protocol Verification project establishes a scalable, reusable UVM testbench environment capable of thoroughly exercising all aspects of the AMBA AXI4-Lite specification. AXI4-Lite represents a simplified subset of the full AXI4 protocol, specifically designed for **lower-bandwidth peripheral applications** where burst transactions are not required.

This project demonstrates a **professional-grade verification methodology** applicable to complex SoC designs by combining constrained random stimulus generation, comprehensive functional coverage, protocol assertions, and automated scoreboarding.


## Project Architecture

The UVM testbench consists of a hierarchical composition of reusable verification components:

- **Two UVM Agents**: Master (ACTIVE) and Slave (PASSIVE) for bidirectional verification
- **Transaction Layer**: Encapsulates AXI4-Lite protocol attributes
- **Scoreboard**: Compares expected vs. actual DUT behavior
- **Coverage Collector**: Tracks protocol specification completeness
- **Assertion Monitor**: Real-time protocol violation detection
- **Virtual Interface**: Abstracts DUT signal connections

## Features

- **Complete UVM Testbench**: All standard UVM components implemented
- **Constrained Random Verification**: Automated stimulus generation with protocol constraints
- **Functional Coverage**: Comprehensive coverage model for AXI4-Lite specification
- **SystemVerilog Assertions**: Real-time protocol compliance checking
- **Vivado Integration**: Native UVM 1.2 support with XSim simulator
- **Scalable Architecture**: Reusable components for different AXI4 configurations
- **Automated Scripts**: TCL scripts for project setup and simulation control
- **Documentation**: Detailed protocol verification methodology

## Directory Structure

```
axi4lite-uvm-verification/
├── README.md
├── LICENSE
├── .gitignore
├── rtl/
│   └── axi4lite_slave.v                 # AXI4-Lite DUT (Slave implementation)
├── sim/
│   ├── axi4lite_pkg.sv                  # UVM package with all components
│   ├── axi4lite_if.sv                   # Interface with embedded SVAs
│   ├── axi4lite_tb.sv                   # Top-level testbench
│   ├── sequences/
│   │   ├── axi4lite_sequence.sv         # Base sequence
│   │   ├── axi4lite_boundary_sequence.sv
│   │   └── axi4lite_error_sequence.sv
│   └── tests/
│       ├── axi4lite_base_test.sv        # Base test class
│       └── axi4lite_write_read_test.sv  # Specific test scenario
├── scripts/
│   ├── create_project.tcl               # Vivado project creation
│   ├── add_files.tcl                    # File management
│   ├── run_simulation.tcl               # Simulation control
│   └── compile_all.tcl                  # Batch compilation
├── docs/
│   ├── protocol_spec.md                 # AXI4-Lite protocol details
│   └── verification_plan.md             # Verification strategy
├── constraints/
│   └── timing.xdc                       # Timing constraints
├── reports/
│   ├── coverage_report.html             # Coverage results
│   └── simulation_results.log           # Simulation logs
└── media/
    ├── image1.jpg                       # Architecture diagram
    ├── image2.jpg                       # Timing diagram
    └── image3.png                       # Methodology flow
```

## Setup Instructions

### Prerequisites
- **Xilinx Vivado Design Suite** (2020.1 or later)
- **SystemVerilog** knowledge
- **UVM 1.2** understanding
- Basic **Tcl** scripting skills

### Quick Start
1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/axi4lite-uvm-verification.git
   cd axi4lite-uvm-verification
   ```

2. **Create Vivado project using Tcl script:**
   ```bash
   vivado -mode batch -source scripts/create_project.tcl
   ```

3. **Open project in Vivado:**
   ```bash
   vivado axi4_uvm_project/axi4_uvm.xpr
   ```

4. **Run a basic simulation:**
   ```tcl
   source scripts/run_simulation.tcl
   ```

### Manual Setup
1. Create new Vivado project with SystemVerilog as simulator language
2. Add RTL files from `rtl/` directory
3. Add simulation files from `sim/` directory
4. Configure UVM settings:
   ```tcl
   set_property -name {xsim.compile.xvlog.more_options} -value {-L uvm} -objects [get_filesets sim_1]
   set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} -objects [get_filesets sim_1]
   ```

## Running Simulations

### Command Line (Batch Mode)
```bash
# Compile and elaborate
xvlog -sv -work work -L uvm sim/axi4lite_if.sv sim/axi4lite_pkg.sv sim/axi4lite_tb.sv rtl/axi4lite_slave.v
xelab -work work -top axi4lite_tb -snapshot axi4lite_sim -L uvm

# Run simulation
xsim axi4lite_sim -R -tclbatch scripts/xsim_cfg.tcl
```

### Vivado GUI
1. Open the project in Vivado
2. Navigate to **Flow Navigator → Simulation → Run Simulation → Run Behavioral Simulation**
3. Use the Tcl Console to control simulation:
   ```tcl
   run 100us
   restart
   run -all
   ```

### Available Tests
```systemverilog
// Run specific test from Tcl console
set_property generic {UVM_TESTNAME=axi4lite_write_read_test} [get_filesets sim_1]
```

## Verification Components

### 1. Transaction Object (`axi4lite_transaction.sv`)
Encapsulates all AXI4-Lite protocol attributes into a randomizable UVM sequence item with constraints for address alignment, write strobes, and valid transactions.

### 2. Sequencer (`axi4lite_sequencer.sv`)
Manages the flow of randomized transactions from sequences to the driver using TLM ports for asynchronous communication.

### 3. Driver (`axi4lite_driver.sv`)
Converts transaction objects into pin-level signal manipulations, implementing the VALID/READY handshake protocol for both read and write channels.

### 4. Monitor (`axi4lite_monitor.sv`)
Passively observes signal activity on the interface, captures transactions, and publishes them to analysis ports for scoreboarding and coverage.

### 5. Coverage Collector (`axi4lite_coverage.sv`)
Tracks functional coverage metrics including transaction types, address ranges, write strobe patterns, and response codes.

### 6. Scoreboard (`axi4lite_scoreboard.sv`)
Compares expected behavior against actual DUT responses, identifying mismatches and maintaining match statistics.

### 7. Interface (`axi4lite_if.sv`)
Defines all AXI4-Lite signals with modports for master/slave connections and embedded SystemVerilog Assertions for protocol checking.

## Coverage Metrics

The project targets comprehensive verification closure with the following metrics:

| Metric | Target | Purpose |
|--------|--------|---------|
| **Functional Coverage** | >95% | All specification scenarios exercised |
| **Code Coverage (Line)** | 100% | All RTL statements executed |
| **Code Coverage (Branch)** | 95%+ | All decision paths taken |
| **Transaction Count** | 10,000+ | Sufficient stimulus diversity |
| **Assertion Passes** | 100% | No protocol violations detected |
| **Scoreboard Matches** | 100% | No DUT behavior mismatches |

## Key Test Scenarios

1. **Basic Read/Write Transactions**: Single-address operations with OKAY responses
2. **Address Alignment Violations**: Unaligned addresses triggering protocol errors
3. **Write Strobe Variations**: All byte-enable combinations (0001, 0010, 0100, 1000, 1111)
4. **Error Response Scenarios**: SLVERR for invalid addresses, DECERR for decode errors
5. **Timing Edge Cases**: Back-to-back transactions, minimal delays, maximum pipeline depth
6. **Back-Pressure Handling**: READY signal deassertion causing transaction stalling
7. **Out-of-Order Completion**: Read address accepted but read data significantly delayed
8. **Boundary Addresses**: Transactions at memory space limits (0x00000000, 0xFFFFFFFC)

## Results and Reports

After simulation, the following reports are generated:

- **Coverage Report**: HTML report showing functional and code coverage
- **Assertion Summary**: List of passed/failed protocol assertions
- **Scoreboard Results**: Transaction match/mismatch statistics
- **Waveform Database**: .wdb file for debugging in Vivado Waveform Viewer

To generate reports:
```tcl
# Generate coverage report
report_coverage -html -output coverage_report.html

# Export simulation data
log_sim -type uvm -file simulation_log.txt
```

## References

1. [AMBA AXI4-Lite Protocol Specification](https://developer.arm.com/documentation/ihi0022/latest/)
2. [UVM 1.2 User's Guide](https://www.accellera.org/images/downloads/standards/uvm/UVM_Users_Guide_1.2.pdf)
3. [Xilinx Vivado Design Suite User Guide](https://docs.xilinx.com/v/u/en-US/ug973-vivado-release-notes-install-license)
4. [SystemVerilog IEEE 1800-2017 Standard](https://ieeexplore.ieee.org/document/8299595)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- ARM for the AMBA AXI4 specification
- Accellera for the Universal Verification Methodology (UVM)
- Xilinx for Vivado Design Suite and UVM integration
- All contributors and verification engineers who provided feedback

*Note: This project is for educational and professional verification purposes. Always verify against the latest AXI4 specification from ARM.*
