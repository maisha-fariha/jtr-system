import 'package:flutter_test/flutter_test.dart';

import 'package:jtr_system/data/models/realtime/pos_bootstrap_config.dart';

void main() {
  group('PosBootstrapConfig', () {
    test('parses guide sample', () {
      final config = PosBootstrapConfig.fromJson({
        'success': true,
        'data': {
          'realtime_enabled': true,
          'reverb': {
            'app_key': 'local-key',
            'port': 6001,
            'use_tls': false,
          },
        },
      });
      expect(config.realtimeEnabled, isTrue);
      expect(config.shouldConnect, isTrue);
      expect(config.reverb!.appKey, 'local-key');
      expect(config.reverb!.port, 6001);
      expect(config.reverb!.useTls, isFalse);
    });

    test('parses Goatech demo bootstrap shape', () {
      final config = PosBootstrapConfig.fromJson({
        'success': true,
        'status': 200,
        'locale': 'en',
        'message': 'POS bootstrap config.',
        'data': {
          'realtime_enabled': true,
          'reverb': {
            'app_key': 'local-app-key',
            'port': 443,
            'use_tls': true,
          },
        },
      });
      expect(config.shouldConnect, isTrue);
      expect(config.reverb!.appKey, 'local-app-key');
      expect(config.reverb!.port, 443);
      expect(config.reverb!.useTls, isTrue);
      expect(config.reverb!.host, isNull);
    });

    test('shouldConnect false when reverb null', () {
      final config = PosBootstrapConfig.fromJson({
        'data': {'realtime_enabled': true, 'reverb': null},
      });
      expect(config.shouldConnect, isFalse);
    });

    test('shouldConnect false when realtime disabled', () {
      final config = PosBootstrapConfig.fromJson({
        'data': {
          'realtime_enabled': false,
          'reverb': {'app_key': 'x', 'port': 6001, 'use_tls': true},
        },
      });
      expect(config.shouldConnect, isFalse);
    });

    test('shouldConnect false when app_key empty', () {
      final config = PosBootstrapConfig.fromJson({
        'data': {
          'realtime_enabled': true,
          'reverb': {'app_key': '', 'port': 443, 'use_tls': true},
        },
      });
      expect(config.shouldConnect, isFalse);
    });
  });

  group('TableSessionWireEvent', () {
    test('parses started payload with nested table', () {
      final event = TableSessionWireEvent.fromJson({
        'id': 14,
        'floor_id': 1,
        'locked_by': 1,
        'locked_at': '2026-07-31T16:39:46.000000Z',
        'is_locked': true,
        'status': 'open',
        'session_waiter_name': 'SERVEUR 1',
        'table': {
          'id': 14,
          'floor_id': 1,
          'locked_by': 1,
          'is_locked': true,
          'status': 'open',
        },
      });
      expect(event.tableId, 14);
      expect(event.isLocked, isTrue);
      expect(event.lockedBy, 1);
      expect(event.toTablePatch()['session_owner_id'], 1);
      expect(event.toTablePatch()['session_waiter_name'], 'SERVEUR 1');
    });

    test('ended payload clears owner fields including session_owner_id', () {
      final event = TableSessionWireEvent.fromJson({
        'id': 14,
        'floor_id': 1,
        'locked_by': null,
        'locked_at': null,
        'is_locked': false,
        'status': 'available',
        'session_waiter_name': null,
      });
      expect(event.isLocked, isFalse);
      expect(event.lockedBy, isNull);
      expect(event.status, 'available');

      final patch = event.toTablePatch();
      expect(patch['is_locked'], isFalse);
      expect(patch.containsKey('locked_by'), isTrue);
      expect(patch['locked_by'], isNull);
      expect(patch.containsKey('session_owner_id'), isTrue);
      expect(patch['session_owner_id'], isNull);
      expect(patch.containsKey('session_waiter_name'), isTrue);
      expect(patch['session_waiter_name'], isNull);
    });

    test('merge unlock over previous lock clears stale owner', () {
      final previous = <String, dynamic>{
        'id': 14,
        'is_locked': true,
        'locked_by': 9,
        'session_owner_id': 9,
        'session_waiter_name': 'OLD',
        'status': 'open',
      };
      final ended = TableSessionWireEvent.fromJson({
        'id': 14,
        'locked_by': null,
        'is_locked': false,
        'status': 'available',
        'session_waiter_name': null,
      });
      final merged = {...previous, ...ended.toTablePatch()};
      expect(merged['is_locked'], isFalse);
      expect(merged['locked_by'], isNull);
      expect(merged['session_owner_id'], isNull);
      expect(merged['session_waiter_name'], isNull);
      expect(merged['status'], 'available');
    });
  });

  group('ForceLogoutWireEvent', () {
    test('parses force.logout payload', () {
      final event = ForceLogoutWireEvent.fromJson({
        'user_id': 1,
        'message':
            'You have been logged out because you logged in on another device.',
        'timestamp': '2026-07-31T16:45:00+00:00',
      });
      expect(event.userId, 1);
      expect(event.message, contains('logged out'));
    });
  });
}
