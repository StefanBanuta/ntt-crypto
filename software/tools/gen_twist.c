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

int main(void) {
    int32_t psi = power_mod(PRIMITIVE_ROOT, (Q - 1) / (2 * N), Q);
    int32_t a[N], a_twisted[N];

    /* Input: 1, 2, 3, ..., 256 */
    for (int i = 0; i < N; i++) a[i] = i + 1;

    /* Twist: a[i] = a[i] * psi^i mod q */
    int32_t pw = 1;
    for (int i = 0; i < N; i++) {
        a_twisted[i] = (int32_t)(((int64_t)a[i] * pw) % Q);
        pw = (int32_t)(((int64_t)pw * psi) % Q);
    }

    /* Scrie input si output */
    FILE *f1 = fopen("test_vectors/twist_input.hex", "w");
    FILE *f2 = fopen("test_vectors/twist_output.hex", "w");
    for (int i = 0; i < N; i++) {
        fprintf(f1, "%04x\n", a[i] & 0x1FFF);
        fprintf(f2, "%04x\n", a_twisted[i] & 0x1FFF);
    }
    fclose(f1);
    fclose(f2);

    printf("[OK] twist_input.hex + twist_output.hex\n");
    return 0;
}
