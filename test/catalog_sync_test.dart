import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tienda_ropa_app/data/clothing_repository.dart';
import 'package:tienda_ropa_app/data/remote_catalog.dart';
import 'package:tienda_ropa_app/models/clothing_item.dart';

class FakeRemoteCatalog implements RemoteCatalog {
  final controller = StreamController<RemoteSnapshot>();
  final upserted = <String>[];
  final deleted = <String>[];

  @override
  Stream<RemoteSnapshot> watch() => controller.stream;

  @override
  Future<void> upsert(ClothingItem item) async => upserted.add(item.id);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  Future<void> emit(List<ClothingItem> items, {bool fromServer = true}) async {
    controller.add(RemoteSnapshot(items: items, fromServer: fromServer));
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
    repo = ClothingRepository();
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

    expect(remote.upserted, ['PRENDA-000001']);
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
}
