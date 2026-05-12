#ifndef DECRYPT_H
#define DECRYPT_H
#include "encrypt.h"
void decrypt(uint8_t msg[N], const ciphertext_t *ct, const secret_key_t *sk);
#endif
