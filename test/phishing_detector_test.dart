import 'package:flutter_test/flutter_test.dart';
import 'package:tuturedu/utils/phishing_detector.dart';

void main() {
  group('isSuspiciousUrl', () {
    test('ordinary links are not flagged', () {
      expect(isSuspiciousUrl('https://www.google.com'), isFalse);
      expect(isSuspiciousUrl('https://tuturedu-app.web.app/'), isFalse);
      expect(isSuspiciousUrl('www.example.com/page'), isFalse);
    });

    test('raw IP address hosts are flagged', () {
      expect(isSuspiciousUrl('http://192.168.1.1/login'), isTrue);
    });

    test('the "@" userinfo trick is flagged', () {
      expect(isSuspiciousUrl('http://paypal.com@evil.com/'), isTrue);
    });

    test('known link shorteners are flagged', () {
      expect(isSuspiciousUrl('https://bit.ly/abc123'), isTrue);
      expect(isSuspiciousUrl('https://tinyurl.com/xyz'), isTrue);
    });

    test('punycode (lookalike unicode) domains are flagged', () {
      expect(isSuspiciousUrl('https://xn--pypal-4ve.com'), isTrue);
    });

    test('commonly abused TLDs are flagged', () {
      expect(isSuspiciousUrl('https://free-prize.tk'), isTrue);
      expect(isSuspiciousUrl('https://login-update.click/verify'), isTrue);
    });
  });

  group('normalizeUrl', () {
    test('adds https:// to bare www links', () {
      expect(normalizeUrl('www.example.com'), 'https://www.example.com');
    });

    test('leaves links that already have a scheme unchanged', () {
      expect(normalizeUrl('http://example.com'), 'http://example.com');
    });
  });

  group('urlPattern', () {
    test('finds links inside free-form chat text', () {
      final matches = urlPattern
          .allMatches('See www.example.com and https://a.com/x tonight')
          .map((m) => m.group(0))
          .toList();
      expect(matches, ['www.example.com', 'https://a.com/x']);
    });
  });
}
