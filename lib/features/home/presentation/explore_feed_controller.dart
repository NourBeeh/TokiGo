import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';

/// Loading state of the Explore destination feed (the backend's published
/// destination cards, merged into the bundled catalog).
enum ExploreFeedStatus { loading, success, error }

@immutable
class ExploreFeedState {
  const ExploreFeedState({
    this.status = ExploreFeedStatus.loading,
    this.sections = const <HomeSection>[],
    this.errorMessage,
  });

  final ExploreFeedStatus status;
  final List<HomeSection> sections;
  final String? errorMessage;

  ExploreFeedState copyWith({
    ExploreFeedStatus? status,
    List<HomeSection>? sections,
    String? errorMessage,
  }) {
    return ExploreFeedState(
      status: status ?? this.status,
      sections: sections ?? this.sections,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Loads the backend destination feed used by the Explore Cities page.
///
/// This is deliberately NOT the old Home controller: it has no snapshot, no
/// price validation, no composer and no recommendation rail. Home itself does
/// not use it at all — it renders the bundled Explore catalog directly.
class ExploreFeedController extends StateNotifier<ExploreFeedState> {
  ExploreFeedController(this.repository) : super(const ExploreFeedState()) {
    load();
  }

  final HomeRepository repository;

  Future<void> load() async {
    state = state.copyWith(status: ExploreFeedStatus.loading);
    final result = await repository.getHomeSections();
    result.when(
      success: (List<HomeSection> sections) {
        state = state.copyWith(
          status: ExploreFeedStatus.success,
          sections: sections,
          errorMessage: null,
        );
      },
      failure: (Object error) {
        state = state.copyWith(
          status: ExploreFeedStatus.error,
          errorMessage: userFacingMessage(error, subject: 'explore feed'),
        );
      },
    );
  }
}
