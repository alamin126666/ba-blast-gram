cmake_minimum_required(VERSION 3.18)

# BA BLAST GRAM native API key store.
# Built by the Android NDK as libtelegram_keys.so and loaded from Dart
# via dart:ffi (see lib/config/telegram_keys.dart). The library holds the
# owner's obfuscated api_id/api_hash and decrypts them only at runtime.
project(telegram_keys)

add_library(telegram_keys SHARED telegram_keys.cpp)
