# RISC-V Simulator UI

Este proyecto es una interfaz gráfica de usuario (GUI) interactiva y didáctica para el [Simulador de RISC-V](../README.md), construida con el framework Flutter. Su objetivo principal es visualizar el flujo de datos y las señales de control dentro de un procesador RISC-V de ciclo único, facilitando el aprendizaje de la arquitectura de computadores.

![Captura de pantalla del simulador](../images/ui_addi.jpg?raw=true)

## 🚀 Características Principales

*   **Visualización Interactiva del Datapath:** Muestra un diagrama completo del camino de datos de un procesador RISC-V, incluyendo PC, ALU, memorias, multiplexores y banco de registros.
*   **Resaltado de Estado en Tiempo Real:** Los componentes y buses se "iluminan" cuando están lógicamente activos y sus datos están listos en el ciclo de reloj actual. Esto permite identificar visualmente qué partes del procesador se usan para cada instrucción.
*   **Trazado del Flujo de Datos:** Los buses activos muestran el valor hexadecimal que transportan, permitiendo seguir el flujo de la información a través del datapath.
*   **Slider de Tiempo Intra-Ciclo:** Una característica única que permite al usuario "viajar en el tiempo" dentro de un único ciclo de reloj. Al mover el slider, se puede observar cómo las señales se propagan y los componentes se activan progresivamente según sus retardos.

![Captura de pantalla del simulador](../images/ui_beq.jpg?raw=true)


*   **Comunicación Directa con el Núcleo:** Utiliza `dart:ffi` para conectarse directamente con la librería nativa del simulador (escrita en C++), garantizando un alto rendimiento y una representación fiel de la simulación.
*   **Controles Sencillos:** Permite ejecutar la simulación paso a paso con los botones "Clock Tick" y "Reset".

## 🛠️ Cómo Funciona

La interfaz está construida sobre varios pilares clave de Flutter:

1.  **Gestión de Estado con `Provider`:** La clase `DatapathState` actúa como el estado central de la aplicación, notificando a la UI cada vez que el backend envía nueva información.
2.  **Dibujo Personalizado con `CustomPainter`:** La clase `BusesPainter` es la responsable de dibujar dinámicamente todos los buses y flechas que conectan los componentes. Lee las coordenadas de los widgets en tiempo real para asegurar que las conexiones siempre sean correctas.
3.  **Interoperabilidad con `dart:ffi`:** El servicio `FfiSimulationService` define y carga las funciones de la librería nativa (`simulator.dll` en Windows o `libsimulator.so` en Linux/macOS), permitiendo una comunicación directa y eficiente con el núcleo C++.

----
## ⚙️ Ejecución

Para ejecutar la interfaz, es necesario haber compilado primero el núcleo del simulador.

1.  **Compilar el Núcleo C++:** Sigue las instrucciones del README principal para compilar el proyecto `core`. Esto generará la librería `simulator.dll` (Windows) o `libsimulator.so` (Linux/macOS).

2.  **Colocar la Librería:** Asegúrate de que la librería compilada se encuentre en el directorio `simulator_ui/build/windows/runner/Debug` (o la ruta equivalente para tu sistema operativo y modo de compilación). Flutter buscará la librería en la ruta de ejecutables de la aplicación.

3.  **Ejecutar la App Flutter:** Desde el directorio `simulator_ui`, ejecuta el siguiente comando:
    ```bash
    flutter run
    ```


