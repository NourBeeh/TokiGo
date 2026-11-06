import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The resume destination loaded from disk at startup.
///
/// Overridden in `main()` once the saved location is read, so the router can
/// compute its initial location synchronously (before the first frame).
final savedResumeLocationProvider = Provider<String?>((ref) => null);

/// The last allowlisted browse destination visited this session.
///
/// Updated by the router listener on every navigation; the pinned resume
/// button reads it. Null until the traveller first lands on a browse page.
final resumeDestinationProvider = StateProvider<String?>((ref) => null);

/// The current router location, updated on every navigation.
///
/// Used to mark the resume button's selected state and to decide which pages
/// show the pinned top bar.
final currentLocationProvider = StateProvider<String>((ref) => '/');
