import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/lifeverse_theme.dart';

class FlashcardWidget extends StatefulWidget {
  final String frontText;
  final String backText;
  final IconData frontIcon;
  final Color themeColor;

  const FlashcardWidget({
    super.key,
    required this.frontText,
    required this.backText,
    this.frontIcon = Icons.lightbulb_outline,
    this.themeColor = LifeVerseColors.primary,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          // Apply 3D transform
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle);

          // If rotated past 90 degrees, show the back side.
          final isBackVisible = angle >= math.pi / 2;

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBackVisible
                ? Transform(
                    // Flip the back side so text isn't backwards
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardSide(isFront: false),
                  )
                : _buildCardSide(isFront: true),
          );
        },
      ),
    );
  }

  Widget _buildCardSide({required bool isFront}) {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFront
              ? [LifeVerseColors.raised, LifeVerseColors.surface]
              : [
                  widget.themeColor.withValues(alpha: .18),
                  LifeVerseColors.surface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFront
              ? LifeVerseColors.line
              : widget.themeColor.withValues(alpha: .5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.themeColor.withValues(alpha: isFront ? 0 : .08),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Center(
        child: isFront
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.frontIcon, color: widget.themeColor, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    widget.frontText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Tap to flip",
                    style: TextStyle(
                      color: LifeVerseColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Text(
                  widget.backText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
              ),
      ),
    );
  }
}
