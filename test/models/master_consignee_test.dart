/// Test file to verify MasterConsignee update functionality
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/models/master_consignee.dart';

void main() {
  group('MasterConsignee Update Tests', () {
    late MasterConsignee originalConsignee;
    late MasterConsignee updatedConsignee;

    setUp(() {
      originalConsignee = MasterConsignee(
        id: 'consignee-001',
        name: 'Original Customer',
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

      updatedConsignee = originalConsignee.copyWith(
        name: 'Updated Customer',
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
      final updateMap = updatedConsignee.toUpdateMap();

      expect(updateMap['name'], equals('Updated Customer'));
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
      final updateMap = updatedConsignee.toUpdateMap();
      expect(updateMap.containsKey('id'), isFalse);
    });

    test('toUpdateMap includes updated_at timestamp', () {
      final updateMap = updatedConsignee.toUpdateMap();
      expect(updateMap['updated_at'], isA<int>());
      expect(updateMap['updated_at'], greaterThan(0));
    });

    test('copyWith preserves id and createdAt', () {
      expect(updatedConsignee.id, equals(originalConsignee.id));
      expect(updatedConsignee.createdAt, equals(originalConsignee.createdAt));
    });

    test('toFirebase converts timestamps correctly', () {
      final firebaseMap = updatedConsignee.toFirebase();

      expect(firebaseMap['createdAt'], isA<int>());
      expect(firebaseMap['updatedAt'], isA<int>());
      expect(firebaseMap['id'], equals('consignee-001'));
      expect(firebaseMap['name'], equals('Updated Customer'));
    });

    test('formatAddress builds correct single-line address', () {
      final formatted = MasterConsignee.formatAddress(
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
      final displayName = updatedConsignee.displayName;
      expect(displayName, contains('Updated Customer'));
      expect(displayName, contains('New Address'));
    });

    test('equality operator works correctly', () {
      final sameId = updatedConsignee.copyWith(name: 'Different Name');
      final differentId = MasterConsignee(
        id: 'consignee-002',
        name: updatedConsignee.name,
        address: updatedConsignee.address,
        createdAt: updatedConsignee.createdAt,
      );

      expect(updatedConsignee, equals(sameId));
      expect(updatedConsignee, isNot(equals(differentId)));
    });

    test('toString includes id, name and address', () {
      final stringRep = updatedConsignee.toString();
      expect(stringRep, contains('consignee-001'));
      expect(stringRep, contains('Updated Customer'));
      expect(stringRep, contains('New Address'));
    });
  });
}
