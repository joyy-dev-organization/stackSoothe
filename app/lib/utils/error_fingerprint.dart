import 'dart:convert';
import 'dart:typed_data';

/// Deterministic composite fingerprint for StackSoothe repeat-error recognition.
///
/// Combines:
/// 1. [errorSignatureHash] — SHA-256 of canonicalized error/stack trace (strips
///    ephemeral timestamps, hex memory addresses, and stack `:line:col` offsets
///    while preserving exception class, message text, symbols, and package paths).
/// 2. [sourceContextHash] — SHA-256 of line-ending-normalized source code context.
/// 3. [runtimeContextHash] — SHA-256 of normalized project + runtime context.
class ErrorFingerprint {
  final String canonicalError;
  final String canonicalSource;
  final String canonicalRuntime;
  final String errorSignatureHash;
  final String sourceContextHash;
  final String runtimeContextHash;
  final String compositeExactKey;

  const ErrorFingerprint._({
    required this.canonicalError,
    required this.canonicalSource,
    required this.canonicalRuntime,
    required this.errorSignatureHash,
    required this.sourceContextHash,
    required this.runtimeContextHash,
    required this.compositeExactKey,
  });

  factory ErrorFingerprint.compute({
    required String errorLog,
    required String codeContext,
    required String projectContext,
    required String runtimeContext,
  }) {
    final canonicalErr = canonicalizeErrorSignature(errorLog);
    final canonicalSrc = canonicalizeSourceContext(codeContext);
    final canonicalRun = canonicalizeRuntimeContext(
      projectContext: projectContext,
      runtimeContext: runtimeContext,
    );

    final errHash = sha256Hex(canonicalErr);
    final srcHash = sha256Hex(canonicalSrc);
    final runHash = sha256Hex(canonicalRun);

    return ErrorFingerprint._(
      canonicalError: canonicalErr,
      canonicalSource: canonicalSrc,
      canonicalRuntime: canonicalRun,
      errorSignatureHash: errHash,
      sourceContextHash: srcHash,
      runtimeContextHash: runHash,
      compositeExactKey: 'v1:$errHash:$srcHash:$runHash',
    );
  }

  /// Normalizes volatile runtime artifacts (timestamps, hex pointers, stack
  /// `:line:col` suffixes) while preserving exception types, messages, widget
  /// names, and package/file paths so distinct errors never collide.
  static String canonicalizeErrorSignature(String rawError) {
    final normalizedNewlines = rawError
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final lines = normalizedNewlines
        .split('\n')
        .map((line) {
          var s = line.trim();
          // Strip ISO-8601 / log timestamps
          s = s.replaceAll(
            RegExp(
              r'\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?\b',
            ),
            '',
          );
          // Strip raw hex memory addresses (e.g., 0x00007ff8a1b2c3d4)
          s = s.replaceAll(RegExp(r'\b0x[0-9a-fA-F]{6,16}\b'), '<addr>');
          // Normalize stack frame :line:col suffixes while keeping file/package path
          s = s.replaceAll(RegExp(r':\d+:\d+(?=\)|$|\s)'), ':<line>:<col>');
          // Collapse horizontal whitespace runs and trim
          s = s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
          return s;
        })
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.join('\n');
  }

  /// Preserves exact code tokens and line structure while normalizing CRLF and
  /// outer whitespace. Any edit to the code snippet alters [sourceContextHash].
  static String canonicalizeSourceContext(String rawCode) {
    return rawCode.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  /// Normalizes project and runtime environment identifiers. Any change in
  /// project or Flutter/Dart runtime context alters [runtimeContextHash].
  static String canonicalizeRuntimeContext({
    required String projectContext,
    required String runtimeContext,
  }) {
    final normProject = projectContext.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final normRuntime = runtimeContext.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return 'project=$normProject|runtime=$normRuntime';
  }
}

/// Pure-Dart FIPS 180-4 SHA-256 implementation (zero external package dependencies).
String sha256Hex(String input) {
  final data = utf8.encode(input);
  final bitLength = data.length * 8;

  // Padding: append 0x80, then 0x00 bytes until length ≡ 56 (mod 64), then 64-bit big-endian bit length
  final padLen = ((56 - (data.length + 1) % 64) + 64) % 64;
  final totalLen = data.length + 1 + padLen + 8;
  final padded = Uint8List(totalLen);
  padded.setRange(0, data.length, data);
  padded[data.length] = 0x80;

  final bd = ByteData.sublistView(padded);
  final highBits = (bitLength ~/ 0x100000000) & 0xFFFFFFFF;
  final lowBits = bitLength & 0xFFFFFFFF;
  bd.setUint32(totalLen - 8, highBits, Endian.big);
  bd.setUint32(totalLen - 4, lowBits, Endian.big);

  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;

  final w = Uint32List(64);

  for (var offset = 0; offset < totalLen; offset += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = bd.getUint32(offset + i * 4, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      final s0 =
          _rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 =
          _rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    var f = h5;
    var g = h6;
    var h = h7;

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
      final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final temp1 = (h + s1 + ch + _k256[i] + w[i]) & 0xFFFFFFFF;
      final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }

    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
    h5 = (h5 + f) & 0xFFFFFFFF;
    h6 = (h6 + g) & 0xFFFFFFFF;
    h7 = (h7 + h) & 0xFFFFFFFF;
  }

  final out = StringBuffer();
  for (final word in [h0, h1, h2, h3, h4, h5, h6, h7]) {
    out.write(word.toRadixString(16).padLeft(8, '0'));
  }
  return out.toString();
}

int _rotr32(int x, int n) => ((x >>> n) | ((x << (32 - n)) & 0xFFFFFFFF));

const List<int> _k256 = <int>[
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];
