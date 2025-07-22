from fastapi import FastAPI
import ctypes

app = FastAPI(
    title="RISC-V Simulator API",
    description="An API to control a C++ based RISC-V Simulator",
    version="1.0.0"
)

# TODO: Cargar la librería C++ compartida (.so o .dll) usando ctypes
# lib_path = "./path/to/your/libsimulator.so"
# simulator_lib = ctypes.CDLL(lib_path)

@app.get("/")
def read_root():
    return {"message": "RISC-V Simulator API is running!"}