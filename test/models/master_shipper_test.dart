/// Test file to verify MasterShipper update functionality
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/models/master_shipper.dart';

void main() {
  group('MasterShipper Update Tests', () {
    late MasterShipper originalShipper;
    late MasterShipper updatedShipper;

    setUp(() {
      originalShipper = MasterShipper(
        id: 'shipper-001',
        name: 'Original Company',
        address: 'Old Address',
        phone: '1234567890',
        addressLine1: 'Old Street',
        addressLine2: 'Old Building',
        city: 'Old City',
        state: 'OS',
        pincode: '12345',
        landmark: 'Old Landmark',
        createdAt: DateTime.now(),
      );

      updatedShipper = originalShipper.copyWith(
        name: 'Updated Company',
        address: 'New Address',
        phone: '0987654321',
        addressLine1: 'New Street',
        addressLine2: 'New Building',
        city: 'New City',
        state: 'NS',
        pincode: '54321',
        landmark: 'New Landmark',
        updatedAt: DateTime.now(),
      );
    });

    test('toUpdateMap includes all required fields', () {
      final updateMap = updatedShipper.toUpdateMap();

      expect(updateMap['name'], equals('Updated Company'));
      expect(updateMap['address'], equals('New Address'));
      expect(updateMap['phone'], equals('0987654321'));
      expect(updateMap['address_line1'], equals('New Street'));
      expect(updateMap['address_line2'], equals('New Building'));
      expect(updateMap['city'], equals('New City'));
      expect(updateMap['state'], equals('NS'));
      expect(updateMap['pincode'], equals('54321'));
      expect(updateMap['landmark'], equals('New Landmark'));
      expect(updateMap.containsKey('updated_at'), isTrue);
    });

    test('toUpdateMap does not include id field', () {
      final updateMap = updatedShipper.toUpdateMap();
      expect(updateMap.containsKey('id'), isFalse);
    });

    test('toUpdateMap includes updated_at timestamp', () {
      final updateMap = updatedShipper.toUpdateMap();
      expect(updateMap['updated_at'], isA<int>());
      expect(updateMap['updated_at'], greaterThan(0));
    });

    test('copyWith preserves id and createdAt', () {
      expect(updatedShipper.id, equals(originalShipper.id));
      expect(updatedShipper.createdAt, equals(originalShipper.createdAt));
    });

    test('toFirebase converts timestamps correctly', () {
      final firebaseMap = updatedShipper.toFirebase();

      expect(firebaseMap['createdAt'], isA<int>());
      expect(firebaseMap['updatedAt'], isA<int>());
      expect(firebaseMap['id'], equals('shipper-001'));
      expect(firebaseMap['name'], equals('Updated Company'));
    });

    test('formatAddress builds correct single-line address', () {
      final formatted = MasterShipper.formatAddress(
        phone: '1234567890',
        addressLine1: 'Main Street',
        addressLine2: 'Apt 5',
        city: 'Springfield',
        state: 'IL',
        pincode: '62701',
        landmark: 'near park',
      );

      expect(
        formatted,
        contains('Ph: 1234567890'),
      );
      expect(formatted, contains('Main Street'));
      expect(formatted, contains('Apt 5'));
      expect(formatted, contains('Springfield'));
      expect(formatted, contains('IL'));
      expect(formatted, contains('62701'));
      expect(formatted, contains('(near park)'));
    });

    test('displayName includes name and address', () {
      final displayName = updatedShipper.displayName;
      expect(displayName, contains('Updated Company'));
      expect(displayName, contains('New Address'));
    });
  });
}
