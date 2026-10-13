# Initialize the Yosys-Tcl environment
yosys -import


# 1. Define Tcl variables
set top_level "top_blinky"
set src_files [list "top_blinky.v"]
#set target_library "sky130_fd_sc_hd__tt_025C_1v80.lib"

# 2. Read input RTL files using a Tcl loop
foreach file $src_files {
    puts "Parsing source file: $file"
    read_verilog rtl/$file
}

# 3. Design Elaborate & Check
hierarchy -top $top_level
procs; # Executes Yosys RTL proc pass (aliased from 'proc')

# 4. Synthesize and optimize
synth -top $top_level

# 5. Technology Mapping (Mapping to ASIC Gate Library)
# if {[file exists $target_library]} {
#     puts "Mapping design to target technology cell library..."
#     abc -liberty $target_library
#     clean
# } else {
#     puts "Warning: target library $target_library not found. Defaulting to generic cells."
# }

# 6. Print synthesis stats and save the gate-level netlist
stat
write_verilog "build/${top_level}_netlist.v"
write_verilog -noattr "build/${top_level}_netlist_noattr.v"
write_json  "build/${top_level}_netlist.json"

# Read Verilog source file
#yosys read_verilog rtl/$src_files

# Elaborate design hierarchy for a specific top module
#yosys hierarchy -check -top $top_level

# Run generic synthesis script
#yosys synth -top $top_level

# Write out the resulting gate-level Verilog netlist
#yosys write_verilog -noattr synth_output.v
