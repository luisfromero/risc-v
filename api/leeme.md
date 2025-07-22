Este directorio contendrá el servidor de la API en Python.

main.py: El punto de entrada de tu aplicación FastAPI. Cargará la biblioteca C++ y definirá los endpoints (/step, /state, etc.).
requirements.txt: Un archivo de texto que lista las dependencias de Python (ej. fastapi, uvicorn). Esto hace que sea fácil para cualquiera instalar lo necesario con pip install -r requirements.txt.