#include <stdio.h>
#include <stdint.h>
#include "params.h"
#include "ntt.h"

int main(void) {
    ntt_init();

    int32_t psi     = 0;
    int32_t psi_inv = 0;
    int32_t omega   = 0;
    int32_t n_inv   = 0;

    /* Recalculeaza valorile */
    int64_t base, result, mod;
    mod = Q;

    /* power_mod local */
    #define PM(b,e,m) ({ \
        int64_t _r=1, _b=((b)%(m)+(m))%(m); \
        int32_t _e=(e); \
        while(_e>0){if(_e&1)_r=_r*_b%(m);_b=_b*_b%(m);_e>>=1;} \
        (int32_t)_r; })

    psi     = PM(PRIMITIVE_ROOT, (Q-1)/(2*N), Q);
    psi_inv = PM(psi, Q-2, Q);
    omega   = (int32_t)(((int64_t)psi * psi) % Q);
    n_inv   = PM(N, Q-2, Q);

    printf("/* Auto-generated from gen_tables.c */\n");
    printf("/* N=%d Q=%d PRIMITIVE_ROOT=%d */\n\n", N, Q, PRIMITIVE_ROOT);
    printf("/* psi     = %d */\n", psi);
    printf("/* psi_inv = %d */\n", psi_inv);
    printf("/* omega   = %d */\n", omega);
    printf("/* n_inv   = %d */\n\n", n_inv);

    /* Twiddle factors psi^i mod q */
    printf("/* PSI powers: psi_table[i] = psi^i mod q */\n");
    printf("parameter logic [12:0] PSI_TABLE [0:255] = '{\n");
    int32_t pw = 1;
    for (int i = 0; i < N; i++) {
        printf("    13'd%d", pw);
        if (i < N-1) printf(",");
        if ((i+1) % 8 == 0) printf("  /* [%d..%d] */\n", i-7, i);
        pw = (int32_t)(((int64_t)pw * psi) % Q);
    }
    printf("};\n\n");

    /* PSI inverse */
    printf("/* PSI_INV powers: psi_inv_table[i] = psi^(-i) mod q */\n");
    printf("parameter logic [12:0] PSI_INV_TABLE [0:255] = '{\n");
    pw = 1;
    for (int i = 0; i < N; i++) {
        printf("    13'd%d", pw);
        if (i < N-1) printf(",");
        if ((i+1) % 8 == 0) printf("  /* [%d..%d] */\n", i-7, i);
        pw = (int32_t)(((int64_t)pw * psi_inv) % Q);
    }
    printf("};\n\n");

    /* Omega bit-reversed pentru NTT cyclic */
    int bit_rev[N];
    for (int i = 0; i < N; i++) {
        int x = i, r = 0;
        for (int b = 0; b < LOGN; b++) { r=(r<<1)|(x&1); x>>=1; }
        bit_rev[i] = r;
    }

    printf("/* OMEGA powers bit-reversed: omega_table[i] = omega^br(i) mod q */\n");
    printf("parameter logic [12:0] OMEGA_TABLE [0:255] = '{\n");
    for (int i = 0; i < N; i++) {
        int32_t val = PM(omega, bit_rev[i], Q);
        printf("    13'd%d", val);
        if (i < N-1) printf(",");
        if ((i+1) % 8 == 0) printf("  /* [%d..%d] */\n", i-7, i);
    }
    printf("};\n\n");

    printf("/* OMEGA_INV powers bit-reversed */\n");
    int32_t omega_inv = PM(omega, Q-2, Q);
    printf("parameter logic [12:0] OMEGA_INV_TABLE [0:255] = '{\n");
    for (int i = 0; i < N; i++) {
        int32_t val = PM(omega_inv, bit_rev[i], Q);
        printf("    13'd%d", val);
        if (i < N-1) printf(",");
        if ((i+1) % 8 == 0) printf("  /* [%d..%d] */\n", i-7, i);
    }
    printf("};\n");

    printf("\n/* Constante */\n");
    printf("parameter logic [12:0] N_INV = 13'd%d;\n", n_inv);
    printf("parameter logic [12:0] PSI   = 13'd%d;\n", psi);
    printf("parameter logic [12:0] PSI_INV = 13'd%d;\n", psi_inv);
    printf("parameter logic [12:0] DELTA_VAL = 13'd%d;\n", DELTA);

    return 0;
}
