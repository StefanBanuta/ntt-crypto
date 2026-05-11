.PHONY: all run clean software fpga

all: software fpga

software:
	$(MAKE) -C software

fpga:
	$(MAKE) -C fpga

run:
	$(MAKE) -C software run
	$(MAKE) -C fpga run

clean:
	$(MAKE) -C software clean
	$(MAKE) -C fpga clean
