import 'dart:convert';
import '../models/token.dart';

/// Import/export tokens in various formats.
class ImportExport {
  /// Export tokens to Citadel JSON format.
  static String exportToJson(List<Token> tokens) {
    final data = {
      'version': 1,
      'app': 'citadel_auth',
      'exported_at': DateTime.now().toIso8601String(),
      'tokens': tokens.map((t) => {
            'issuer': t.issuer,
            'account': t.account,
            'secret': t.secret,
            'type': t.type.name,
            'algorithm': t.algorithm.name,
            'digits': t.digits,
            'period': t.period,
            'counter': t.counter,
            'tags': t.tags,
          }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Import tokens from JSON (supports Citadel, Aegis, 2FAS, Ente formats).
  static List<Token> importFromJson(String content) {
    // Try as list of otpauth URIs first (non-JSON)
    if (content.trimLeft().startsWith('otpauth://')) {
      return _importUriList(content);
    }

    final decoded = json.decode(content);

    if (decoded is Map) {
      final data = Map<String, dynamic>.from(decoded);
      // Citadel format
      if (data['app'] == 'citadel_auth') {
        return _importCitadel(data);
      }
      // Aegis format
      if (data.containsKey('db') && data['db'] is Map) {
        return _importAegis(data);
      }
      // 2FAS format
      if (data.containsKey('services') || data.containsKey('servicesEncrypted')) {
        return _import2FAS(data);
      }
      // Ente Auth format
      if (data.containsKey('items')) {
        return _importEnte(data);
      }
      // Generic: try tokens array
      if (data.containsKey('tokens')) {
        return _importCitadel(data);
      }
    }

    throw const FormatException('Unrecognized import format');
  }

  static List<Token> _importCitadel(Map<String, dynamic> data) {
    final tokens = data['tokens'] as List;
    return tokens.map((t) {
      final m = t as Map<String, dynamic>;
      return Token(
        issuer: m['issuer'] as String? ?? '',
        account: m['account'] as String? ?? '',
        secret: m['secret'] as String,
        type: OtpType.values.byName(m['type'] as String? ?? 'totp'),
        algorithm: Algorithm.values.byName(m['algorithm'] as String? ?? 'sha1'),
        digits: m['digits'] as int? ?? 6,
        period: m['period'] as int? ?? 30,
        counter: m['counter'] as int? ?? 0,
        tags: (m['tags'] as List?)?.cast<String>() ?? const [],
      );
    }).toList();
  }

  static List<Token> _importAegis(Map<String, dynamic> data) {
    final db = data['db'] as Map<String, dynamic>;
    final entries = db['entries'] as List;
    return entries.map((e) {
      final entry = e as Map<String, dynamic>;
      final info = entry['info'] as Map<String, dynamic>;
      return Token(
        issuer: entry['issuer'] as String? ?? '',
        account: entry['name'] as String? ?? '',
        secret: info['secret'] as String,
        type: (entry['type'] as String?) == 'hotp' ? OtpType.hotp : OtpType.totp,
        algorithm: _parseAlgo(info['algo'] as String?),
        digits: info['digits'] as int? ?? 6,
        period: info['period'] as int? ?? 30,
        counter: info['counter'] as int? ?? 0,
      );
    }).toList();
  }

  static List<Token> _import2FAS(Map<String, dynamic> data) {
    final services = data['services'] as List? ?? [];
    return services.map((s) {
      final svc = s as Map<String, dynamic>;
      final otp = svc['otp'] as Map<String, dynamic>;
      return Token(
        issuer: svc['name'] as String? ?? '',
        account: otp['account'] as String? ?? svc['name'] as String? ?? '',
        secret: otp['secret'] as String? ?? svc['secret'] as String,
        type: (otp['tokenType'] as String?) == 'HOTP' ? OtpType.hotp : OtpType.totp,
        algorithm: _parseAlgo(otp['algorithm'] as String?),
        digits: otp['digits'] as int? ?? 6,
        period: otp['period'] as int? ?? 30,
        counter: otp['counter'] as int? ?? 0,
      );
    }).toList();
  }

  static List<Token> _importEnte(Map<String, dynamic> data) {
    final items = data['items'] as List;
    return items.map((item) {
      final uri = (item as Map<String, dynamic>)['rawData'] as String? ??
          item['uri'] as String? ??
          '';
      if (uri.startsWith('otpauth://')) {
        return Token.fromUri(uri);
      }
      return Token(
        issuer: item['issuer'] as String? ?? '',
        account: item['account'] as String? ?? '',
        secret: item['secret'] as String? ?? '',
      );
    }).toList();
  }

  static List<Token> _importUriList(String content) {
    return content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('otpauth://'))
        .map((uri) => Token.fromUri(uri))
        .toList();
  }

  static Algorithm _parseAlgo(String? algo) {
    switch (algo?.toUpperCase()) {
      case 'SHA256':
        return Algorithm.sha256;
      case 'SHA512':
        return Algorithm.sha512;
      default:
        return Algorithm.sha1;
    }
  }

  /// Export tokens as otpauth:// URI list.
  static String exportToUriList(List<Token> tokens) {
    return tokens.map((t) => t.toUri()).join('\n');
  }
}
