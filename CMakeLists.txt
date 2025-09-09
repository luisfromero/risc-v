# Versión mínima de CMake requerida
cmake_minimum_required(VERSION 3.10)

# Nombre del proyecto
project(riscv_simulator VERSION 1.0)

# Usar el estándar C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)



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

# Indicar a CMake dónde encontrar los archivos de cabecera (.h) para el target "simulator".
# Usamos PUBLIC para que los targets que enlacen con "simulator" (como simulator_test)
# también tengan acceso a estos encabezados.
target_include_directories(simulator PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/core/include)

# --- Sección para Tests y Depuración ---
# Habilitar los tests
enable_testing()

# Añadir un ejecutable para pruebas y depuración
add_executable(simulator_test tests/main_test.cpp)
# Enlazar el ejecutable con nuestra biblioteca de simulación
target_link_libraries(simulator_test PRIVATE simulator)
