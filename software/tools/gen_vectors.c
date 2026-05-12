#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ntt.h"
#include "poly.h"
#include "keygen.h"
#include "encrypt.h"
#include "decrypt.h"

/*
 * Genereaza vectori de test pentru SV testbenches.
 * Toti vectorii sunt scrisi in test_vectors/ ca fisiere hex.
 *
 * Format: o valoare pe linie, in hex (4 caractere, 13 biti)
 */

static void write_vec(const char *fname, const int32_t *v, int n) {
    FILE *f = fopen(fname, "w");
    if (!f) { perror(fname); exit(1); }
    for (int i = 0; i < n; i++) {
        fprintf(f, "%04x\n", v[i] & 0x1FFF);
    }
    fclose(f);
}

static void write_bits(const char *fname, const uint8_t *bits, int n) {
    FILE *f = fopen(fname, "w");
    if (!f) { perror(fname); exit(1); }
    for (int i = 0; i < n; i++) {
        fprintf(f, "%d\n", bits[i] & 1);
    }
    fclose(f);
}

int main(void) {
    int32_t a[N], b[N], r[N];
    poly_t pa, pb, pres;

    srand(42);  // seed fix pentru reproductibilitate
    ntt_init();

    printf("=== Generare vectori de test ===\n");

    /* ─────────────────────────────────────
     * Test 1: NTT forward
     * Input: polinom simplu [1, 2, 3, ..., 256]
     * Output: NTT(input)
     * ───────────────────────────────────── */
    for (int i = 0; i < N; i++) a[i] = i + 1;
    write_vec("test_vectors/ntt_fwd_input.hex", a, N);

    int32_t a_ntt[N];
    memcpy(a_ntt, a, sizeof(a));
    ntt_forward(a_ntt);
    write_vec("test_vectors/ntt_fwd_output.hex", a_ntt, N);
    printf("[OK] NTT forward: ntt_fwd_input.hex -> ntt_fwd_output.hex\n");

    /* ─────────────────────────────────────
     * Test 2: NTT inverse
     * Input: NTT(simplu)
     * Output: simplu (recuperat)
     * ───────────────────────────────────── */
    write_vec("test_vectors/ntt_inv_input.hex", a_ntt, N);
    int32_t a_back[N];
    memcpy(a_back, a_ntt, sizeof(a_back));
    ntt_inverse(a_back);
    write_vec("test_vectors/ntt_inv_output.hex", a_back, N);
    printf("[OK] NTT inverse: ntt_inv_input.hex -> ntt_inv_output.hex\n");

    /* ─────────────────────────────────────
     * Test 3: pointwise multiplication
     * Input: a_hat, b_hat (in domeniul NTT)
     * Output: a_hat * b_hat (componenta cu componenta)
     * ───────────────────────────────────── */
    for (int i = 0; i < N; i++) {
        a[i] = (i * 17 + 3) % Q;
        b[i] = (i * 31 + 7) % Q;
    }
    write_vec("test_vectors/pwm_input_a.hex", a, N);
    write_vec("test_vectors/pwm_input_b.hex", b, N);

    int32_t pwm_out[N];
    ntt_pointwise_mul(pwm_out, a, b);
    write_vec("test_vectors/pwm_output.hex", pwm_out, N);
    printf("[OK] Pointwise mul: pwm_input_{a,b}.hex -> pwm_output.hex\n");

    /* ─────────────────────────────────────
     * Test 4: poly_mul prin NTT
     * Input: doi polinoame in domeniul coeficientilor
     * Output: produsul lor in Z[X]/(X^N+1) mod Q
     * ───────────────────────────────────── */
    for (int i = 0; i < N; i++) {
        pa.coeffs[i] = (i * 13 + 5) % Q;
        pb.coeffs[i] = (i * 19 + 11) % Q;
    }
    write_vec("test_vectors/polymul_input_a.hex", pa.coeffs, N);
    write_vec("test_vectors/polymul_input_b.hex", pb.coeffs, N);

    poly_mul_ntt(&pres, &pa, &pb);
    write_vec("test_vectors/polymul_output.hex", pres.coeffs, N);
    printf("[OK] Poly mul: polymul_input_{a,b}.hex -> polymul_output.hex\n");

    /* ─────────────────────────────────────
     * Test 5: encrypt + decrypt cu mesaj fix
     * ───────────────────────────────────── */
    public_key_t pk;
    secret_key_t sk;
    ciphertext_t ct;
    uint8_t msg_in[N], msg_out[N];

    keygen(&pk, &sk);

    // Scrie cheile
    write_vec("test_vectors/key_a.hex",  pk.a.coeffs, N);
    write_vec("test_vectors/key_b.hex",  pk.b.coeffs, N);
    write_vec("test_vectors/key_s.hex",  sk.s.coeffs, N);

    // Mesaj de test: "HELLO" in 256 biti
    memset(msg_in, 0, N);
    const char *text = "HELLO";
    for (int c = 0; c < (int)strlen(text); c++)
        for (int b = 7; b >= 0; b--)
            msg_in[c*8 + (7-b)] = (text[c] >> b) & 1;
    write_bits("test_vectors/msg_input.bits", msg_in, N);

    encrypt(&ct, &pk, msg_in);
    write_vec("test_vectors/ct_c1.hex", ct.c1.coeffs, N);
    write_vec("test_vectors/ct_c2.hex", ct.c2.coeffs, N);

    decrypt(msg_out, &ct, &sk);
    write_bits("test_vectors/msg_output.bits", msg_out, N);
    printf("[OK] Encrypt/Decrypt: ct_{c1,c2}.hex, msg_{input,output}.bits\n");

    /* ─────────────────────────────────────
     * Constante (pentru SV)
     * ───────────────────────────────────── */
    FILE *f = fopen("test_vectors/constants.txt", "w");
    fprintf(f, "N=%d\n", N);
    fprintf(f, "Q=%d\n", Q);
    fprintf(f, "DELTA=%d\n", DELTA);
    fprintf(f, "PRIMITIVE_ROOT=%d\n", PRIMITIVE_ROOT);
    fclose(f);

    printf("\n=== Toti vectorii generati in test_vectors/ ===\n");
    return 0;
}
