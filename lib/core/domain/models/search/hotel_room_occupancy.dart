import 'package:flutter/foundation.dart';

/// One room's occupancy for a hotel search.
///
/// Each entry represents exactly one room: how many adults sleep in it and
/// the exact age of every child. Children are never represented as a bare
/// count — a child without a known age is invalid for the Nuitee contract.
@immutable
class HotelRoomOccupancy {
  const HotelRoomOccupancy({
    required this.adults,
    this.childAges = const <int>[],
  });

  final int adults;
  final List<int> childAges;

  int get children => childAges.length;

  HotelRoomOccupancy copyWith({int? adults, List<int>? childAges}) {
    return HotelRoomOccupancy(
      adults: adults ?? this.adults,
      childAges: childAges ?? this.childAges,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HotelRoomOccupancy &&
      other.adults == adults &&
      listEquals(other.childAges, childAges);

  @override
  int get hashCode => Object.hash(adults, Object.hashAll(childAges));

  Map<String, dynamic> toJson() => <String, dynamic>{
    'adults': adults,
    'childAges': childAges,
  };

  factory HotelRoomOccupancy.fromJson(Map<String, dynamic> json) {
    return HotelRoomOccupancy(
      adults: (json['adults'] as num?)?.toInt() ?? 1,
      childAges: (json['childAges'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

/// Splits a total adult count across [rooms] rooms for a hotel search.
///
/// One occupancy per room, and the total the traveller picked must be spread
/// across them: giving every room the full count would search a party several
/// times larger than the one on screen. Every room receives at least one
/// adult, so a party smaller than the room count still searches honestly
/// instead of claiming zero adults. Each room is capped at the provider's
/// 20-adult limit.
List<HotelRoomOccupancy> distributeAdultsAcrossRooms({
  required int adults,
  required int rooms,
}) {
  final int safeRooms = rooms < 1 ? 1 : rooms;
  final int safeAdults = adults < 1 ? 1 : adults;
  final int baseAdults = safeAdults ~/ safeRooms;
  final int remainder = safeAdults % safeRooms;
  return List<HotelRoomOccupancy>.generate(
    safeRooms,
    (int index) => HotelRoomOccupancy(
      adults: (baseAdults + (index < remainder ? 1 : 0)).clamp(1, 20),
    ),
  );
}
