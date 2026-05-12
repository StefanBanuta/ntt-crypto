#ifndef ENCRYPT_H
#define ENCRYPT_H
#include "keygen.h"
typedef struct { poly_t c1; poly_t c2; } ciphertext_t;
void encrypt(ciphertext_t *ct, const public_key_t *pk, const uint8_t msg[N]);
#endif
