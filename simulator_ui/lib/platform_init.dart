// Este archivo utiliza importaciones condicionales para cargar el código
// de inicialización de plataforma correcto.

export 'platform_init_stub.dart' // Implementación de respaldo
    if (dart.library.io) 'platform_init_desktop.dart' // Para Windows, macOS, Linux, Android, iOS
    if (dart.library.html) 'platform_init_web.dart'; // Para Web
