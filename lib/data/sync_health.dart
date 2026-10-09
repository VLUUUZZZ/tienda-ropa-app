// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/foundation.dart';

/// Whether this phone can reach the server right now, as far as sync can
/// tell from the catalog's live connection.
enum SyncConnection {
  /// Just started; no answer from the server yet.
  connecting,

  /// The latest data came from the server.
  online,

  /// Only the phone's offline copy is reachable (no internet, or the server
  /// can't be reached and sync keeps retrying).
  offline,
}

/// How sync is doing, for the screens to show. Only observed — nothing in
/// here changes what sync does.
@immutable
class SyncHealth {
  const SyncHealth({
    this.connection = SyncConnection.connecting,
    this.lastSync,
    this.retrying = false,
    this.lastRejection,
  });

  final SyncConnection connection;

  /// Last time the server confirmed data or a change (null: never on this
  /// phone).
  final DateTime? lastSync;

  /// The connection to the server failed and sync is waiting to retry.
  final bool retrying;

  /// Last time the server refused a change made here (e.g. the account lost
  /// permission meanwhile): that change was undone and the server's version
  /// put back.
  final DateTime? lastRejection;

  SyncHealth copyWith({
    SyncConnection? connection,
    DateTime? lastSync,
    bool? retrying,
    DateTime? lastRejection,
  }) => SyncHealth(
    connection: connection ?? this.connection,
    lastSync: lastSync ?? this.lastSync,
    retrying: retrying ?? this.retrying,
    lastRejection: lastRejection ?? this.lastRejection,
  );
}
