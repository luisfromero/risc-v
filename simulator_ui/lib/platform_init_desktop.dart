import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const String _kWindowTitle = 'RISC-V Datapath Simulator';
const Size _kInitialWindowSize = Size(1600, 900);

// Implementación para plataformas de escritorio.
// Configura el tamaño inicial de la ventana y su título.
Future<void> setupWindow() async {
  // Asegurarnos de que solo se ejecute en plataformas de escritorio
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: _kInitialWindowSize,
      title: _kWindowTitle,
      titleBarStyle: TitleBarStyle.normal,
    );
 
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
 
      // Volvemos a usar el método center() del window_manager.
      // Se ejecuta lo suficientemente tarde para no causar la excepción original.
      //await windowManager.center();
      //      await windowManager.setAlignment(Alignment.center);

    });
  }
}
