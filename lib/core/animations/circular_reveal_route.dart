import 'dart:math';
import 'package:flutter/material.dart';

class CircularRevealRoute extends PageRouteBuilder {
  final Widget page;
  final Offset center; // The point where the animation starts

  CircularRevealRoute({required this.page, required this.center})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ClipPath(
        clipper: CircleRevealClipper(
          fraction: animation.value,
          center: center,
        ),
        child: child,
      );
    },
  );
}

class CircleRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  CircleRevealClipper({required this.fraction, required this.center});

  @override
  Path getClip(Size size) {
    // 1. Calculate the distance from the touch point to the furthest corner
    final double distanceToTopLeft = sqrt(pow(center.dx, 2) + pow(center.dy, 2));
    final double distanceToTopRight = sqrt(pow(size.width - center.dx, 2) + pow(center.dy, 2));
    final double distanceToBottomLeft = sqrt(pow(center.dx, 2) + pow(size.height - center.dy, 2));
    final double distanceToBottomRight = sqrt(pow(size.width - center.dx, 2) + pow(size.height - center.dy, 2));

    // 2. Find the max radius needed to cover the whole screen
    final double maxRadius = [
      distanceToTopLeft,
      distanceToTopRight,
      distanceToBottomLeft,
      distanceToBottomRight
    ].reduce(max);

    // 3. Draw the circle based on the animation fraction (0.0 to 1.0)
    return Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: maxRadius * fraction),
      );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}