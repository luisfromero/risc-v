# Troubleshooting - Solución de Problemas

## Problemas con caché de paquetes de Flutter

### Síntomas
- Errores recurrentes con paquetes como `file_picker`, `window_manager`, etc.
- Mensajes de error sobre archivos `.dart` generados automáticamente
- Comportamiento inconsistente después de actualizar dependencias
- Los breakpoints no funcionan en modo debug

### Solución: Limpieza completa de caché

Ejecuta estos comandos desde el directorio `simulator_ui`:

```powershell
# 1. Limpiar el proyecto local
flutter clean

# 2. Limpiar TODA la caché de paquetes de Flutter (requiere confirmación)
flutter pub cache clean

# 3. Reinstalar las dependencias
flutter pub get

# 4. Ejecutar la aplicación
flutter run -d chrome    # Para web
# o
flutter run -d windows   # Para Windows nativo
```

### Notas importantes

- **`flutter pub cache clean`** elimina TODOS los paquetes descargados globalmente en:
  ```
  C:\Users\<usuario>\AppData\Local\Pub\Cache
  ```
  
- Después de este comando, **todos tus proyectos Flutter** necesitarán descargar sus dependencias de nuevo.

- Es normal ver algunos warnings sobre archivos bloqueados en `ephemeral` o `.dart_tool`. Estos se resolverán en la siguiente ejecución.

### Si el problema persiste

1. **Cierra VS Code completamente**
2. **Elimina manualmente las carpetas bloqueadas**:
   ```powershell
   cd D:\onedrive\proyectos\riscv\simulator_ui
   Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force windows\flutter\ephemeral -ErrorAction SilentlyContinue
   ```
3. **Vuelve a ejecutar**:
   ```powershell
   flutter pub get
   flutter run
   ```

## Diferencias entre modos de ejecución

### Chrome (`flutter run -d chrome`)
- **Ventajas**: Hot reload más rápido, ideal para desarrollo
- **Limitaciones**: `window_manager` no funciona (es web, no escritorio)
- **Breakpoints**: Funciona con DevTools de Chrome

### Windows (`flutter run -d windows`)
- **Ventajas**: Aplicación nativa, `window_manager` funciona correctamente
- **Limitaciones**: Compilación inicial más lenta
- **Breakpoints**: Funciona con el debugger de VS Code

---

*Última actualización: Noviembre 2025*
