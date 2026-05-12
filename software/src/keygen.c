#include "keygen.h"
#include "ntt.h"

void keygen(public_key_t *pk, secret_key_t *sk) {
    poly_t e;
    poly_random_uniform(&pk->a);
    poly_random_error(&sk->s);
    poly_random_error(&e);
    poly_mul_ntt(&pk->b, &pk->a, &sk->s);
    poly_add(&pk->b, &pk->b, &e);
}
