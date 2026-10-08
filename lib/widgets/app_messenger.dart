import 'package:flutter/material.dart';

/// The app-wide snackbar host (set on MaterialApp), for messages whose
/// screen may already be gone by the time they're ready.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
