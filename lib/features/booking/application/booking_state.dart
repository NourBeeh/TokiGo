import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_error.dart';

enum BookingPhase {
  idle,
  preparing,
  prepared,
  revalidating,
  readyToConfirm,
  priceChanged,
  unavailable,
  confirming,
  confirmed,
  failed,
  error,
}

class BookingState {
  final BookingPhase phase;
  final BookingRecord? record;
  final BookingPreparation? preparation;
  final String? errorMessage;
  final BookingErrorCode? errorCode;
  final bool priceAccepted;
  final String? idempotencyKey;

  const BookingState({
    required this.phase,
    this.record,
    this.preparation,
    this.errorMessage,
    this.errorCode,
    this.priceAccepted = false,
    this.idempotencyKey,
  });

  factory BookingState.idle() => const BookingState(phase: BookingPhase.idle);

  BookingState copyWith({
    BookingPhase? phase,
    BookingRecord? record,
    BookingPreparation? preparation,
    String? errorMessage,
    BookingErrorCode? errorCode,
    bool? priceAccepted,
    String? idempotencyKey,
  }) {
    return BookingState(
      phase: phase ?? this.phase,
      record: record ?? this.record,
      preparation: preparation ?? this.preparation,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      priceAccepted: priceAccepted ?? this.priceAccepted,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}
