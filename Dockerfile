# --- Etapa 1: Builder ---
# Usamos una imagen con las herramientas de compilación de C++
FROM ubuntu:22.04 AS builder

# Evitar prompts interactivos durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias de compilación
RUN apt-get update && apt-get install -y build-essential cmake

# Copiar el código fuente del núcleo
WORKDIR /app
COPY ./core ./core
COPY ./CMakeLists.txt .

# Compilar el proyecto
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release .
RUN cmake --build build

# --- Etapa 2: Final ---
# Usamos una imagen ligera de Python
FROM python:3.10-slim

# Copiar la biblioteca compilada desde la etapa 'builder'
COPY --from=builder /app/build/libsimulator.so /usr/local/lib/libsimulator.so
# Actualizar el caché de enlaces dinámicos para que el sistema encuentre la librería
RUN ldconfig

# Copiar la API de Python y sus dependencias
WORKDIR /app
COPY ./api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./api .

# Exponer el puerto y ejecutar la API
EXPOSE 8070
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8070"]