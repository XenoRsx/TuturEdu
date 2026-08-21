// lib/utils/phishing_detector.dart
//
// Lightweight heuristic URL scanner for chat messages (see BLUEPRINT.md
// section 11). Client-side only, no external API/Cloud Function - flags
// patterns commonly seen in phishing links (raw IP hosts, the "@" trick,
// known shorteners, punycode/IDN, abused TLDs) rather than doing a real
// reputation lookup. Treat a "safe" result as "nothing obvious was found",
// not a guarantee - and a "suspicious" result as a warning, not proof.

/// Matches "http(s)://..." and bare "www...." links in free-form text.
final RegExp urlPattern = RegExp(
  r'((https?://|www\.)\S+)',
  caseSensitive: false,
);

final RegExp _ipHostPattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

const Set<String> _knownShorteners = {
  'bit.ly',
  'tinyurl.com',
  't.co',
  'goo.gl',
  'is.gd',
  'ow.ly',
  'buff.ly',
  'rebrand.ly',
};

const Set<String> _suspiciousTlds = {
  '.tk',
  '.ml',
  '.ga',
  '.cf',
  '.gq',
  '.top',
  '.click',
  '.work',
};

/// Adds a scheme to a bare "www...." match so it can be parsed/launched -
/// `Uri.parse('www.example.com')` alone doesn't resolve a host.
String normalizeUrl(String rawUrl) {
  if (rawUrl.toLowerCase().startsWith('www.')) return 'https://$rawUrl';
  return rawUrl;
}

/// Heuristic-only check (BLUEPRINT.md 11.3) - true if [rawUrl] matches a
/// pattern commonly abused for phishing. Not a real reputation check.
bool isSuspiciousUrl(String rawUrl) {
  final Uri uri;
  try {
    uri = Uri.parse(normalizeUrl(rawUrl));
  } catch (_) {
    return true; // Unparsable as a URL at all is itself a red flag.
  }

  final host = uri.host.toLowerCase();
  if (host.isEmpty) return true;

  if (_ipHostPattern.hasMatch(host)) return true;
  // "@" trick, e.g. http://legit-site.com@evil.com/ - Uri.parse resolves
  // the real host to evil.com but keeps legit-site.com as userInfo.
  if (uri.userInfo.isNotEmpty) return true;
  if (_knownShorteners.contains(host)) return true;
  if (host.contains('xn--')) return true;
  if (_suspiciousTlds.any((tld) => host.endsWith(tld))) return true;

  return false;
}
