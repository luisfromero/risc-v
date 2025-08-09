import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// Implementación para plataformas de escritorio.
// Configura el tamaño inicial de la ventana y su título.
Future<void> setupWindow() async {
  // Asegurarnos de que solo se ejecute en plataformas de escritorio
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1600, 900),
      center: true,
      title: "RISC-V Datapath Simulator",
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
