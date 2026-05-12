#include "decrypt.h"
#include "ntt.h"

void decrypt(uint8_t msg[N], const ciphertext_t *ct, const secret_key_t *sk) {
    poly_t c1s, result;
    poly_mul_ntt(&c1s, &ct->c1, &sk->s);
    poly_sub(&result, &ct->c2, &c1s);
    for (int i = 0; i < N; i++) {
        int32_t v = result.coeffs[i];
        msg[i] = (v > Q / 4 && v < 3 * Q / 4) ? 1 : 0;
    }
}
