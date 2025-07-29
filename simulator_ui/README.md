# RISC-V Simulator UI

Este proyecto Flutter es la interfaz gráfica (GUI) para un simulador de procesador RISC-V. Su objetivo es visualizar el estado interno del simulador y permitir una ejecución controlada paso a paso.

## Propósito

La aplicación se comunicará con el núcleo del simulador (escrito en C++) a través de una DLL (Dynamic-Link Library) utilizando `dart:ffi`. Esto permitirá que la lógica de la simulación se mantenga separada de su representación visual.

## Funcionalidades Planeadas

La interfaz de usuario ofrecerá controles para ejecutar la simulación a diferentes niveles de granularidad, por ejemplo:

-   **Siguiente Ciclo de Reloj:** Avanzar la simulación un único ciclo de reloj.
-   **Siguiente Instrucción:** Completar la ejecución de la instrucción actual.
-   **Siguiente Etapa:** Avanzar una etapa en el pipeline (en caso de un diseño segmentado) o fase (en el monociclo).

La implementación final de estos controles dependerá del diseño del procesador subyacente (monociclo, multiciclo o segmentado).

---

## Getting Started

*Esta sección es la original generada por Flutter y se mantiene como referencia.*

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
