import 'dart:convert';
import 'package:crypto/crypto.dart';

String hashPassword(String plain) {
  final bytes = utf8.encode(plain);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

bool verifyPassword(String plain, String hash) {
  return hashPassword(plain) == hash;
}
