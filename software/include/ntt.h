#ifndef NTT_H
#define NTT_H
#include "params.h"
void ntt_init(void);
void ntt_forward(int32_t a[N]);
void ntt_inverse(int32_t a[N]);
void ntt_pointwise_mul(int32_t result[N], const int32_t a[N], const int32_t b[N]);
#endif
