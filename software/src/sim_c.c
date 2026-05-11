#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define MAX_PAYLOAD 32
#define MAX_FRAME   64
#define N_TARGET    256
#define Q_TARGET    7681
#define SOF         0xAA
#define EOF_BYTE    0x55

typedef struct {
    uint8_t type;
    const char *name;
    uint8_t payload[MAX_PAYLOAD];
    size_t payload_len;
} iot_packet_t;

typedef struct {
    uint8_t bytes[MAX_FRAME];
    size_t len;
} serial_frame_t;

static uint8_t checksum8(const uint8_t *data, size_t len) {
    uint32_t s = 0;
    for (size_t i = 0; i < len; i++) s += data[i];
    return (uint8_t)(s & 0xFFu);
}

static int make_serial_frame(const iot_packet_t *p, serial_frame_t *f) {
    if (p->payload_len > MAX_PAYLOAD) return -1;
    size_t idx = 0;
    f->bytes[idx++] = SOF;
    f->bytes[idx++] = (uint8_t)p->payload_len;
    f->bytes[idx++] = p->type;
    memcpy(&f->bytes[idx], p->payload, p->payload_len);
    idx += p->payload_len;
    f->bytes[idx++] = checksum8(&f->bytes[1], 2 + p->payload_len);
    f->bytes[idx++] = EOF_BYTE;
    f->len = idx;
    return 0;
}

static void hex_print(FILE *f, const uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        fprintf(f, "%02X", data[i]);
        if (i + 1 < len) fprintf(f, " ");
    }
}

static void bytes_to_bits_256(const uint8_t *bytes, size_t nbytes, uint8_t bits[N_TARGET]) {
    memset(bits, 0, N_TARGET);
    if (nbytes > N_TARGET / 8) nbytes = N_TARGET / 8;
    for (size_t i = 0; i < nbytes; i++) {
        for (int b = 0; b < 8; b++) bits[i * 8 + b] = (bytes[i] >> (7 - b)) & 1u;
    }
}

static void bits_to_bytes_256(const uint8_t bits[N_TARGET], uint8_t *bytes, size_t nbytes) {
    memset(bytes, 0, nbytes);
    if (nbytes > N_TARGET / 8) nbytes = N_TARGET / 8;
    for (size_t i = 0; i < nbytes; i++) {
        for (int b = 0; b < 8; b++) bytes[i] |= (uint8_t)(bits[i * 8 + b] << (7 - b));
    }
}

static void mock_encrypt_decrypt(const uint8_t in[N_TARGET], uint8_t out[N_TARGET], uint16_t c1[8], uint16_t c2[8]) {
    for (int i = 0; i < N_TARGET; i++) out[i] = in[i];
    for (int i = 0; i < 8; i++) {
        c1[i] = (uint16_t)((1000 + 17 * i + in[i]) % Q_TARGET);
        c2[i] = (uint16_t)((2000 + 31 * i + in[i]) % Q_TARGET);
    }
}

static void load_samples(iot_packet_t p[6]) {
    memset(p, 0, 6 * sizeof(iot_packet_t));
    p[0].type = 1; p[0].name = "Temperatura"; float t = 23.5f; memcpy(p[0].payload, &t, 4); p[0].payload_len = 4;
    p[1].type = 2; p[1].name = "Umiditate"; float h = 65.2f; memcpy(p[1].payload, &h, 4); p[1].payload_len = 4;
    p[2].type = 3; p[2].name = "Comanda_LED"; const char *cmd = "LED_ON"; memcpy(p[2].payload, cmd, strlen(cmd)); p[2].payload_len = strlen(cmd);
    p[3].type = 4; p[3].name = "Device_ID"; uint32_t id = 0xDEADBEEFu; memcpy(p[3].payload, &id, 4); p[3].payload_len = 4;
    p[4].type = 5; p[4].name = "ADC_4CH"; uint16_t adc[4] = {1023,2048,512,4095}; memcpy(p[4].payload, adc, 8); p[4].payload_len = 8;
    p[5].type = 6; p[5].name = "Text"; const char *msg = "Hello FPGA!"; memcpy(p[5].payload, msg, strlen(msg)); p[5].payload_len = strlen(msg);
}

int main(void) {
    iot_packet_t packets[6]; load_samples(packets);
    FILE *csv = fopen("golden_results.csv", "w");
    FILE *hex = fopen("uart_frames.hex", "w");
    FILE *bitsf = fopen("message_bits.hex", "w");
    if (!csv || !hex || !bitsf) return 1;
    fprintf(csv, "test_name,type,payload_len,frame_hex,original_hex,c1_preview,c2_preview,decrypted_hex,pass\n");
    for (int i = 0; i < 6; i++) {
        serial_frame_t frame = {0}; uint8_t bits[N_TARGET], out_bits[N_TARGET], decrypted[MAX_PAYLOAD]; uint16_t c1[8], c2[8];
        make_serial_frame(&packets[i], &frame);
        bytes_to_bits_256(packets[i].payload, packets[i].payload_len, bits);
        mock_encrypt_decrypt(bits, out_bits, c1, c2);
        bits_to_bytes_256(out_bits, decrypted, packets[i].payload_len);
        int pass = memcmp(packets[i].payload, decrypted, packets[i].payload_len) == 0;
        hex_print(hex, frame.bytes, frame.len); fprintf(hex, "\n");
        for (int j = 0; j < 32; j++) { fprintf(bitsf, "%u", bits[j]); if (j < 31) fprintf(bitsf, " "); } fprintf(bitsf, "\n");
        fprintf(csv, "%s,%u,%zu,\"", packets[i].name, packets[i].type, packets[i].payload_len); hex_print(csv, frame.bytes, frame.len);
        fprintf(csv, "\",\""); hex_print(csv, packets[i].payload, packets[i].payload_len);
        fprintf(csv, "\",\""); for (int j = 0; j < 8; j++) { fprintf(csv, "%u%s", c1[j], j == 7 ? "" : " "); }
        fprintf(csv, "\",\""); for (int j = 0; j < 8; j++) { fprintf(csv, "%u%s", c2[j], j == 7 ? "" : " "); }
        fprintf(csv, "\",\""); hex_print(csv, decrypted, packets[i].payload_len);
        fprintf(csv, "\",%s\n", pass ? "PASS" : "FAIL");
    }
    fclose(csv); fclose(hex); fclose(bitsf);
    printf("Generated: golden_results.csv, uart_frames.hex, message_bits.hex\n");
    return 0;
}
