#include "ntt.h"
#include <string.h>

static int32_t psi_val, psi_inv_val, omega_val, omega_inv_val, n_inv_val;

static inline int32_t mod_q(int64_t x) {
    int32_t r = (int32_t)(x % Q);
    return r < 0 ? r + Q : r;
}

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

static int bit_reverse(int x, int bits) {
    int r = 0;
    for (int i = 0; i < bits; i++) { r = (r << 1) | (x & 1); x >>= 1; }
    return r;
}

void ntt_init(void) {
    psi_val       = power_mod(PRIMITIVE_ROOT, (Q - 1) / (2 * N), Q);
    psi_inv_val   = power_mod(psi_val, Q - 2, Q);
    omega_val     = mod_q((int64_t)psi_val * psi_val);
    omega_inv_val = power_mod(omega_val, Q - 2, Q);
    n_inv_val     = power_mod(N, Q - 2, Q);
}

static void ntt_cyclic(int32_t a[N], int32_t w_base) {
    for (int i = 0; i < N; i++) {
        int j = bit_reverse(i, LOGN);
        if (i < j) { int32_t t = a[i]; a[i] = a[j]; a[j] = t; }
    }
    for (int len = 2; len <= N; len <<= 1) {
        int32_t wl = power_mod(w_base, N / len, Q);
        for (int i = 0; i < N; i += len) {
            int32_t w = 1;
            for (int j = 0; j < len / 2; j++) {
                int32_t u = a[i + j];
                int32_t v = mod_q((int64_t)a[i + j + len / 2] * w);
                a[i + j]           = mod_q(u + v);
                a[i + j + len / 2] = mod_q(u - v);
                w = mod_q((int64_t)w * wl);
            }
        }
    }
}

void ntt_forward(int32_t a[N]) {
    int32_t pw = 1;
    for (int i = 0; i < N; i++) {
        a[i] = mod_q((int64_t)a[i] * pw);
        pw   = mod_q((int64_t)pw * psi_val);
    }
    ntt_cyclic(a, omega_val);
}

void ntt_inverse(int32_t a[N]) {
    ntt_cyclic(a, omega_inv_val);
    for (int i = 0; i < N; i++)
        a[i] = mod_q((int64_t)a[i] * n_inv_val);
    int32_t pw = 1;
    for (int i = 0; i < N; i++) {
        a[i] = mod_q((int64_t)a[i] * pw);
        pw   = mod_q((int64_t)pw * psi_inv_val);
    }
}

void ntt_pointwise_mul(int32_t result[N], const int32_t a[N], const int32_t b[N]) {
    for (int i = 0; i < N; i++)
        result[i] = mod_q((int64_t)a[i] * b[i]);
}
