# Simulador Didáctico de RISC-V

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Language](https://img.shields.io/badge/language-C++%20%7C%20Python%20%7C%20Dart-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Una plataforma modular y didáctica para la simulación de la arquitectura de conjunto de instrucciones (ISA) **RISC-V**. El proyecto está diseñado con una arquitectura de microservicios, incluyendo un núcleo de simulación de alto rendimiento en C++, APIs en Python (FastAPI) y una interfaz gráfica interactiva en Flutter.

![Captura de pantalla del simulador](images/ui_addi.jpg?raw=true)

El objetivo principal es crear una herramienta flexible para aprender sobre la arquitectura de computadores, con aplicaciones prácticas como la preparación de exámenes (inspirado en el proyecto CASIUM) o la visualización del flujo de ejecución de un programa a bajo nivel.

## 🚀 Características Clave

*   **Arquitectura de Microservicios:** Componentes desacoplados (simulador, API, servicio de exámenes) para mayor escalabilidad y mantenibilidad.
*   **Núcleo en C++:** Simulación de bajo nivel de la CPU, memoria y registros para obtener el máximo rendimiento.
*   **API RESTful (FastAPI):** Una interfaz moderna y desacoplada para controlar el simulador de forma remota, permitiendo la conexión de múltiples clientes.
*   **Contenerización con Docker:** Todo el sistema está orquestado con Docker y Docker Compose para una configuración y despliegue sencillos en cualquier entorno.
*   **Interfaz Gráfica Interactiva (Flutter):** Una UI de escritorio moderna que visualiza el datapath en tiempo real, resaltando los componentes y buses activos en cada ciclo.
*   **Módulo de Exámenes (En desarrollo):** Un servicio dedicado para crear, gestionar y evaluar exámenes online, similar a la plataforma CASIUM.
*   **Soporte RV32I:** Implementación progresiva del conjunto de instrucciones base de 32 bits para enteros.

## 🏗️ Arquitectura del Proyecto

El proyecto sigue una filosofía de separación de incumbencias, orquestada a través de Docker.

1.  **`core/` (C++):** El corazón del simulador. Contiene la lógica pura de la máquina RISC-V y se compila como una librería compartida (`.so` o `.dll`). No sabe nada sobre APIs o interfaces de usuario.
2.  **`api/` (Python + FastAPI):** Un microservicio que carga la librería del `core` y la expone a través de una API REST. Gestiona las peticiones, serializa los datos a JSON y se comunica con los clientes.
3.  **`exam_service/` (Futuro):** Un microservicio independiente que gestionará la lógica de los exámenes, usuarios y calificaciones.
4.  **`simulator_ui/` (Flutter):** Una interfaz gráfica de escritorio que se comunica directamente con la API del simulador para una visualización detallada del datapath.
5.  **`frontend/` (Futuro):** Directorio destinado a albergar la interfaz web principal que consumirá tanto la API del simulador como la del servicio de exámenes.
6.  **`docker-compose.yml`:** El fichero principal que define y orquesta todos los servicios para un despliegue unificado.

## 🐳 Instalación y Uso con Docker (Recomendado)

La forma más sencilla de ejecutar toda la plataforma sin preocuparse por las dependencias locales.

### Prerrequisitos
*   Docker
*   Docker Compose

### Pasos

1.  **Clonar el repositorio:**
    ```bash
    git clone https://github.com/luisfromero/risc-v.git
    cd risc-v.git
    cd riscv
    ```

2.  **Construir y ejecutar los contenedores:**
    Desde la raíz del proyecto, ejecuta:
    ```bash
    docker-compose up --build
    ```
    Este comando construirá las imágenes de cada servicio (incluyendo la compilación del núcleo C++) y los levantará.

3.  **Acceder a los servicios:**
    *   **API del Simulador:** `http://localhost:8000`
    *   **Documentación de la API (Swagger UI):** `http://localhost:8000/docs`

## 🛠️ Desarrollo Local (Alternativo)

Si prefieres ejecutar los servicios de forma nativa para desarrollo.

### Prerrequisitos
*   Compilador C++ (GCC/Clang/MSVC)
*   CMake (>= 3.10)
*   Python (>= 3.10)
*   Flutter SDK (>= 3.0)

### Pasos

1.  **Compilar el núcleo C++:**
    ```bash
    # Desde la raíz del proyecto
    cmake -S core -B core/build
    cmake --build core/build
    ```
    Esto generará la librería compartida en `core/build/`.

2.  **Ejecutar la API del Simulador:**
    ```bash
    # Navegar al directorio de la API
    cd api

    # (Recomendado) Crear y activar un entorno virtual
    python -m venv venv
    source venv/bin/activate  # En Linux/macOS
    # venv\Scripts\activate    # En Windows

    # Instalar dependencias
    pip install -r requirements.txt

    # Iniciar el servidor
    uvicorn main:app --reload
    ```

3.  **Ejecutar la Interfaz Gráfica (Flutter):**
    ```bash
    # Navegar al directorio de la UI
    cd simulator_ui
    
    # Ejecutar la aplicación (asume que la API está corriendo)
    flutter run
    ```

## 🗺️ Roadmap y Futuras Ideas

- [ ] **Servicio de Exámenes:** Implementar la lógica para crear, realizar y calificar exámenes.
- [ ] **Frontend Web:** Desarrollar una interfaz web con React/Vue para interactuar con la plataforma.
- [ ] **API Gateway:** Introducir un API Gateway para gestionar el enrutamiento y la autenticación de forma centralizada.
- [ ] **Autenticación de Usuarios:** Añadir un sistema de registro y login.
- [ ] **Persistencia de Datos:** Integrar una base de datos (ej. PostgreSQL) para los servicios que lo requieran.
- [ ] **Completar RV32IM:** Implementar el conjunto de instrucciones base y la extensión 'M'.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor, abre un *issue* para discutir cambios importantes antes de realizar un *pull request*.

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.