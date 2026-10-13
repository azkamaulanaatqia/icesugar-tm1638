DIR_BUILD = build
DIR_CONS  = constraints
DIR_SRC   = tcl

TOP_LEVEL  = top_tm1638_demo
TOP_MODULE = top_tm1638_demo
VERILOGS   = top_tm1638_demo.v tm1638.v
SRCS       = $(addprefix $(DIR_SRC)/,$(VERILOGS))

all:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	yosys -p "synth_ice40 -top $(TOP_MODULE) -json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json" $(SRCS)
	nextpnr-ice40 --up5k --package sg48 --json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json --pcf $(DIR_CONS)/$(TOP_LEVEL).pcf --asc $(DIR_BUILD)/$(TOP_LEVEL).asc
	icepack $(DIR_BUILD)/$(TOP_LEVEL).asc $(DIR_BUILD)/$(TOP_LEVEL).bin

flash:
	icesprog $(DIR_BUILD)/$(TOP_LEVEL).bin

clean:
	if exist $(DIR_BUILD) rmdir $(DIR_BUILD) /S /Q

.PHONY: all flash clean
