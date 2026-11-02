import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/core/auth/pos_permissions.dart';
import 'package:jtr_system/data/models/auth_user_model.dart';

void main() {
  group('PosPermissions', () {
    test('superuser bypasses all checks', () {
      const user = AuthUserModel(
        id: 1,
        name: 'Admin',
        isSuperuser: true,
        permissions: [],
      );
      expect(PosPermissions.canCancelSentArticle(user), isTrue);
      expect(PosPermissions.canCancelTable(user), isTrue);
      expect(PosPermissions.canCancelSeat(user), isTrue);
      expect(PosPermissions.canAccessOffert(user), isTrue);
      expect(PosPermissions.canAccessStatistics(user), isTrue);
      expect(PosPermissions.canViewAllOpenOrders(user), isTrue);
    });

    test('cashier without keys cannot cancel sent article', () {
      const user = AuthUserModel(
        id: 2,
        name: 'Cashier',
        permissions: ['access-payment-button'],
      );
      expect(PosPermissions.canCancelSentArticle(user), isFalse);
      expect(PosPermissions.canCancelTable(user), isFalse);
    });

    test('access-annulation-article grants sent-article cancel', () {
      const user = AuthUserModel(
        id: 3,
        name: 'Manager',
        permissions: [PosPermissions.accessAnnulationArticle],
      );
      expect(PosPermissions.canCancelSentArticle(user), isTrue);
      expect(PosPermissions.canCancelTable(user), isFalse);
      expect(PosPermissions.canCancelSeat(user), isFalse);
    });

    test('access-annulation-table grants table cancel', () {
      const user = AuthUserModel(
        id: 31,
        name: 'Manager',
        permissions: [PosPermissions.accessAnnulationTable],
      );
      expect(PosPermissions.canCancelTable(user), isTrue);
      expect(PosPermissions.canCancelSentArticle(user), isFalse);
    });

    test('access-annulation-seat grants seat/course cancel', () {
      const user = AuthUserModel(
        id: 32,
        name: 'Manager',
        permissions: [PosPermissions.accessAnnulationSeat],
      );
      expect(PosPermissions.canCancelSeat(user), isTrue);
    });

    test('parses permission objects with key field', () {
      const user = AuthUserModel(
        id: 4,
        name: 'Manager',
        permissions: [
          {'key': PosPermissions.accessAnnulationArticle, 'name': 'Annulation'},
        ],
      );
      expect(PosPermissions.canCancelSentArticle(user), isTrue);
    });

    test('access-stock-visual grants Stock Visuel UI', () {
      const user = AuthUserModel(
        id: 5,
        name: 'Manager',
        permissions: [PosPermissions.accessStockVisual],
      );
      expect(PosPermissions.canAccessStockVisual(user), isTrue);
      expect(
        PosPermissions.canAccessStockVisual(
          const AuthUserModel(id: 6, name: 'Cashier', permissions: []),
        ),
        isFalse,
      );
    });

    test('view all open orders uses access-edit-table-details only', () {
      expect(
        PosPermissions.canViewAllOpenOrders(
          const AuthUserModel(
            id: 1,
            name: 'C',
            permissions: [PosPermissions.accessPaymentButton],
          ),
        ),
        isFalse,
      );
      expect(
        PosPermissions.canViewAllOpenOrders(
          const AuthUserModel(
            id: 2,
            name: 'M',
            permissions: [PosPermissions.accessEditTableDetails],
          ),
        ),
        isTrue,
      );
      expect(
        PosPermissions.canViewAllOpenOrders(
          const AuthUserModel(
            id: 3,
            name: 'M',
            permissions: [PosPermissions.accessCloseDay],
          ),
        ),
        isFalse,
      );
      // Role names must not grant access (doc: prefer permissions[]).
      expect(
        PosPermissions.canViewAllOpenOrders(
          const AuthUserModel(id: 4, name: 'M', role: 'Manager'),
        ),
        isFalse,
      );
      expect(
        PosPermissions.canViewAllOpenOrders(
          const AuthUserModel(id: 5, name: 'W', role: 'Serveur'),
        ),
        isFalse,
      );
    });

    test('access-pos-dashboard grants Statistics and JTR Mobile dashboard', () {
      const user = AuthUserModel(
        id: 7,
        name: 'Manager',
        permissions: [PosPermissions.accessPosDashboard],
      );
      expect(PosPermissions.canAccessJtrMobileDashboard(user), isTrue);
      expect(PosPermissions.canAccessStatistics(user), isTrue);
    });

    test('access-dashboard (admin web) does not grant mobile analytics', () {
      const user = AuthUserModel(
        id: 8,
        name: 'Manager',
        permissions: [PosPermissions.accessDashboard],
      );
      expect(PosPermissions.canAccessStatistics(user), isFalse);
      expect(PosPermissions.canAccessJtrMobileDashboard(user), isFalse);
    });

    test('table lock override accepts either override or edit-table-details', () {
      expect(
        PosPermissions.canOverrideTableLock(
          const AuthUserModel(
            id: 9,
            name: 'A',
            permissions: [PosPermissions.accessTableLockOverride],
          ),
        ),
        isTrue,
      );
      expect(
        PosPermissions.canOverrideTableLock(
          const AuthUserModel(
            id: 10,
            name: 'B',
            permissions: [PosPermissions.accessEditTableDetails],
          ),
        ),
        isTrue,
      );
      expect(
        PosPermissions.canOverrideTableLock(
          const AuthUserModel(id: 11, name: 'C', permissions: []),
        ),
        isFalse,
      );
    });

    test('hasAnyPermission matches desktop helper', () {
      const user = AuthUserModel(
        id: 12,
        name: 'U',
        permissions: [PosPermissions.accessOffert],
      );
      expect(
        PosPermissions.hasAnyPermission(user, [
          PosPermissions.accessAnnulationTable,
          PosPermissions.accessOffert,
        ]),
        isTrue,
      );
      expect(
        PosPermissions.hasAnyPermission(user, [
          PosPermissions.accessAnnulationTable,
        ]),
        isFalse,
      );
    });
  });
}
