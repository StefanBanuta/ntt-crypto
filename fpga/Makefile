SIM = sim_fpga

SRC = \
	rtl/params.svh \
	rtl/parser.sv \
	rtl/encoder.sv \
	rtl/crypto_core.sv \
	rtl/top.sv \
	tb/tb_top.sv

all:
	iverilog -g2012 -Irtl -o $(SIM) $(SRC)

run: all
	vvp $(SIM) | tee fpga_results.txt

wave: run
	gtkwave wave.vcd

clean:
	rm -f $(SIM) *.vcd *.txt
