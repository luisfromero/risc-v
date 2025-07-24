Este directorio contendrá el servidor de la API en Python.

*   `main.py`: El punto de entrada de la aplicación FastAPI.
    *   Usa la biblioteca `ctypes` de Python para cargar la biblioteca compartida C++ (`.dll` o `.so`).
    *   Define una interfaz C para las funciones del simulador.
    *   Envuelve la lógica C++ en una clase Python `Simulator` para un manejo más sencillo.
    *   Define los endpoints de la API REST (`/state`, `/step`) para interactuar con el simulador.
*   `requirements.txt`: Un archivo de texto que lista las dependencias de Python (ej. `fastapi`, `uvicorn`). Esto hace que sea fácil para cualquiera instalar lo necesario con `pip install -r requirements.txt`.