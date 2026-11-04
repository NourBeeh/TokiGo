import 'package:flutter/material.dart';

/// Compatibility wrapper for the former AI page content entrance.
///
/// The route transition itself is strictly horizontal and is owned by the
/// platform (native Cupertino on iOS, predictive back on Android). A content
/// entrance on top of it used to scale the whole page from
/// `Alignment.bottomRight`, which made every pushed page appear to grow
/// diagonally out of the bottom-right corner (and put a second animation in
/// the tree during the interactive back-swipe).
///
/// The wrapper therefore adds nothing: it renders [child] unchanged, keeping
/// existing call sites compiling without reintroducing a zoom/corner entrance.
class AiEntranceAnimation extends StatelessWidget {
  const AiEntranceAnimation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
