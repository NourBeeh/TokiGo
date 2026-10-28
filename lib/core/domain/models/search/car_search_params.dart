import 'package:flutter/foundation.dart';

@immutable
class CarSearchParams {
  final String pickupLocation;
  final String dropoffLocation;
  final DateTime pickupDateTime;
  final DateTime dropoffDateTime;
  final int driverAge;
  final String? carType;
  final String? transmission;

  const CarSearchParams({
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupDateTime,
    required this.dropoffDateTime,
    this.driverAge = 25,
    this.carType,
    this.transmission,
  });
}
