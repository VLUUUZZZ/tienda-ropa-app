// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

/// The app's root navigator (set on MaterialApp). Its context sits below
/// the app's theme and snackbar host, so it can show a message correctly
/// styled when the screen that wanted to show it is already gone.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The app-wide snackbar host (set on MaterialApp).
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
