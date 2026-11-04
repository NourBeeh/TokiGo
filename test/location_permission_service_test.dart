import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tokigo/core/geo/location_permission_service.dart';

void main() {
  group('LocationPermissionService - check() states', () {
    test('service disabled returns serviceDisabled', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(false),
        checkPermission: () => Future.value(LocationPermission.denied),
      );
      expect(await service.check(), LocationAccess.serviceDisabled);
    });

    test('denied returns denied', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.denied),
      );
      expect(await service.check(), LocationAccess.denied);
    });

    test('deniedForever returns deniedForever', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.deniedForever),
      );
      expect(await service.check(), LocationAccess.deniedForever);
    });

    test('always returns granted', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.always),
      );
      expect(await service.check(), LocationAccess.granted);
    });

    test('whileInUse returns granted', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.whileInUse),
      );
      expect(await service.check(), LocationAccess.granted);
    });

    test('unableToDetermine is treated as denied (prompt allowed)', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.unableToDetermine),
      );
      expect(await service.check(), LocationAccess.denied);
    });

    test('uncaught exception returns unavailable', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.error(Exception('broken')),
      );
      expect(await service.check(), LocationAccess.unavailable);
    });
  });

  group('LocationPermissionService - request() states', () {
    test('service disabled returns serviceDisabled', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(false),
        checkPermission: () => Future.value(LocationPermission.denied),
        requestPermission: () => Future.value(LocationPermission.always),
      );
      expect(await service.request(), LocationAccess.serviceDisabled);
    });

    test('denied then granted returns granted', () async {
      var asked = false;
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () {
          return Future.value(asked ? LocationPermission.always : LocationPermission.denied);
        },
        requestPermission: () {
          asked = true;
          return Future.value(LocationPermission.always);
        },
      );
      expect(await service.request(), LocationAccess.granted);
      expect(asked, true); // prompt actually triggered
    });

    test('already granted returns granted without prompting', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.always),
        requestPermission: () => Future.value(LocationPermission.denied),
      );
      expect(await service.request(), LocationAccess.granted);
    });

    test('deniedForever returns deniedForever', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.deniedForever),
        requestPermission: () => Future.value(LocationPermission.always),
      );
      expect(await service.request(), LocationAccess.deniedForever);
    });

    test('unableToDetermine falls back to requestPermission', () async {
      var asked = false;
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.unableToDetermine),
        requestPermission: () {
          asked = true;
          return Future.value(LocationPermission.always);
        },
      );
      expect(await service.request(), LocationAccess.granted);
      expect(asked, true);
    });

    test('uncaught exception returns unavailable', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.error(Exception('broken')),
      );
      expect(await service.request(), LocationAccess.unavailable);
    });
  });

  group('LocationPermissionService - openSettings / openLocationSettings', () {
    test('openSettings delegates to _openAppSettings', () async {
      bool opened = false;
      final service = LocationPermissionService(
        openAppSettings: () async {
          opened = true;
          return Future.value();
        },
      );
      await service.openSettings();
      expect(opened, true);
    });

    test('openLocationSettings delegates to _openLocationSettings', () async {
      bool opened = false;
      final service = LocationPermissionService(
        openLocationSettings: () async {
          opened = true;
          return Future.value();
        },
      );
      await service.openLocationSettings();
      expect(opened, true);
    });

    test('exceptions in openSettings are caught (best-effort)', () async {
      final service = LocationPermissionService(
        openAppSettings: () => Future.error(Exception('blocked')),
      );
      // Should not throw
      await service.openSettings();
    });
  });

  group('LocationPermissionService - _map', () {
    test('deniedForever maps to deniedForever', () async {
      final service = LocationPermissionService(
        isServiceEnabled: () => Future.value(true),
        checkPermission: () => Future.value(LocationPermission.deniedForever),
      );
      // check() maps via _map
      expect(await service.check(), LocationAccess.deniedForever);
    });
  });
}
