import 'dart:math';
import 'package:flutter/material.dart';

// 1. GLOBAL HELPER TO STORE LAST TAP POSITION
class RevealData {
  static Offset? lastTap;
}

class CircularRevealPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return _CircularRevealTransition(
      animation: animation,
      child: child,
    );
  }
}

class _CircularRevealTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _CircularRevealTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // 2. USE LAST TAP POSITION (OR CENTER IF NULL)
        final center = RevealData.lastTap ?? Offset(size.width / 2, size.height / 2);

        // 3. CALCULATE DISTANCE TO FURTHEST CORNER
        // We need to cover the whole screen, so find the furthest corner from the tap
        double distanceTo(Offset point) {
          final dx = point.dx - center.dx;
          final dy = point.dy - center.dy;
          return sqrt(dx * dx + dy * dy);
        }

        final topLeft = distanceTo(Offset.zero);
        final topRight = distanceTo(Offset(size.width, 0));
        final bottomLeft = distanceTo(Offset(0, size.height));
        final bottomRight = distanceTo(Offset(size.width, size.height));

        final maxRadius = [topLeft, topRight, bottomLeft, bottomRight].reduce(max);

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return ClipPath(
              clipper: _CircularRevealClipper(
                center: center,
                fraction: animation.value,
                maxRadius: maxRadius,
              ),
              child: child,
            );
          },
          child: child,
        );
      },
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double fraction;
  final double maxRadius;

  _CircularRevealClipper({
    required this.center,
    required this.fraction,
    required this.maxRadius,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final radius = maxRadius * fraction;
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.center != center;
  }
}