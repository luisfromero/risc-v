# Simulador Didáctico de RISC-V

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Language](https://img.shields.io/badge/language-C++%20%7C%20Python-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Un simulador modular y didáctico de la arquitectura de conjunto de instrucciones (ISA) **RISC-V**. El proyecto está diseñado con un núcleo de alto rendimiento en C++ y una API REST en Python, permitiendo la conexión de múltiples interfaces de usuario (web, escritorio, móvil).

El objetivo principal es crear una herramienta flexible para aprender sobre la arquitectura de computadores, con aplicaciones prácticas como la preparación de exámenes (inspirado en el proyecto CASIUM) o la visualización del flujo de ejecución de un programa a bajo nivel.

## 🚀 Características Clave

*   **Núcleo en C++:** Simulación de bajo nivel de la CPU, memoria y registros para obtener el máximo rendimiento.
*   **API RESTful:** Una interfaz moderna y desacoplada (usando **FastAPI**) para controlar el simulador de forma remota.
*   **Modularidad Extrema:** El núcleo es una biblioteca compartida (`.so` o `.dll`), lo que permite reutilizarlo en cualquier tipo de aplicación.
*   **Soporte RV32I:** Implementación progresiva del conjunto de instrucciones base de 32 bits para enteros.
*   **Configuración Sencilla:** Preparado para compilar y depurar fácilmente con **VS Code** y **CMake**.
*   **Dockerizado:** Totalmente containerizado con **Docker** y **Docker Compose** para un despliegue y ejecución universales.
*   **Definición por Datos:** Las instrucciones se definen en un archivo `resources/instructions.json`, abriendo la puerta a la metaprogramación y a la fácil extensión del simulador.

## 🏗️ Arquitectura del Proyecto

El proyecto sigue una filosofía de separación de incumbencias:

1.  **`core/` (C++):** El corazón del simulador. Contiene la lógica pura de la máquina RISC-V. No sabe nada sobre web, APIs o interfaces de usuario. Su única misión es ejecutar código RISC-V correctamente.
2.  **`api/` (Python):** Un servidor web ligero que carga la biblioteca C++ y la expone al mundo a través de una API REST. Gestiona las peticiones HTTP, serializa los datos a JSON y se comunica con los frontends.
3.  **`resources/`:** Activos y datos compartidos. El fichero `instructions.json` es la "única fuente de la verdad" sobre las instrucciones soportadas.
4.  **`frontends/` (Futuro):** Directorio destinado a albergar las diferentes interfaces de usuario (una aplicación web con React/Vue, una app de escritorio con .NET/C#, etc.).

## 🛠️ Instalación y Uso (Local)

### Prerrequisitos
*   Un compilador de C++ (GCC/g++, Clang o MSVC)
*   CMake (versión 3.10+)
*   Python (versión 3.10+)
*   Git

### Pasos

1.  **Clonar el repositorio:**
    ```bash
    git clone <URL-DEL-REPOSITORIO>
    cd riscv-simulator
    ```

2.  **Compilar el núcleo C++:**
    Usa CMake para generar los archivos de compilación y compilar la biblioteca.
    ```bash
    # Crear el directorio de compilación
    cmake -B build .

    # Compilar el proyecto
    cmake --build build
    ```
    Esto generará la biblioteca `libsimulator.so` (en Linux/macOS) o `simulator.dll` (en Windows) dentro del directorio `build/`.

3.  **Ejecutar la API de Python:**
    Se recomienda usar un entorno virtual.
    ```bash
    # Navegar al directorio de la API
    cd api

    # Crear y activar el entorno virtual
    python -m venv venv
    # En Linux/macOS:
    source venv/bin/activate
    # En Windows:
    .\venv\Scripts\activate

    # Instalar dependencias
    pip install -r requirements.txt

    # Iniciar el servidor (se recargará automáticamente con los cambios)
    uvicorn main:app --reload
    ```
    La API estará disponible en `http://localhost:8000`.

## 🐳 Uso con Docker

La forma más sencilla de ejecutar el proyecto sin preocuparse por las dependencias locales.

### Prerrequisitos
*   Docker
*   Docker Compose

### Pasos

1.  **Construir y ejecutar el contenedor:**
    Desde la raíz del proyecto, ejecuta:
    ```bash
    docker-compose up --build
    ```
2.  La API estará disponible en `http://localhost:8000` y el código de la API se sincronizará en tiempo real gracias al volumen montado.

## 🗺️ Roadmap y Futuras Ideas

- [ ] **Completar RV32I:** Implementar el conjunto de instrucciones base al completo.
- [ ] **Extensión 'M':** Añadir soporte para las instrucciones de multiplicación y división.
- [ ] **Frontend Web:** Desarrollar una interfaz web interactiva para visualizar los registros, la memoria y la ejecución paso a paso.
- [ ] **Ensamblador/Desensamblador:** Crear herramientas para convertir código ensamblador a binario y viceversa directamente desde la aplicación.
- [ ] **Sistema de Depuración:** Añadir soporte para *breakpoints* y ejecución controlada.
- [ ] **Generador de Exámenes:** Desarrollar la lógica para crear y evaluar pruebas basadas en la ejecución de código en el simulador.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor, abre un *issue* para discutir cambios importantes antes de realizar un *pull request*.

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.