import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tienda_ropa_app/data/clothing_repository.dart';
import 'package:tienda_ropa_app/data/remote_catalog.dart';
import 'package:tienda_ropa_app/models/clothing_item.dart';

class FakeRemoteCatalog implements RemoteCatalog {
  // A fresh stream per watch(), like Firestore after a listener is re-opened.
  var controller = StreamController<RemoteSnapshot>();
  var watchCount = 0;
  final upserted = <String>[];
  final deleted = <String>[];

  /// When set, writes fail with this error (e.g. no connection).
  Object? failWritesWith;

  @override
  Stream<RemoteSnapshot> watch() {
    if (watchCount > 0) controller = StreamController<RemoteSnapshot>();
    watchCount++;
    return controller.stream;
  }

  @override
  Future<void> upsert(ClothingItem item) async {
    if (failWritesWith != null) throw failWritesWith!;
    upserted.add(item.id);
  }

  @override
  Future<void> delete(String id) async {
    if (failWritesWith != null) throw failWritesWith!;
    deleted.add(id);
  }

  Future<void> emit(List<ClothingItem> items, {bool fromServer = true}) async {
    controller.add(RemoteSnapshot(items: items, fromServer: fromServer));
    await pumpEventQueue();
  }

  /// Like Firestore: an error, then the listener is closed.
  Future<void> fail(Object error) async {
    controller.addError(error);
    await controller.close();
    await pumpEventQueue();
  }
}

/// Emits a snapshot and waits until [repo] has finished writing it to Hive
/// (real file I/O, so pumping the event queue alone isn't enough).
Future<void> emitAndSettle(
  FakeRemoteCatalog remote,
  ClothingRepository repo,
  List<ClothingItem> items, {
  bool fromServer = true,
}) async {
  await remote.emit(items, fromServer: fromServer);
  await repo.remoteSettled;
}

ClothingItem item(String id, {String nombre = 'Playera', int existencia = 1}) {
  return ClothingItem(
    id: id,
    nombre: nombre,
    precio: 100,
    variantes: [
      ClothingVariant(talla: 'M', color: 'Negro', existencia: existencia),
    ],
  );
}

void main() {
  late Directory tempDir;
  late ClothingRepository repo;
  late FakeRemoteCatalog remote;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    repo = ClothingRepository(initialRetryDelay: Duration.zero);
    await repo.init();
    remote = FakeRemoteCatalog();
  });

  tearDown(() async {
    await repo.detachRemote();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('saves and deletes are mirrored to the remote catalog', () async {
    await repo.attachRemote(remote);

    await repo.save(item('PRENDA-000001'));
    await repo.delete('PRENDA-000001');

    expect(remote.upserted, ['PRENDA-000001']);
    expect(remote.deleted, ['PRENDA-000001']);
  });

  test('works local-only when no remote is attached', () async {
    await repo.save(item('PRENDA-000001'));

    expect(repo.getAll(), hasLength(1));
    expect(remote.upserted, isEmpty);
  });

  test('remote items and edits land in the local catalog', () async {
    await repo.attachRemote(remote);

    await emitAndSettle(remote, repo, [item('PRENDA-000007', existencia: 3)]);
    expect(repo.getById('PRENDA-000007')!.existenciaTotal, 3);

    await emitAndSettle(remote, repo, [item('PRENDA-000007', existencia: 9)]);
    expect(repo.getById('PRENDA-000007')!.existenciaTotal, 9);
  });

  test('first server contact uploads local-only items instead of '
      'deleting them', () async {
    await repo.save(item('PRENDA-000001'));
    await repo.attachRemote(remote);

    await emitAndSettle(remote, repo, [item('PRENDA-000002')]);

    // Upserts are idempotent, so being pushed on attach and again on first
    // contact is fine; what matters is it's uploaded and never deleted.
    expect(remote.upserted.toSet(), {'PRENDA-000001'});
    expect(repo.getAll().map((i) => i.id), ['PRENDA-000001', 'PRENDA-000002']);
  });

  test('after the first upload, items deleted remotely are removed '
      'locally', () async {
    await repo.attachRemote(remote);
    await emitAndSettle(remote, repo, [
      item('PRENDA-000001'),
      item('PRENDA-000002'),
    ]);

    await emitAndSettle(remote, repo, [item('PRENDA-000002')]);

    expect(repo.getAll().map((i) => i.id), ['PRENDA-000002']);
  });

  test('a cache-only snapshot never deletes local items', () async {
    await repo.attachRemote(remote);
    await emitAndSettle(remote, repo, [item('PRENDA-000001')]);

    await emitAndSettle(remote, repo, [], fromServer: false);

    expect(repo.getAll(), hasLength(1));
  });

  test('generateId skips ids another device already used', () async {
    await repo.attachRemote(remote);
    await emitAndSettle(remote, repo, [
      item('PRENDA-000001'),
      item('PRENDA-000002'),
    ]);

    expect(await repo.generateId(), 'PRENDA-000003');
  });

  test('unconfirmed local changes survive stale remote snapshots', () async {
    await repo.attachRemote(remote);
    await emitAndSettle(remote, repo, [
      item('PRENDA-000001', existencia: 1),
      item('PRENDA-000002'),
    ]);

    remote.failWritesWith = Exception('sin conexión');
    await repo.save(item('PRENDA-000001', existencia: 5));
    await repo.delete('PRENDA-000002');
    await pumpEventQueue();

    // The server still has the old versions: they must not win.
    await emitAndSettle(remote, repo, [
      item('PRENDA-000001', existencia: 1),
      item('PRENDA-000002'),
    ]);

    expect(repo.getById('PRENDA-000001')!.existenciaTotal, 5);
    expect(repo.getById('PRENDA-000002'), isNull);
    expect(repo.pendingIds, {'PRENDA-000001', 'PRENDA-000002'});
  });

  test(
    'changes made while sync was off are pushed on the next attach',
    () async {
      await repo.attachRemote(remote);
      await emitAndSettle(remote, repo, [item('PRENDA-000001')]);
      await repo.detachRemote();

      await repo.save(item('PRENDA-000002'));
      await repo.delete('PRENDA-000001');
      expect(remote.upserted, isEmpty);

      await repo.attachRemote(remote);
      await pumpEventQueue();

      expect(remote.upserted, ['PRENDA-000002']);
      expect(remote.deleted, ['PRENDA-000001']);
      expect(repo.pendingIds, isEmpty);
    },
  );

  test('re-opens the remote listener after an error', () async {
    await repo.attachRemote(remote);
    await remote.fail(Exception('permiso denegado'));

    expect(remote.watchCount, 2);
    await emitAndSettle(remote, repo, [item('PRENDA-000004')]);
    expect(repo.getById('PRENDA-000004'), isNotNull);
  });

  test('failed writes are retried once the listener reconnects', () async {
    await repo.attachRemote(remote);
    remote.failWritesWith = Exception('sin conexión');
    await repo.save(item('PRENDA-000001'));
    await pumpEventQueue();
    expect(repo.pendingIds, {'PRENDA-000001'});

    remote.failWritesWith = null;
    await remote.fail(Exception('red caída'));

    expect(remote.upserted, ['PRENDA-000001']);
    expect(repo.pendingIds, isEmpty);
  });

  test(
    'a corrupt local record is skipped instead of breaking the list',
    () async {
      await Hive.box(
        ClothingRepository.boxName,
      ).put('PRENDA-000009', {'nombre': 'sin id'});
      await repo.save(item('PRENDA-000001'));

      expect(repo.getAll().map((i) => i.id), ['PRENDA-000001']);
    },
  );
}
