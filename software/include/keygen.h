#ifndef KEYGEN_H
#define KEYGEN_H
#include "poly.h"
typedef struct { poly_t s; } secret_key_t;
typedef struct { poly_t a; poly_t b; } public_key_t;
void keygen(public_key_t *pk, secret_key_t *sk);
#endif
