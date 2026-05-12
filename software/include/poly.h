#ifndef POLY_H
#define POLY_H
#include "params.h"
typedef struct { int32_t coeffs[N]; } poly_t;
void poly_add(poly_t *r, const poly_t *a, const poly_t *b);
void poly_sub(poly_t *r, const poly_t *a, const poly_t *b);
void poly_mul_ntt(poly_t *r, const poly_t *a, const poly_t *b);
void poly_random_uniform(poly_t *p);
void poly_random_error(poly_t *p);
#endif
