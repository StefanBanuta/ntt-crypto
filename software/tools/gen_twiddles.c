/*
 * Genereaza tabelele psi^i si psi_inv^i in format SV
 * pentru a fi incluse in twiddle_rom.sv
 */
#include <stdio.h>
#include <stdint.h>
#include "params.h"

static int32_t power_mod(int64_t base, int32_t exp, int32_t mod) {
    int64_t result = 1;
    base = ((base % mod) + mod) % mod;
    while (exp > 0) {
        if (exp & 1) result = (result * base) % mod;
        base = (base * base) % mod;
        exp >>= 1;
    }
    return (int32_t)result;
}

static int32_t inv_mod(int32_t a) {
    return power_mod(a, Q - 2, Q);
}

int main(void) {
    int32_t psi     = power_mod(PRIMITIVE_ROOT, (Q - 1) / (2 * N), Q);
    int32_t psi_inv = inv_mod(psi);

    /* Tabel psi^i */
    FILE *f1 = fopen("test_vectors/psi_table.hex", "w");
    int32_t pw = 1;
    for (int i = 0; i < N; i++) {
        fprintf(f1, "%04x\n", pw & 0x1FFF);
        pw = (int32_t)(((int64_t)pw * psi) % Q);
    }
    fclose(f1);

    /* Tabel psi_inv^i */
    FILE *f2 = fopen("test_vectors/psi_inv_table.hex", "w");
    pw = 1;
    for (int i = 0; i < N; i++) {
        fprintf(f2, "%04x\n", pw & 0x1FFF);
        pw = (int32_t)(((int64_t)pw * psi_inv) % Q);
    }
    fclose(f2);

    printf("psi=%d psi_inv=%d\n", psi, psi_inv);
    printf("[OK] test_vectors/psi_table.hex\n");
    printf("[OK] test_vectors/psi_inv_table.hex\n");
    return 0;
}
