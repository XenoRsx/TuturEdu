// lib/widgets/message_bubble.dart
//
// Chat bubble shell, extracted out of chat_screen.dart's inline Container.
// Only the shape/decoration lives here - all the per-message content
// (sender name, overtime/scheduled badge, attachment/text, timestamp/tick)
// stays in chat_screen.dart's build method as its `child`, since that logic
// is deeply message-type-specific and not worth generalizing.
//
// Claymorphic: the received-message bubble uses main.dart's clayShadows()
// (soft dual shadow) instead of a single flat shadow, matching AppCard
// elsewhere. The sent-message bubble stays solid blue (accent color, no
// clay treatment) per the app's "pastel surfaces, saturated accents" rule -
// an asymmetric corner (a small "tail" on the sending side) keeps the two
// visually distinct beyond just color.

import 'package:flutter/material.dart';
import '../main.dart' show clayShadows;

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.isMe, required this.child});

  final bool isMe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 18),
        ),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : clayShadows(context, intensity: 0.6),
      ),
      child: child,
    );
  }
}
