#include "poly.h"
#include "ntt.h"
#include <stdlib.h>
#include <string.h>

static inline int32_t mod_q(int64_t x) {
    int32_t r = (int32_t)(x % Q);
    return r < 0 ? r + Q : r;
}

void poly_add(poly_t *r, const poly_t *a, const poly_t *b) {
    for (int i = 0; i < N; i++)
        r->coeffs[i] = mod_q((int64_t)a->coeffs[i] + b->coeffs[i]);
}

void poly_sub(poly_t *r, const poly_t *a, const poly_t *b) {
    for (int i = 0; i < N; i++)
        r->coeffs[i] = mod_q((int64_t)a->coeffs[i] - b->coeffs[i]);
}

void poly_mul_ntt(poly_t *r, const poly_t *a, const poly_t *b) {
    int32_t ta[N], tb[N];
    memcpy(ta, a->coeffs, sizeof(ta));
    memcpy(tb, b->coeffs, sizeof(tb));
    ntt_forward(ta);
    ntt_forward(tb);
    ntt_pointwise_mul(r->coeffs, ta, tb);
    ntt_inverse(r->coeffs);
}

void poly_random_uniform(poly_t *p) {
    for (int i = 0; i < N; i++) p->coeffs[i] = rand() % Q;
}

void poly_random_error(poly_t *p) {
    for (int i = 0; i < N; i++)
        p->coeffs[i] = mod_q((rand() % (2 * ERROR_BOUND + 1)) - ERROR_BOUND);
}
