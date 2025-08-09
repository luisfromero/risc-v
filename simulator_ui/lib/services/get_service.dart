// Este fichero exporta la implementación correcta según la plataforma.
// Exportará 'get_service_desktop.dart' si 'dart:io' está disponible (escritorio/móvil).
export 'get_service_web.dart' if (dart.library.io) 'get_service_desktop.dart';