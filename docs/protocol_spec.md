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
