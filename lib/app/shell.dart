import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

/// The unified application shell.
///
/// The app is Home-centric: every product vertical is reached from the Home
/// surface through `HomeNavButtons` (flights / hotels / cars / packages) plus
/// the compact Groups entry. The shell only hosts the navigation stack.
class TokiGoShell extends StatelessWidget {
  const TokiGoShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: navigationShell);
  }
}
