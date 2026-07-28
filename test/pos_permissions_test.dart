import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/core/auth/pos_permissions.dart';
import 'package:jtr_system/data/models/auth_user_model.dart';

void main() {
  group('PosPermissions', () {
    test('superuser can edit after send', () {
      const user = AuthUserModel(
        id: 1,
        name: 'Admin',
        isSuperuser: true,
        permissions: [],
      );
      expect(PosPermissions.canEditTableDetailsAfterSend(user), isTrue);
    });

    test('cashier without keys cannot edit after send', () {
      const user = AuthUserModel(
        id: 2,
        name: 'Cashier',
        permissions: ['access-payment-button'],
      );
      expect(PosPermissions.canEditTableDetailsAfterSend(user), isFalse);
    });

    test('manager with access-edit-table-details can edit after send', () {
      const user = AuthUserModel(
        id: 3,
        name: 'Manager',
        permissions: [PosPermissions.accessEditTableDetails],
      );
      expect(PosPermissions.canEditTableDetailsAfterSend(user), isTrue);
    });

    test('parses permission objects with key field', () {
      const user = AuthUserModel(
        id: 4,
        name: 'Manager',
        permissions: [
          {'key': PosPermissions.accessEditTableDetails, 'name': 'Edit'},
        ],
      );
      expect(PosPermissions.canEditTableDetailsAfterSend(user), isTrue);
    });

    test('superuser can view stock visual', () {
      const user = AuthUserModel(
        id: 5,
        name: 'Admin',
        isSuperuser: true,
        permissions: [],
      );
      expect(PosPermissions.canViewStockVisual(user), isTrue);
    });

    test('user with access-stock-visual can view stock', () {
      const user = AuthUserModel(
        id: 6,
        name: 'Stock',
        permissions: [PosPermissions.accessStockVisual],
      );
      expect(PosPermissions.canViewStockVisual(user), isTrue);
    });

    test('cashier without stock key cannot view stock', () {
      const user = AuthUserModel(
        id: 7,
        name: 'Cashier',
        permissions: ['access-payment-button'],
      );
      expect(PosPermissions.canViewStockVisual(user), isFalse);
    });
  });
}
