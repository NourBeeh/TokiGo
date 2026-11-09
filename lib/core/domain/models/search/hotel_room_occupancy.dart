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

  HotelRoomOccupancy copyWith({
    int? adults,
    List<int>? childAges,
  }) {
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
