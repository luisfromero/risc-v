# Simulador RISC-V

Este proyecto es un simulador funcional de un procesador RISC-V con una interfaz gráfica de usuario moderna. Permite visualizar el flujo de datos a través del datapath, inspeccionar registros y memoria, y ejecutar programas paso a paso.

## Estructura del Proyecto

El proyecto está dividido en varios componentes principales:

-   `core/`: Contiene el núcleo del simulador implementado en C++. Es una librería de alto rendimiento que se encarga de la lógica de la CPU.
-   `api/`: Una API web construida con Python y FastAPI que expone la funcionalidad del núcleo C++ a través de una interfaz REST.
-   `simulator_ui/`: La interfaz de usuario, desarrollada con Flutter, que se comunica con la API para visualizar el estado del simulador y controlar su ejecución.
-   `tests/`: Contiene los tests unitarios para el núcleo del simulador.

## Preparación del Entorno de Desarrollo

Sigue estos pasos para configurar tu entorno y poder compilar y ejecutar el proyecto.

### 1. Prerrequisitos

Asegúrate de tener instaladas las siguientes herramientas en tu sistema:

-   **Git:** Para clonar el repositorio.
-   **Compilador de C++:**
    -   **Windows:** Visual Studio con el workload "Desarrollo para el escritorio con C++".
    -   **macOS:** Xcode Command Line Tools.
    -   **Linux:** `build-essential` o un paquete similar que incluya `g++`.
-   **CMake:** Versión 3.15 o superior.
-   **Flutter SDK:** Versión 3.10 o superior. Instrucciones de instalación.
-   **Python:** Versión 3.8 o superior.

### 2. Configuración del Núcleo C++ (`core/`)

El núcleo del simulador se compila como una librería que es utilizada por la API de Python.

1.  Abre una terminal en la raíz del proyecto.
2.  Crea una carpeta de compilación y configúrala con CMake:
    ```bash
    cmake -S . -B build
    ```
3.  Compila el núcleo:
    ```bash
    cmake --build build
    ```
    Esto generará la librería compartida (un `.dll` en Windows, `.so` en Linux, `.dylib` en macOS) dentro de la carpeta `build/`.

### 3. Configuración de la API Python (`api/`)

La API actúa como puente entre el núcleo C++ y la interfaz de Flutter.

1.  Navega a la carpeta `api`:
    ```bash
    cd api
    ```
2.  Crea y activa un entorno virtual de Python:
    -   **Windows:**
        ```bash
        python -m venv venv
        .\venv\Scripts\activate
        ```
    -   **macOS / Linux:**
        ```bash
        python3 -m venv venv
        source venv/bin/activate
        ```
3.  Instala las dependencias (asumiendo que tienes un archivo `requirements.txt`):
    ```bash
    pip install -r requirements.txt
    ```

### 4. Configuración de la Interfaz Flutter (`simulator_ui/`)

La interfaz gráfica te permite interactuar con el simulador.

1.  Navega a la carpeta `simulator_ui`:
    ```bash
    cd simulator_ui
    ```
2.  Obtén las dependencias de Flutter:
    ```bash
    flutter pub get
    ```

## Cómo Ejecutar la Aplicación Completa

1.  **Inicia el backend:**
    -   Asegúrate de estar en la carpeta `api/` con el entorno virtual activado.
    -   Ejecuta el servidor:
        ```bash
        uvicorn main:app --host 0.0.0.0 --port 8000 --reload
        ```
2.  **Inicia la interfaz:**
    -   Abre otra terminal y navega a la carpeta `simulator_ui/`.
    -   Ejecuta la aplicación de Flutter (puedes elegir la plataforma):
        ```bash
        # Para web
        flutter run -d chrome

        # Para escritorio (Windows/macOS/Linux)
        flutter run -d windows # o macos, o linux
        ```

## Pruebas

La carpeta `tests/` está dedicada a los tests unitarios del núcleo C++. Para más información sobre cómo ejecutar y añadir nuevos tests, consulta el archivo `tests/leeme.md`.