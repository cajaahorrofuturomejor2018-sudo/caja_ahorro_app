# Reglas de seguridad Firestore y despliegue

Este archivo explica cómo probar y desplegar las reglas de seguridad incluidas en `firestore.rules`.

Propuesta principal:
- Permitir lecturas a usuarios autenticados.
- Permitir operaciones administrativas (aprobaciones, cambios de rol, configuración) sólo a usuarios cuyo documento `/usuarios/{uid}` tenga `rol == 'admin'`.

Archivos añadidos:
- `firestore.rules` — reglas que debes revisar antes de desplegar.

Probar localmente con el emulador (recomendado):

1. Inicia el emulador de Firestore (requiere instalar Firebase CLI y configurar `firebase init emulators` si no lo hiciste):

```powershell
# en la carpeta del proyecto (donde está firebase.json si existe)
firebase emulators:start --only firestore
```

2. Usa la consola del emulador (http://localhost:4000 por defecto) para inspeccionar datos y reglas.

Desplegar las reglas a Firebase (producción):

1. Asegúrate de estar autenticado en Firebase CLI:

```powershell
firebase login
```

2. Despliega sólo las reglas de Firestore:

```powershell
firebase deploy --only firestore:rules
```

Notas y recomendaciones:
- Revisa la colección `usuarios` y sus campos: las reglas esperan que exista un documento por cada usuario con campo `rol`.
- Estas reglas son un punto de partida. Ajusta lecturas/escrituras según tus necesidades (por ejemplo, restringir `movimientos` para que sólo se lean por el propio usuario o por roles específicos).
- Después de desplegar, prueba las rutas administrativas con una cuenta `admin` para verificar permisos.
