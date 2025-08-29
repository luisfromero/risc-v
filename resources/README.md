## Generador de Programas por Defecto

Este directorio contiene el script para generar los programas binarios por defecto que se usan tanto en la API de Python como en la UI de Flutter.

### `generate_program.py`

Este script es la **única fuente de verdad** para los programas por defecto.

**¿Qué hace?**

1.  Contiene los programas binarios (`PROGRAM_A` y `PROGRAM_B`) como objetos `bytes` de Python.
2.  Genera dos archivos de salida:
    -   `api/src/program_data.py`: Contiene los binarios para ser usados por la API de FastAPI.
    -   `simulator_ui/lib/generated/program_data.g.dart`: Contiene los binarios para ser usados por la UI de Flutter.

**¿Cómo usarlo?**

1.  Modifica los bytearrays `PROGRAM_A` o `PROGRAM_B` en `generate_program.py`.
2.  Ejecuta el script desde el directorio raíz del proyecto (`riscv/`):
    ```bash
    python resources/generate_program.py
    ```
3.  Esto actualizará automáticamente los archivos en la API y la UI.

Cualquier cambio en los programas por defecto debe hacerse aquí y luego regenerar los archivos.