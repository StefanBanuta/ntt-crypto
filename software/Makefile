CC = gcc
CFLAGS = -std=c11 -O2 -Wall -Wextra -Iinclude

# Standalone simulator/golden-vector generator
SIM_C = output/sim_c

# Full crypto sources
CRYPTO_SRC = \
	src/ntt.c \
	src/poly.c \
	src/keygen.c \
	src/encrypt.c \
	src/decrypt.c

.PHONY: all run clean crypto tools

all:
	mkdir -p output
	$(CC) $(CFLAGS) -o $(SIM_C) src/sim_c.c

run: all
	cd output && ../$(SIM_C)

# Optional: compile only crypto objects to verify syntax
crypto:
	mkdir -p output
	$(CC) $(CFLAGS) -c src/ntt.c -o output/ntt.o
	$(CC) $(CFLAGS) -c src/poly.c -o output/poly.o
	$(CC) $(CFLAGS) -c src/keygen.c -o output/keygen.o
	$(CC) $(CFLAGS) -c src/encrypt.c -o output/encrypt.o
	$(CC) $(CFLAGS) -c src/decrypt.c -o output/decrypt.o

clean:
	rm -rf output
