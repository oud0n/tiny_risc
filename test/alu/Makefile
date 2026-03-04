# ====================================================================
# Makefile for RISC-V RTL Simulation
# This Makefile automates the compilation and simulation process
# for various testbenches using Icarus Verilog.
# ====================================================================

# --- Simulation Tools and Options ---
SIMULATOR = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Default testbench if not specified
TESTBENCH ?= tb_alu
EXECUTABLE = $(TESTBENCH).vvp

# --- Directories ---
SOURCE_DIR = ../../src
TESTBENCH_DIR = .

# --- Source Files ---
SOURCE_FILES = $(wildcard $(SOURCE_DIR)/*.sv)
TESTBENCH_FILES = $(wildcard $(TESTBENCH_DIR)/*.sv)

# --- Compiler Options ---
INCLUDE_DIR = -I$(SOURCE_DIR)
COMPILER_OPTS = -g2012 -Wall

# --- Main Targets ---
.PHONY: all simulate compile clean

# Default target: compile and simulate
all: simulate

# Compile the design for the specified testbench
compile:
	@echo "Compiling $(TESTBENCH) with Icarus Verilog..."
	$(SIMULATOR) -o $(EXECUTABLE) $(COMPILER_OPTS) $(INCLUDE_DIR) $(SOURCE_FILES) $(TESTBENCH_FILES)

# Run the simulation
simulate: compile
	@echo "Running simulation for $(TESTBENCH)..."
	$(VVP) $(EXECUTABLE)

# View the waveform using GTKWave
view_wave:
	@echo "Viewing waveform with GTKWave..."
	$(GTKWAVE) $(TESTBENCH).vcd

# Clean up generated files
clean:
	@echo "Cleaning up generated files..."
	rm -f $(EXECUTABLE) \*.vcd