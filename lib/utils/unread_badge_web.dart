// lib/utils/unread_badge_web.dart
//
// Web implementation of the unread chat badge, via the Badging API
// (https://w3c.github.io/badging/). `navigator.setAppBadge`/`clearAppBadge`
// only exist on Chromium-based browsers and only visibly do anything once
// the site is installed as a PWA - both bindings below are declared
// nullable so a missing property resolves to `null` instead of throwing,
// which is how we feature-detect before calling.

import 'dart:js_interop';

@JS('navigator.setAppBadge')
external JSFunction? get _setAppBadgeFn;

@JS('navigator.setAppBadge')
external JSPromise<JSAny?> _callSetAppBadge(int contents);

@JS('navigator.clearAppBadge')
external JSFunction? get _clearAppBadgeFn;

@JS('navigator.clearAppBadge')
external JSPromise<JSAny?> _callClearAppBadge();

void setUnreadChatBadge(int count) {
  try {
    if (count > 0) {
      if (_setAppBadgeFn != null) _callSetAppBadge(count);
    } else if (_clearAppBadgeFn != null) {
      _callClearAppBadge();
    }
  } catch (_) {
    // Badging API existed but the call itself failed (e.g. permission
    // policy) - this is a best-effort enhancement, so just ignore it.
  }
}
