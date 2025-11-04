Dónde colocar imágenes de prueba para ML/OCR

Propósito
- Guardar ejemplos de comprobantes (facturas/recibos) para probar y entrenar heurísticas OCR localmente.
- Estos archivos no deberían subirse al repositorio (contienen datos sensibles).

Estructura recomendada

- local_samples/
  - receipts/       # imágenes .jpg/.png/.pdf para pruebas locales

Ejemplo de ruta (relativa al repo):
- local_samples/receipts/mi-comprobante-001.jpg

Buenas prácticas
- NO subir imágenes reales con datos personales o financieros.
- Mantener `local_samples/` en `.gitignore` (ya configurado).
- Si necesitas compartir muestras, depura o anonimiza los datos antes de salir del entorno local.

Cómo usar estas imágenes en desarrollo

1) Coloca tus imágenes en `local_samples/receipts/`.
2) Desde la app en modo debug (o desde un script de pruebas), llama al helper ML que acepta una `File` o la ruta local para procesarlas.

Ejemplo (Dart) — uso de helper local (si está disponible en `MlService`):

final file = File('local_samples/receipts/mi-comprobante-001.jpg');
final result = await MlService.instance.analyzeImageFromFile(file);
print(result);

Opciones para compartir muestras entre el equipo
- Prefiere almacenar muestras en un recurso privado (Drive/Share) con acceso controlado o usar un repositorio privado con LFS si se requiere versionado.

Seguridad y privacidad
- Tratar estas imágenes como datos sensibles.
- Anonimizar o sintetizar datos cuando sea posible.

Si quieres, puedo:
- Añadir en el código un helper `analyzeImageFromFile(File)` en `lib/core/services/ml_service.dart` para facilitar pruebas locales.
- Crear un pequeño ejemplo de test que recorra `local_samples/receipts` y ejecute el OCR en cada archivo.
cfdxwv