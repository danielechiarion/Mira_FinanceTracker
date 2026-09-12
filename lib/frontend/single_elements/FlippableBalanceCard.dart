import 'dart:math';

import 'package:flutter/material.dart';

/// A card that flips (like a physical card) between a [front] and a [back]
/// widget when tapped. Both sides share the same rounded, bordered "white
/// card" look used throughout the app (see HomePage's section cards), so
/// callers only need to provide the content, not the decoration.
class FlippableBalanceCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;

  const FlippableBalanceCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FlippableBalanceCard> createState() => _FlippableBalanceCardState();
}

class _FlippableBalanceCardState extends State<FlippableBalanceCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  bool _showingFront = true;

  void _flip() {
    if (_showingFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _showingFront = !_showingFront);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * pi;
          final isBackVisible = angle > pi / 2;

          /* the back content is counter-rotated by pi so it reads correctly
          once the card has flipped past the halfway point, instead of
          showing up mirrored */
          final content = isBackVisible
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: widget.back,
                )
              : widget.front;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: _cardShell(content),
          );
        },
      ),
    );
  }

  /// Same decoration used by HomePage's `_sectionCard`, kept here so both
  /// faces of the card always look consistent with the rest of the app.
  Widget _cardShell(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }
}