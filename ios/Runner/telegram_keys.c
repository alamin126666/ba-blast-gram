/* telegram_keys.c — BA BLAST GRAM native API key store.
 *
 * This file holds the OWNER'S Telegram api_id / api_hash, obfuscated with
 * a repeating XOR key and decrypted only at runtime, in native code.
 *
 * Rules:
 * - These keys belong to the APP OWNER only. End users never see them,
 *   never enter them, and never need their own — they log in with
 *   phone + OTP.
 * - The values below are PLACEHOLDERS (all zeros). A build with the
 *   placeholders fails loudly at login with:
 *       "API keys not configured — owner must add api_id/api_hash"
 * - The owner supplies api_id/api_hash ONCE (via the secure flow, never
 *   in plain chat). The builder then runs:
 *       dart scripts/make_keys.dart <api_id> <api_hash>
 *   and replaces the OWNER PLACEHOLDER block below with the output.
 * - The same content lives in two files — keep them in sync:
 *       android/app/src/main/cpp/telegram_keys.cpp  (NDK, CMake)
 *       ios/Runner/telegram_keys.c                  (Xcode, Runner target)
 * - This is OBFUSCATION, not real encryption: anyone who can read the
 *   binary and this key can recover the values. That is the normal
 *   trade-off for every Telegram client (official clients embed theirs
 *   too). The point is that the keys are never in plain text in Dart
 *   code, pubspec, strings.xml, or the repo, and are decrypted only
 *   at runtime in native code.
 */

#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* XOR key. Must match scripts/make_keys.dart (kXorKey). */
static const char kXorKey[] = "BA-BLAST-GRAM-KEY-v1";

/* OWNER_PLACEHOLDER_BEGIN — replace with scripts/make_keys.dart output. */
static const uint8_t kApiIdObfuscated[8] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
static const uint8_t kApiHashObfuscated[] = {0x00};
static const uint32_t kApiHashLength = 0;
/* OWNER_PLACEHOLDER_END */

static int is_all_zero(const uint8_t *bytes, uint32_t length) {
    uint32_t i;
    for (i = 0; i < length; i++) {
        if (bytes[i] != 0) return 0;
    }
    return 1;
}

static size_t xor_key_length(void) {
    return strlen(kXorKey);
}

/* Returns the owner's api_id, or 0 when the placeholders are still in
 * place (not configured). */
int64_t blastgram_api_id(void) {
    uint8_t decoded[8];
    uint64_t value = 0;
    int i;
    if (is_all_zero(kApiIdObfuscated, 8)) return 0;
    for (i = 0; i < 8; i++) {
        decoded[i] = (uint8_t)(kApiIdObfuscated[i] ^
                               (uint8_t)kXorKey[i % (int)xor_key_length()]);
    }
    for (i = 7; i >= 0; i--) {
        value = (value << 8) | decoded[i];
    }
    return (int64_t)value;
}

/* Returns the owner's api_hash, or "" when the placeholders are still
 * in place (not configured). The returned string is owned by this
 * library and stays valid for the lifetime of the process. */
const char *blastgram_api_hash(void) {
    static char buffer[129];
    uint32_t i;
    if (kApiHashLength == 0 || is_all_zero(kApiHashObfuscated, 1)) {
        buffer[0] = '\0';
        return buffer;
    }
    if (kApiHashLength > 128) {
        buffer[0] = '\0';
        return buffer;
    }
    for (i = 0; i < kApiHashLength; i++) {
        buffer[i] = (char)(kApiHashObfuscated[i] ^
                           (uint8_t)kXorKey[i % (int)xor_key_length()]);
    }
    buffer[kApiHashLength] = '\0';
    return buffer;
}

#ifdef __cplusplus
}
#endif
