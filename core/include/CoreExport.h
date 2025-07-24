#pragma once

// Macro genérico para la importación/exportación de símbolos en DLLs de Windows.
#ifdef _WIN32
  #ifdef SIMULATOR_EXPORTS
    #define SIMULATOR_API __declspec(dllexport)
  #else
    #define SIMULATOR_API __declspec(dllimport)
  #endif
#else
  // En Linux/macOS, esto ayuda a controlar la visibilidad de los símbolos.
  #define SIMULATOR_API __attribute__((visibility("default")))
#endif