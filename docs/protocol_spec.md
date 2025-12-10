# AXI4-Lite Protocol Specification
## AMBA AXI4-Lite Interface for UVM Verification

## Table of Contents
1. [Introduction](#introduction)
2. [Protocol Overview](#protocol-overview)
3. [Channel Architecture](#channel-architecture)
4. [Signal Descriptions](#signal-descriptions)
5. [Transaction Types](#transaction-types)
6. [Handshake Protocol](#handshake-protocol)
7. [Response Codes](#response-codes)
8. [Address Alignment](#address-alignment)
9. [Write Strobes](#write-strobes)
10. [Timing Requirements](#timing-requirements)
11. [Error Conditions](#error-conditions)
12. [Protocol Limitations](#protocol-limitations)

## Introduction

The **AXI4-Lite** (Advanced eXtensible Interface 4 Lite) is a simplified subset of the full AXI4 protocol designed for lower-bandwidth peripheral applications. It provides a simple, low-cost interface for register-mapped peripherals and memory-mapped I/O operations.

### Key Features
- **32-bit address and data bus**
- **Single transaction support** (no bursts)
- **Five independent channels**
- **VALID/READY handshake flow control**
- **Three response types**
- **Byte-level write strobes**

## Protocol Overview

AXI4-Lite eliminates complex features from full AXI4:
- ❌ No burst transactions (single transfers only)
- ❌ No cache support
- ❌ No QoS (Quality of Service)
- ❌ No multiple outstanding addresses
- ❌ No exclusive accesses
- ❌ No locking mechanism

## Channel Architecture

AXI4-Lite consists of **five independent channels**:

### 1. Write Address Channel (AW)
- `AWADDR[31:0]` - Write address
- `AWVALID` - Write address valid
- `AWREADY` - Write address ready

### 2. Write Data Channel (W)
- `WDATA[31:0]` - Write data
- `WSTRB[3:0]` - Write byte strobes
- `WVALID` - Write data valid
- `WREADY` - Write data ready

### 3. Write Response Channel (B)
- `BRESP[1:0]` - Write response
- `BVALID` - Write response valid
- `BREADY` - Write response ready

### 4. Read Address Channel (AR)
- `ARADDR[31:0]` - Read address
- `ARVALID` - Read address valid
- `ARREADY` - Read address ready

### 5. Read Data Channel (R)
- `RDATA[31:0]` - Read data
- `RRESP[1:0]` - Read response
- `RVALID` - Read data valid
- `RREADY` - Read data ready

## Signal Descriptions

### Global Signals
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `ACLK` | 1 | Input | Global clock signal |
| `ARESETn` | 1 | Input | Active-low asynchronous reset |

### Write Address Channel
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `AWADDR` | 32 | Input | Write address (byte aligned) |
| `AWVALID` | 1 | Input | Write address valid |
| `AWREADY` | 1 | Output | Write address ready |

### Write Data Channel
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `WDATA` | 32 | Input | Write data |
| `WSTRB` | 4 | Input | Write byte strobes |
| `WVALID` | 1 | Input | Write data valid |
| `WREADY` | 1 | Output | Write data ready |

### Write Response Channel
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `BRESP` | 2 | Output | Write response |
| `BVALID` | 1 | Output | Write response valid |
| `BREADY` | 1 | Input | Write response ready |

### Read Address Channel
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `ARADDR` | 32 | Input | Read address (byte aligned) |
| `ARVALID` | 1 | Input | Read address valid |
| `ARREADY` | 1 | Output | Read address ready |

### Read Data Channel
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `RDATA` | 32 | Output | Read data |
| `RRESP` | 2 | Output | Read response |
| `RVALID` | 1 | Output | Read data valid |
| `RREADY` | 1 | Input | Read data ready |

## Transaction Types

### Write Transaction Sequence
1. **Address Phase**: AWVALID & AWREADY handshake
2. **Data Phase**: WVALID & WREADY handshake
3. **Response Phase**: BVALID & BREADY handshake

### Read Transaction Sequence
1. **Address Phase**: ARVALID & ARREADY handshake
2. **Data Phase**: RVALID & RREADY handshake

## Handshake Protocol

### VALID/READY Signaling Rules

#### Rule 1: VALID must not depend on READY
- A source can assert VALID without waiting for READY
- Once asserted, VALID must remain asserted until handshake occurs

#### Rule 2: READY can wait for VALID
- A destination can wait for VALID before asserting READY
- READY can be asserted before or after VALID is asserted

#### Rule 3: Handshake occurs when both are HIGH
- Transfer occurs on rising clock edge when VALID=1 and READY=1
- Both signals can be deasserted on next clock edge

#### Rule 4: Signal stability during handshake
- All address, data, and control signals must remain stable while VALID=1 and READY=0

### Example Timing Diagram
Clock | || || || || || |_| |
AWVALID ___________|---------------------------------------|
AWREADY ______________________|---------------------------|
AWADDR ===========__|
↑ Handshake occurs here

## Response Codes

### AXI4-Lite Response Types

| Code | Name | Description |
|------|------|-------------|
| `2'b00` | **OKAY** | Normal access success |
| `2'b10` | **SLVERR** | Slave error (operation failed) |
| `2'b11` | **DECERR** | Decode error (no slave at address) |

### Response Usage Guidelines

1. **OKAY (00)**
   - Successful completion of transaction
   - Default response for valid accesses

2. **SLVERR (10)**
   - Slave unable to process request
   - Data may be corrupted or unavailable
   - Example: Write to read-only register

3. **DECERR (11)**
   - No slave at specified address
   - Interconnect component generates this response
   - Example: Access to unmapped address space

### Full AXI4 Response Codes (Not in AXI4-Lite)
- `2'b01` - **EXOKAY**: Exclusive access okay (not supported in AXI4-Lite)

## Address Alignment

### Alignment Requirements
- All addresses must be **32-bit (4-byte) aligned**
- Lower 2 bits of address (`ADDR[1:0]`) must be `2'b00`
- Unaligned addresses are **protocol violations**

### Valid Address Examples
0x0000_0000 ✓ 32-bit aligned
0x0000_0004 ✓ 32-bit aligned
0x0000_0008 ✓ 32-bit aligned
0x0000_000C ✓ 32-bit aligned

### Invalid Address Examples
0x0000_0001 ✗ Byte 1 (unaligned)
0x0000_0002 ✗ Byte 2 (unaligned)
0x0000_0003 ✗ Byte 3 (unaligned)
0x0000_0005 ✗ Byte 1 (unaligned)

### Memory Mapping Example (4KB Slave)
Address Range Description
0x0000_0000 - 0x0000_0FFF 4KB Memory Space
0x0000_1000 - 0xFFFF_FFFF Unmapped (DECERR)

## Write Strobes

### Byte Lane Mapping
WSTRB[3] → WDATA[31:24] Byte 3 (MSB)
WSTRB[2] → WDATA[23:16] Byte 2
WSTRB[1] → WDATA[15:8] Byte 1
WSTRB[0] → WDATA[7:0] Byte 0 (LSB)


### Valid Strobe Patterns
| Strobe | Bytes Written | Description |
|--------|---------------|-------------|
| `4'b0001` | Byte 0 only | 8-bit write to LSB |
| `4'b0010` | Byte 1 only | 8-bit write to byte 1 |
| `4'b0100` | Byte 2 only | 8-bit write to byte 2 |
| `4'b1000` | Byte 3 only | 8-bit write to MSB |
| `4'b0011` | Bytes 0-1 | 16-bit write to lower half |
| `4'b1100` | Bytes 2-3 | 16-bit write to upper half |
| `4'b1111` | All bytes | Full 32-bit write |

### Invalid Strobe Patterns
- `4'b0000` - No bytes selected (protocol violation)
- Any pattern with non-consecutive bytes (e.g., `4'b0101`) may be valid depending on implementation

### Strobe Usage Examples
```verilog
// Write 0x12345678 to address 0x0000_0100
AWADDR  = 32'h0000_0100
WDATA   = 32'h12345678
WSTRB   = 4'b1111  // Write all 4 bytes

// Write only lower 16 bits (0x5678)
AWADDR  = 32'h0000_0100
WDATA   = 32'hxxxx5678  // Upper 16 bits don't care
WSTRB   = 4'b0011       // Write only bytes 0 and 1

// Write only MSB (0x12)
AWADDR  = 32'h0000_0100
WDATA   = 32'h12xxxxxx  // Lower 24 bits don't care
WSTRB   = 4'b1000       // Write only byte 3
```
Timing Requirements
Clock and Reset
Clock frequency: Typically 100-200MHz for Zynq devices

Reset polarity: Active low (ARESETn = 0 for reset)

Reset deassertion: Must be synchronized to clock

Signal Timing Rules
Rule 1: Setup and Hold Times
          ┌───┐   ┌───┐   ┌───┐
CLK    ___│   │___│   │___│   │___
          │ tsu│   │ th│
DATA  _____________________│=======│___________
          ↑ Setup  ↑ Hold
Rule 2: Minimum VALID Assertion
VALID must remain asserted for at least 1 clock cycle after handshake

Rule 3: Maximum Response Delay
Slave should respond within reasonable time (implementation specific)

Typically 1-16 clock cycles

Back-to-Back Transactions
Cycle:  0   1   2   3   4   5   6   7   8
AWVALID ____|-------|_______|-------|
AWREADY ________|-------|_______|-------|
                    ↑      ↑      ↑
                Txn1   Txn2   Txn3
Error Conditions
  Protocol Violations
  Category 1: Signal Timing Errors
    1. VALID deasserted before handshake
    ```systemverilog
    // Violation: VALID goes low before READY
    @(posedge ACLK) (VALID && !READY) |=> !VALID
    ```
    2. Address/data changed while VALID=1 and READY=0
    ```systemverilog
    // Violation: Signals not stable
    @(posedge ACLK) (VALID && !READY) |=> $stable(ADDR) && $stable(DATA)
    ```
  Category 2: Protocol Rule Violations
    1. Unaligned address
    ```systemverilog
    // Violation: ADDR[1:0] != 2'b00
    @(posedge ACLK) VALID |-> (ADDR[1:0] == 2'b00)
    Invalid write strobe
    ```
    2. Invalid write strobe
    ```systemverilog
    // Violation: WSTRB == 4'b0000
    @(posedge ACLK) WVALID |-> (WSTRB != 4'b0000)
    Invalid response code
    ```
    3. Invalid response code
    ```systemverilog
    // Violation: Response not 00, 10, or 11
    @(posedge ACLK) (BVALID || RVALID) |-> (RESP inside {2'b00, 2'b10, 2'b11})
    Category 3: Transaction Ordering Errors
    Write response before data handshake
    ```
  Category 3: Transaction Ordering Errors
    1. Write response before data handshake
    ```systemverilog
    // Violation: BVALID before W handshake
    !(AWVALID && AWREADY && WVALID && WREADY) throughout (##[0:$] BVALID)
    Read data before address handshake
    ```
    2. Read data before address handshake
    ```systemverilog
    // Violation: RVALID before AR handshake
    !(ARVALID && ARREADY) throughout (##[0:$] RVALID)
    Error Recovery
    Protocol violations should be detected by assertions
    ```

Error Recovery
  1. Protocol violations should be detected by assertions
  2. Design may ignore or flag violations
  3. Testbench should inject and detect error conditions
