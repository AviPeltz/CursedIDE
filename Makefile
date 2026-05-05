IVERILOG ?= iverilog
VVP      ?= vvp
BUILD    := build

SRC := src/agent_fsm.v src/agent_pool.v src/file_buffer.v \
       src/prompt_channel.v src/cursed_ide_top.v

.PHONY: all tb_agent tb_top clean

all: tb_agent tb_top

$(BUILD):
	mkdir -p $(BUILD)

tb_agent: $(BUILD)
	$(IVERILOG) -g2012 -o $(BUILD)/tb_agent.vvp \
		src/agent_fsm.v tb/tb_agent_fsm.v
	$(VVP) $(BUILD)/tb_agent.vvp

tb_top: $(BUILD)
	$(IVERILOG) -g2012 -o $(BUILD)/tb_top.vvp \
		$(SRC) tb/tb_cursed_ide_top.v
	$(VVP) $(BUILD)/tb_top.vvp

clean:
	rm -rf $(BUILD) *.vcd *.fst
