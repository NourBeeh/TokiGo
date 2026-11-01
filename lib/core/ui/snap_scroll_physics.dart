import 'package:flutter/material.dart';

class SnapScrollPhysics extends ScrollPhysics {
  const SnapScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) => SnapScrollPhysics(parent: buildParent(ancestor));

  @override
  double get minFlingVelocity => 0.0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (velocity.abs() < 0.01) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      _snapToCard(position.pixels, velocity),
      velocity,
      tolerance: tolerance,
    );
  }

  double _snapToCard(double current, double velocity) {
    const cardHeight = 300.0;
    return (current / cardHeight).round() * cardHeight;
  }
}
