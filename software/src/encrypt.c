#include "encrypt.h"
#include "ntt.h"

void encrypt(ciphertext_t *ct, const public_key_t *pk, const uint8_t msg[N]) {
    poly_t r, e1, e2, m, ar, br;
    poly_random_error(&r);
    poly_random_error(&e1);
    poly_random_error(&e2);
    for (int i = 0; i < N; i++)
        m.coeffs[i] = (msg[i] & 1) ? DELTA : 0;
    poly_mul_ntt(&ar, &pk->a, &r);
    poly_add(&ct->c1, &ar, &e1);
    poly_mul_ntt(&br, &pk->b, &r);
    poly_add(&ct->c2, &br, &e2);
    poly_add(&ct->c2, &ct->c2, &m);
}
