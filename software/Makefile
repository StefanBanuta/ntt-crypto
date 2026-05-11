CC = gcc
CFLAGS = -std=c11 -O2 -Wall -Wextra
SIM = output/sim_c

all:
	mkdir -p output
	$(CC) $(CFLAGS) -o $(SIM) src/sim_c.c

run: all
	cd output && ./sim_c
	mv -f output/golden_results.csv output/c_results.csv 2>/dev/null || true

clean:
	rm -f output/sim_c output/*.csv output/*.hex
