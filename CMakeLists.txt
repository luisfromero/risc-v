# Versión mínima de CMake requerida
cmake_minimum_required(VERSION 3.10)

# Nombre del proyecto
project(riscv_simulator VERSION 1.0)

# Usar el estándar C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Indicar a CMake dónde encontrar los archivos de cabecera (.h)
include_directories(core/include)

# Encontrar todos los archivos fuente (.cpp) en el directorio src
aux_source_directory(core/src CORE_SOURCES)

# Crear una biblioteca COMPARTIDA (SHARED -> .so o .dll) llamada "simulator"
# a partir de los archivos fuente encontrados.
add_library(simulator SHARED ${CORE_SOURCES})

# --- Sección para Tests y Depuración ---
# Habilitar los tests
enable_testing()

# Añadir un ejecutable para pruebas y depuración
add_executable(simulator_test tests/main_test.cpp)
# Enlazar el ejecutable con nuestra biblioteca de simulación
target_link_libraries(simulator_test PRIVATE simulator)