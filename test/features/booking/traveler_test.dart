import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/booking/domain/traveler.dart';

void main() {
  test('Traveler validation', () {
    final t = Traveler(id: '1', firstName: 'A', lastName: 'B', email: 'a@b.com', phone: '123');
    expect(t.firstName, 'A');
    expect(t.email, 'a@b.com');
  });
}
