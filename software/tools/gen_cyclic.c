#include <stdio.h>
#include <stdint.h>
#include <string.h>
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

static int32_t mod_q(int64_t x) {
    int32_t r = (int32_t)(x % Q);
    return r < 0 ? r + Q : r;
}

static int bit_reverse(int x, int bits) {
    int r = 0;
    for (int i = 0; i < bits; i++) { r = (r<<1)|(x&1); x>>=1; }
    return r;
}

int main(void) {
    int32_t psi   = power_mod(PRIMITIVE_ROOT, (Q-1)/(2*N), Q);
    int32_t omega = mod_q((int64_t)psi * psi);

    int32_t a[N], a_in[N];

    /* Input: numere simple 1..256 */
    for (int i = 0; i < N; i++) a[i] = i + 1;
    memcpy(a_in, a, sizeof(a));

    /* Salveaza input */
    FILE *f1 = fopen("test_vectors/cyclic_input.hex", "w");
    for (int i = 0; i < N; i++) fprintf(f1, "%04x\n", a_in[i] & 0x1FFF);
    fclose(f1);

    /* NTT cyclic forward (textbook) */
    /* 1. Bit-reversal */
    for (int i = 0; i < N; i++) {
        int j = bit_reverse(i, LOGN);
        if (i < j) { int32_t t = a[i]; a[i] = a[j]; a[j] = t; }
    }

    /* 2. Butterfly stages */
    for (int len = 2; len <= N; len <<= 1) {
        int32_t w_len = power_mod(omega, N / len, Q);
        for (int i = 0; i < N; i += len) {
            int32_t w = 1;
            for (int j = 0; j < len / 2; j++) {
                int32_t u = a[i + j];
                int32_t v = mod_q((int64_t)a[i + j + len/2] * w);
                a[i + j]         = mod_q(u + v);
                a[i + j + len/2] = mod_q(u - v + Q);
                w = mod_q((int64_t)w * w_len);
            }
        }
    }

    /* Salveaza output */
    FILE *f2 = fopen("test_vectors/cyclic_output.hex", "w");
    for (int i = 0; i < N; i++) fprintf(f2, "%04x\n", a[i] & 0x1FFF);
    fclose(f2);

    /* Salveaza si tabelul omega^k pentru k = 0..N-1 */
    /* Pentru un NTT cyclic, twiddle factors sunt puterile lui omega */
    /* dar in SV vom genera w_len-urile pentru fiecare etapa */
    FILE *f3 = fopen("test_vectors/omega_table.hex", "w");
    int32_t pw = 1;
    for (int i = 0; i < N; i++) {
        fprintf(f3, "%04x\n", pw & 0x1FFF);
        pw = mod_q((int64_t)pw * omega);
    }
    fclose(f3);

    printf("psi=%d omega=%d\n", psi, omega);
    printf("[OK] cyclic_input.hex, cyclic_output.hex, omega_table.hex\n");
    printf("Input[0..5]:  ");
    for (int i = 0; i < 6; i++) printf("%04x ", a_in[i] & 0x1FFF);
    printf("\nOutput[0..5]: ");
    for (int i = 0; i < 6; i++) printf("%04x ", a[i] & 0x1FFF);
    printf("\n");

    return 0;
}
