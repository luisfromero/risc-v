# Versión mínima de CMake requerida
cmake_minimum_required(VERSION 3.10)

# Nombre del proyecto
project(riscv_simulator VERSION 1.0)

# --- Gestión de Dependencias (nlohmann/json) ---
# Incluimos el módulo FetchContent para descargar dependencias en tiempo de configuración.
include(FetchContent)

# Declaramos la dependencia. CMake la descargará si no está ya disponible.
FetchContent_Declare(
  nlohmann_json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG v3.11.3 # Usamos una versión específica para asegurar la estabilidad
  # Solución para problemas de certificados SSL en entornos corporativos o con proxies
  GIT_CONFIG "http.sslVerify=false"
)
# Hacemos que la dependencia esté disponible para ser usada por nuestros targets.
FetchContent_MakeAvailable(nlohmann_json)

# Usar el estándar C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Indicar a CMake dónde encontrar los archivos de cabecera (.h) para TODO el proyecto.
# Al hacerlo aquí, cualquier target (simulator, simulator_test, etc.) heredará esta ruta.
# Esto es crucial para que IntelliSense de VS Code funcione correctamente.
include_directories(core/include)


# Lista explícita de archivos fuente. Es la práctica moderna recomendada
# en lugar de aux_source_directory, ya que es más claro para los IDEs y
# garantiza que el proyecto se reconfigure si se añaden o quitan ficheros.
set(CORE_SOURCES
    core/src/Simulator.cpp
    core/src/Api.cpp
    core/src/Memory.cpp
    core/src/RegisterFile.cpp
    core/src/ControlUnit.cpp
    core/src/ALU.cpp
    core/src/SignExtender.cpp
    core/src/Mux.cpp
    core/src/Adder.cpp
    core/src/Cache.cpp
    core/src/Assembler.cpp
)

# Crear una biblioteca COMPARTIDA (SHARED -> .so o .dll) llamada "simulator"
# a partir de los archivos fuente encontrados.
add_library(simulator SHARED ${CORE_SOURCES})

# Para Windows, es necesario definir un macro para exportar los símbolos de la DLL.
# Esto asegura que se genere el archivo .lib necesario para el enlazado.
if(WIN32)
    target_compile_definitions(simulator PRIVATE SIMULATOR_EXPORTS)
endif()

# Enlazamos la librería del simulador con nlohmann_json.
# Al ser una librería de solo cabeceras, esto simplemente añade su directorio de includes.
target_link_libraries(simulator PUBLIC nlohmann_json::nlohmann_json)

# --- Sección para Tests y Depuración ---
# Habilitar los tests
enable_testing()

# Añadir un ejecutable para pruebas y depuración
add_executable(simulator_test tests/main_test.cpp)
# Enlazar el ejecutable con nuestra biblioteca de simulación
target_link_libraries(simulator_test PRIVATE simulator)
