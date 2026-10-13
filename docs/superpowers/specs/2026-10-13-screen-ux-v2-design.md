# Screen — UX v2 (después de la primera prueba real)

**Fecha:** 2026-10-13 · **Estado:** diseño aprobado en chat, pendiente revisión del spec
**Reemplaza** la estructura de navegación y la edición de límites del spec
`2026-10-12-screen-design.md`. Las reglas de negocio de ese spec siguen vigentes.

## 1. Por qué

Primera prueba con dos iPhone (Facundo y Miranda, build TestFlight 2.1, 2026-10-13):

- *"Me costó un montón entender toda la aplicación."* La app arranca en el login sin
  explicar la idea.
- *"No sabíamos qué límite le estaba poniendo, si el mío o el de ella."* Los límites de
  los dos estaban en la misma lista con apenas un subtítulo de diferencia.
- *"Apretaba, apretaba y no se aceptaba."* La base registró **6 pedidos de aflojar en 9
  segundos** (13:07:05–13:07:14): "Guardar" mandaba un pedido sin decirlo con claridad, y
  cada toque mandaba otro que reemplazaba al anterior. Los pedidos que sí se respondieron
  tardaron 85 s y 70 s (tiempo humano de Miranda) y se aplicaron 4–6 s después: el
  circuito técnico anda, lo que falla es que no se ve.

## 2. Decisiones del usuario

| Tema | Decisión |
|---|---|
| Quién decide los límites | **Igual que hoy:** cada uno los suyos; bajar es libre, subir lo aprueba el otro |
| Navegación | **Dos pestañas: "Yo" y "<nombre de la dupla>"** |
| Edición | **Un solo editor que avisa antes de tocar** qué va a pasar |
| Pestaña de la dupla | **Todo lo de la otra persona ahí:** pedidos pendientes arriba, sus límites, lo último |
| Primera vez | **Recorrido guiado interactivo:** se ilumina el control, el paso avanza al hacer la acción |

## 3. Navegación

`HomeView` pasa a un `TabView` de dos pestañas (reemplaza Límites / Pedidos / Actividad):

- **Yo** (`hourglass`) — color coral.
- **<Nombre>** (`person.fill`), o **"Tu dupla"** sin pareja — color ámbar. Badge = pedidos
  entrantes pendientes.

La fase `.unpaired` deja de ser una pantalla aparte: después de los permisos se entra
siempre a `HomeView`. Sin dupla, la segunda pestaña muestra el contenido de invitación
(código, compartir, "¿Te pasaron un código?") que hoy vive en `PairingView`.
El título de navegación es la pestaña ("Yo" / el nombre), no "Vos y Ana".

### 3.1 Pestaña "Yo"
1. Botón principal **"Pedirle tiempo a <nombre>"** (deshabilitado sin dupla, con la nota
   "Primero invitá a tu dupla").
2. **Tus límites:** una tarjeta por grupo con borde coral, nombre, resumen (minutos /
   horario / N apps) y un estado:
   - **Bloqueado ahora** (coral) cuando `shouldShield`;
   - **Esperando a <nombre> · 45 → 75 min** (ámbar) si hay un pedido de aflojar pendiente,
     con botón **Cancelar pedido**;
   - **Activo** en otro caso.
3. **Nuevo límite** (tarjeta punteada) mientras haya menos de 5.

### 3.2 Pestaña de la dupla
1. **"Te pide · esperando tu respuesta"** — tarjetas destacadas (borde ámbar) para cada
   pedido entrante pendiente: extra (Dar N / Otra / No) o aflojar (diff + Aprobar / No).
   Los botones se deshabilitan apenas se tocan hasta que vuelve la respuesta.
2. **Sus límites** — tarjetas con borde ámbar y estado ("Llegó al límite hoy" si hubo
   `limit_reached` hoy para ese grupo).
3. **Lo último** — los últimos 10 eventos de los dos, con la redacción de `FeedWording`.
4. Sin dupla: el contenido de invitación (§3).

## 4. Editor de límites

Un solo editor (`GroupEditorView`), pero con **vista previa del efecto**:

- Debajo de los controles, una nota calculada en vivo con `LimitChange.classify`:
  - `tightening` / alta nueva → verde: *"Menos tiempo: se aplica al instante."*
  - `loosening` con dupla → ámbar: *"Más tiempo: <nombre> tiene que aprobarlo. Hasta
    entonces seguís con <valor actual>."*
  - `unchanged` → sin nota, botón deshabilitado (salvo cambio de nombre).
- El botón principal cambia: **Guardar** (coral) o **Pedirle a <nombre>** (ámbar).
- Al tocar, el botón muestra un `ProgressView` y queda deshabilitado hasta el resultado
  (no hay forma de mandar dos).
- Si el grupo ya tiene un pedido de aflojar pendiente, el editor abre en solo lectura con
  la nota *"Ya le pediste a <nombre> 45 → 75 min."* y **Cancelar pedido**.

El texto de la nota sale de una función pura nueva en `ScreenCore`:
`ChangePreview.message(old:new:partnerName:) -> (tone, text)?`, con tests.

## 5. Cancelar un pedido propio (servidor)

Migración nueva:
- `requests.status` admite **`'cancelled'`** (cambiar el `check`).
- RPC `cancel_request(p_request_id uuid) returns void`: solo `from_user = auth.uid()`,
  solo si `status = 'pending'`; si no, `raise exception 'not_pending'`.
- `answer_request` sobre uno cancelado ya falla con `not_pending` (sin cambios).

Cliente: `RequestStatus.cancelled` en `ScreenCore`; `SyncService.dropAnsweredEdits`
también descarta las ediciones de pedidos cancelados; `answeredRequestPayload` no manda
push para `cancelled`. Tests pgTAP y de Deno para lo nuevo.

## 6. Recorrido guiado

### 6.1 Mecánica
- `TourController` (`ObservableObject`, en `Screen/Tour/`) con `currentStep: TourStep?`,
  persistido en `UserDefaults` (`tourStep`, `tourDone`). `complete(_ step)` avanza solo si
  `step == currentStep`.
- Modificador `.tourAnchor(_ step: TourStep)` que publica el frame del control con
  `anchorPreference`.
- `TourOverlay` en la raíz: atenúa toda la pantalla (`Color.black.opacity(0.6)`) con un
  **recorte** redondeado alrededor del ancla (relleno even-odd), borde ámbar, y un globo
  blanco arriba o abajo según el espacio, con título, texto, "Paso N de 7" y **Saltear**.
- El recorte **deja pasar los toques** solo dentro del ancla; fuera de ella los toques
  se bloquean (el usuario no se pierde).
- Los pasos avanzan **por la acción real**, nunca con un botón "Siguiente".

### 6.2 Pasos

| # | Pantalla | Se ilumina | Globo | Avanza cuando |
|---|---|---|---|---|
| 1 | Permisos | "Dar permisos" | "Te van a aparecer dos avisos de Apple: tocá *Continuar* y *Permitir*." | autorización aprobada |
| 2 | Yo (vacía) | "Nuevo límite" | "Empecemos por un límite: tocá acá." | se abre el editor |
| 3 | Editor | campo Nombre | "Ponele un nombre, por ejemplo **Redes**." | nombre no vacío y el campo pierde el foco |
| 4 | Editor | "Elegir apps" | "Se abre una lista de Apple: tocá las apps (TikTok, Instagram…) o una categoría y después *Listo*." | selección no vacía al volver |
| 5 | Editor | minutos por día | "¿Cuánto por día? Arrancá generoso: bajarlo después es libre, subirlo lo aprueba tu dupla." | el usuario toca el stepper o el toggle |
| 6 | Editor | "Guardar" | "Listo, guardalo." | grupo guardado |
| 7 | Yo | pestaña de la dupla, después "Compartir código" (o el campo de código si se eligió "Me pasaron un código") | "Ahora invitá a tu dupla con este código." | pareja completa |

Cierre: hoja final con tres viñetas (cuando se te acaba el tiempo la app se bloquea →
desde ahí le pedís minutos → bajar es libre, subir lo aprueba el otro) y "Entendido".
Menú ⋯ → **"Ver el recorrido de nuevo"** reinicia en el paso 2.

Si el usuario ya tiene grupos o dupla (instalaciones existentes), el recorrido arranca en
el primer paso pendiente; si no queda ninguno, no aparece.

## 7. Que la pantalla se actualice sola

- `AppDelegate`: en `willPresent` y en `didReceiveRemoteNotification` publica
  `Notification.Name.screenDataChanged` además de lo que hace hoy.
- `HomeView` recarga pedidos, eventos y grupos de la dupla al recibirla, al cambiar de
  pestaña y al volver a primer plano; además, mientras la pestaña de la dupla está
  visible y hay un pedido propio pendiente, recarga cada 10 s (se corta al salir).
- `AnswerOtherView` y las tarjetas de pedido muestran el resultado al instante (la
  tarjeta desaparece al responder).

## 8. Fuera de alcance

Mostrar minutos restantes exactos (requiere la extensión `DeviceActivityReport`), cambiar
quién decide los límites, más de dos personas, cambios en las extensiones de bloqueo.

## 9. Pruebas

- `ScreenCore`: `ChangePreview` (los cuatro casos de §4) y `RequestStatus.cancelled`.
- pgTAP: `cancel_request` (dueño cancela, el otro no puede, no se cancela uno respondido,
  responder uno cancelado falla).
- Deno: `answeredRequestPayload` con `cancelled` → `null`.
- Capturas del modo demo: `yo`, `dupla`, `dupla-sin-pareja`, `editor-endurecer`,
  `editor-aflojar`, `editor-pendiente`, `tour-2`, `tour-3`, `tour-4`, `tour-final`,
  en claro y `yo`/`dupla` en oscuro.
- Prueba manual con dos iPhone por TestFlight: recorrido completo en un celular nuevo,
  aflojar con un solo toque, cancelar un pedido, y que la pestaña de la otra persona
  muestre un pedido nuevo sin tocar nada.
