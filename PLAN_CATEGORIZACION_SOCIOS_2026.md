# Plan de Categorización de Socios y Control de Aportes (2026)

## Objetivo
Implementar una categorización de socios basada en su fecha de ingreso y un control anual/mensual de aportes para:
- Eximir multas si el socio cumple o está adelantado según el objetivo del mes.
- Aplicar multas solo cuando el socio no alcanza el umbral esperado y además paga/desposa después del día límite.
- Mantener un corte de caja al 31/12/2025 para considerar prepagos y saldos adelantados.

## Parámetros Centrales (2026)
Ubicación: `admin/api/config/parametros_2026.json`
- `anio`: 2026
- `aporte_mensual_base`: 25 (valor base configurable)
- `dia_limite_mensual`: 10 (día tope para no generar multa)
- `fecha_corte_anual_iso`: `2025-12-31T23:59:59Z`
- `fecha_fundacion_iso`: definir por administración
- `categorias`: `fundador|intermedio|nuevo` con criterios por fecha y objetivos de aporte
- `reglas`:
  - `exencion_multa_si_avance_mes_cumplido`: true
  - `exencion_multa_si_adelantado`: true
  - `multa_si_despues_limite_y_avance_insuficiente`: true

## Categorías
- **fundador**: socios con fecha de ingreso anterior a `fecha_fundacion_iso`. Objetivo mensual/ anual definido (por defecto 25/300).
- **intermedio**: socios que ingresaron entre dos fechas (rango). Objetivo por defecto 20/240.
- **nuevo**: socios que ingresaron desde una fecha determinada. Objetivo por defecto 15/180.

Notas:
- Si finalmente se decide uniformizar aportes, todos usan `aporte_mensual_base=25`.
- Los rangos y la fecha de fundación deben ser proporcionados por administración.

## Modelo de Datos (Usuarios)
Ampliar documento de usuario (`usuarios/{uid}`) con:
- `categoria`: `fundador|intermedio|nuevo`
- `fecha_ingreso_iso`: `YYYY-MM-DD` (si no existe, añadir)
- `saldo_corte_2025`: número (suma al 31/12/2025 23:59)
- `avance_anual_2026`: número (acumulado de aportes aprobados 2026)
- `objetivo_anual_2026`: número (ej. 300 para fundador)

## Lógica de Avance y Exenciones
- Para cada mes `m`, el objetivo acumulado esperado `E(m) = aporte_mensual * m`.
- Si `avance_anual_2026 >= E(m)` (al momento del check) → **exención de multa**.
- Si la operación ocurre **antes o en** el día `10` y al completarse el depósito/pago alcanza `E(m)`, **exención**.
- Si la operación ocurre **después** del día `10` y **no** alcanza `E(m)`, **aplica multa** (según reglas vigentes).

## Corte de Caja y Depósitos Adelantados
- Snapshot al `2025-12-31T23:59:59Z`: capturar por usuario `saldo_corte_2025`.
- Cálculo de carry-over: `carryover_2025_a_2026 = max(0, saldo_corte_2025 - objetivo_anual_2025)`.
- En 2026, el avance inicial se fija como `avance_anual_2026 = min(carryover_2025_a_2026, objetivo_anual_2026)`.
- Los depósitos que exceden los objetivos mensuales se registran como **adelantados** y se exime multa subsiguiente mientras se mantenga el plan.

## Endpoints/Comandos a Implementar (backend `admin/api/server.js`)
1. `POST /api/admin/categorizar-socios`:
   - Entrada: criterios de `parametros_2026.json` (opcional si se lee del archivo).
   - Acción: asignar `categoria` por `fecha_ingreso_iso` y setear `objetivo_anual_2026` por usuario.

2. `POST /api/admin/inicializar-corte-2025`:
   - Acción: calcular `saldo_corte_2025` por usuario (agregando movimientos hasta la fecha corte) y ajustar `avance_anual_2026` inicial.

3. Integraciones en flujos existentes:
   - Aprobación de depósitos/pagos: incrementar `avance_anual_2026` y evaluar exención/multa según `E(m)` y `dia_limite_mensual`.
   - Consulta de estado: exponer por usuario `{categoria, avance_anual_2026, objetivo_anual_2026, mes_actual, cumple_mes}`.

## Plan de Pruebas
- **Fundador al día**: paga antes del 10 y alcanza `E(m)`. No multa.
- **Intermedio adelantado**: tiene `avance_anual_2026 >= E(m+1)`. No multa por el siguiente mes.
- **Nuevo con atraso**: deposita después del 10 sin alcanzar `E(m)`. Aplica multa.
- **Corte y ajuste**: usuario con saldo adelantado al cierre 2025; validar que arranca 2026 con `avance_anual_2026` > 0.

## Despliegue y Operativa
- Cargar `parametros_2026.json` y validar.
- Ejecutar `categorizar-socios`.
- Ejecutar `inicializar-corte-2025`.
- Verificar panel de estado por usuario.
- Monitorear multas/exenciones el día 10 de cada mes.

## Notas Finales
- Todos los parámetros son **configurables** y deben poder actualizarse sin cambiar código (idealmente desde Firestore o archivo). 
- La lógica debe ser determinista y auditable: cada decisión de multa/exención debe registrar el motivo y los valores comparados (`avance`, `E(m)`, `dia_operacion`).
