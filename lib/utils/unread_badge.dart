// lib/utils/unread_badge.dart
//
// Best-effort OS-level notification badge for the total unread chat count,
// like WhatsApp shows on its app icon - uses the Web Badging API
// (navigator.setAppBadge/clearAppBadge). Only takes effect when TuturEdu is
// installed as a PWA on a browser that supports it (currently
// Chromium-based); everywhere else this is a silent no-op, since it's a
// nice-to-have, not a required feature.
//
// Conditional export keeps this safe to import from shared widget code even
// though the real implementation only compiles for web.
export 'unread_badge_stub.dart' if (dart.library.js_interop) 'unread_badge_web.dart';
