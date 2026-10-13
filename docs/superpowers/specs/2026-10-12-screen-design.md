# Screen — tiempo en pantalla de a dos

**Fecha:** 2026-10-12 · **Estado:** diseño aprobado en chat, pendiente revisión del spec

## 1. Qué es

App iOS para **dos adultos** que se controlan el tiempo en pantalla mutuamente.
Cada uno limita sus propias apps; para aflojar un límite o conseguir minutos
extra, le pide permiso al otro desde el celular, y el otro aprueba desde el suyo.

Nació de este pedido textual: *"le ponemos tiempo en pantalla para ciertas
aplicaciones… él me puede pedir 'dame 5 minutos más para TikTok' y yo le digo
'bueno, te doy 5 minutos más' y desde mi celular pongo 5 minutos más."*

### Lo que el usuario decidió

| Tema | Decisión |
|---|---|
| Quiénes | Dos adultos, control mutuo y simétrico. No es control parental |
| Plataforma | Los dos con iPhone → SwiftUI nativa |
| Cambiar límites | **Endurecer es libre; aflojar requiere aprobación del otro** |
| Tipos de límite | Minutos diarios por grupo de apps **y** horarios de bloqueo |
| Pedido de tiempo | 5 / 15 / 30 min + mensaje opcional; el otro: Dar / Otra cantidad / No |
| Emergencia | Comodín de 5 min de uso por día, sin aprobación, el otro se entera |
| Nombre | **Screen** (listado probable: "Screen: tiempo en pantalla de a dos") |

### Supuestos (corregibles)

- UI en **español rioplatense** (los dos usuarios son argentinos).
- Bundle ID `com.facufuensa.screen`, team `RS6J29JLPS`, como el resto de las apps.
- Es para ellos dos primero; App Store pública queda abierta pero no es v1.

## 2. Restricciones de la plataforma (verificadas en diseño, condicionan todo)

1. **Es por honor.** Con autorización `.individual` (adultos), cualquiera puede
   quitarle el permiso a la app en Ajustes o borrarla. No se puede impedir; se
   **detecta y se avisa** (§6).
2. **Las apps elegidas no se pueden ver en otro celular.** Los `ApplicationToken`
   son opacos y solo resuelven en el dispositivo que los eligió. El otro ve
   nombre del grupo y minutos, no la lista de apps.
3. **No hay historial de uso exportable.** `DeviceActivityReport` corre en un
   sandbox sin red. El otro ve **eventos** (umbrales, pedidos, comodín), no
   minutos exactos de uso.
4. **Las extensiones de shield no tienen red.** El botón "Pedir tiempo" de la
   pantalla de bloqueo no puede mandar el pedido: abre la app con el pedido armado.
5. **Family Controls no funciona en el simulador.** Lo que toca la API se prueba
   en los dos iPhone reales.
6. **Entitlement de distribución.** Para TestFlight/App Store hace falta que Apple
   apruebe *Family Controls (Distribution)* a mano (semanas). Se pide el día 1.
   Mientras tanto: builds de desarrollo con los UDID de los dos iPhone registrados.

## 3. Piezas

| Pieza | Responsabilidad |
|---|---|
| **App** (`Screen`) | Login, emparejamiento por código de 6 dígitos, grupos y horarios, feed, pedidos (mandar y responder) |
| **Monitor** (`DeviceActivityMonitorExtension`) | Contar minutos por grupo, aplicar/quitar shields, aplicar horarios, consumir minutos extra y comodín |
| **Shield config** (`ShieldConfigurationExtension`) | Pantalla de bloqueo con marca Screen: motivo + botones "Pedir tiempo" / "Usar comodín" |
| **Shield action** (`ShieldActionExtension`) | Recibe el toque, escribe la intención en el App Group y dispara notificación local que abre la app |
| **Rules** (Swift package `ScreenCore`) | Lógica pura y testeable: ¿afloja o endurece?, presupuestos del día, vencimientos |
| **Supabase** | Perfiles, pareja, grupos (metadatos), pedidos, feed, tokens APNs; RLS por pareja |
| **Edge function `notify`** | Manda las push (APNs directo) al insertarse/actualizarse pedidos y eventos |
| **Vigilante** (cron en Supabase) | Si un celular no reporta hace 24 h, avisa al otro |

App y extensiones comparten estado por **App Group**
(`group.com.facufuensa.screen`): la selección de apps (tokens codificados), los
límites vigentes y los créditos del día. **Toda la aplicación de límites ocurre
en el dispositivo**; el servidor solo transporta pedidos y avisos.

## 4. Modelo de datos (Supabase)

- `profiles(id, display_name, apns_token, last_seen_at, auth_status)`
- `pairs(id, user_a, user_b, invite_code, created_at)`, máximo una pareja por usuario
- `limit_groups(id, owner, name, app_count, daily_minutes, schedule jsonb, updated_at)`:
  espejo de metadatos para que el otro los vea. Los tokens **no** suben.
- `requests(id, pair_id, from_user, kind, group_id, payload jsonb, message,
  status, granted_minutes, created_at, expires_at, answered_at)`
  - `kind`: `extra_time` | `loosen_limit`
  - `status`: `pending` | `granted` | `denied` | `expired` | `superseded`
- `events(id, pair_id, actor, kind, group_id, data jsonb, created_at)`: el feed
  (`threshold_80`, `limit_reached`, `wildcard_used`, `auth_revoked`, `silent_24h`,
  `limit_tightened`, …)

RLS: cada usuario lee/escribe solo filas de su `pair_id`; solo el destinatario
puede responder un pedido; solo el dueño edita sus `limit_groups`, y aflojar pasa
por `requests` (lo valida un RPC, no solo el cliente).

## 5. Flujos

**Pedir tiempo extra**
1. Se agota el grupo → Monitor aplica shield → pantalla de bloqueo.
2. "Pedir tiempo" → Shield action guarda la intención + notificación local → la
   app abre con el grupo elegido; el usuario elige 5/15/30 y mensaje.
3. Insert en `requests` → `notify` manda push al otro con acciones
   **Dar N / Otra cantidad / No** (acciones de notificación, sin abrir la app).
4. Al aprobar → push al pedidor (silenciosa + visible). La app escribe el crédito
   en el App Group, quita el shield del grupo y arranca un `DeviceActivity`
   con umbral = N minutos **de uso**. Al llegar al umbral, se vuelve a bloquear.
5. Si la push silenciosa no despierta la app, la visible dice "Te dieron 15 min"
   y al tocarla se aplica.

**Aflojar un límite** (subir minutos, sacar apps de un grupo, achicar horario):
mismo circuito con `kind = loosen_limit`; el otro ve el diff ("30 → 60 min").
Hasta la aprobación rige el límite anterior. **Endurecer** se aplica al instante
y solo genera un evento en el feed.

**Comodín:** 5 min de uso por día, disponible desde la pantalla de bloqueo, sin
red. Se registra local y el evento `wildcard_used` sube cuando haya conexión.

## 6. Casos borde

| Caso | Comportamiento |
|---|---|
| Medianoche (hora local del dueño) | Se reinician contadores; extras no usados y comodín vencen |
| Pedido sin respuesta | Vence a los 30 min (`expired`); se puede volver a pedir |
| Pedido nuevo del mismo grupo con uno pendiente | El viejo pasa a `superseded` |
| Sin red | Los límites siguen; pedidos y eventos se encolan y salen al volver |
| Permiso revocado | Al abrir la app o en background refresh se detecta `AuthorizationCenter.status` ≠ aprobado → evento `auth_revoked` |
| App borrada / celu muerto | Sin heartbeat 24 h → Vigilante emite `silent_24h` al otro |
| Se desarma la pareja | Cada uno conserva sus límites locales; se apagan pedidos |

## 7. Pruebas

- `ScreenCore`: tests unitarios de la regla afloja/endurece, presupuestos,
  vencimientos y medianoche (corren en CI, sin dispositivo).
- Supabase: tests de RLS y del RPC de aflojar (un usuario no puede subir su
  límite sin un `request` aprobado).
- Checklist manual en los dos iPhone para todo lo que toca Family Controls
  (shield aparece, pedido llega, crédito se consume, re-bloqueo, comodín, revocación).

## 8. Build y distribución

Igual que Handl: XcodeGen genera el proyecto en CI (no se commitea),
`supabase-swift` 2.55.1 exacto, `SWIFT_VERSION: "5.0"`, iOS 17+, GitHub Actions
con macOS (repo público para no pagar 10x; nada sensible en el repo, y los logs de build
se redactan antes de subirse). Cuatro targets con entitlement Family Controls + App Group.

**Pasos manuales del usuario (día 1):**
1. Pedir el entitlement *Family Controls (Distribution)* a Apple.
2. Registrar los UDID de los dos iPhone.
3. Crear proyecto Supabase y clave APNs.
4. Chequear si "Screen" está libre en la App Store (casi seguro que no → subtítulo).

## 9. Fuera de v1

Android, más de dos personas por grupo, estadísticas detalladas de uso,
widgets, Apple Watch, rachas/gamificación, publicación en App Store.
