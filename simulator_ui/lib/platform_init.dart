export 'platform_init_stub.dart' // Implementación por defecto (stub para web/móvil)
    if (dart.library.io) 'platform_init_desktop.dart'; // Implementación para desktop