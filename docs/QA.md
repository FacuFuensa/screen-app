# QA manual — Screen v1 (dos iPhone reales, A y B)

Family Controls no funciona en el simulador: todo esto es en dispositivo.

## Arranque
- [ ] A y B crean cuenta, dan los dos permisos y se emparejan con el código.
- [ ] La pantalla de emparejar de A avanza sola cuando B usa el código.

## Límite diario
- [ ] A crea "Redes" (TikTok, Instagram), 5 min por día. B lo ve en "Límites de A".
- [ ] A usa TikTok 4 min → B ve "usó el 80 %" en Actividad (puede tardar hasta que A abra la app).
- [ ] A llega a 5 min → aparece la pantalla de bloqueo "Se terminó tu tiempo de hoy en Redes". B recibe push "A llegó al límite".

## Pedido de tiempo
- [ ] En el bloqueo, A toca "Pedir tiempo" → notificación → abre la app con Redes elegido.
- [ ] A pide 5 min con mensaje → B recibe "A pide 5 min" con "Dar 5 min / Otra cantidad / No".
- [ ] B toca "Dar 5 min" desde la notificación, sin abrir la app → A recibe "Te dieron 5 min" y TikTok se desbloquea.
- [ ] Después de 5 min de uso real, TikTok se vuelve a bloquear.
- [ ] Con la app de A cerrada a la fuerza: B aprueba → A abre la app → se desbloquea (sync al abrir), una sola vez.
- [ ] B elige "Otra cantidad", da 12 → A recibe 12 min.
- [ ] Un pedido sin respuesta durante 30 min aparece como "Venció sin respuesta"; aprobarlo después muestra "El pedido ya venció".

## Comodín
- [ ] En el bloqueo, "Usar comodín (5 min)" desbloquea al instante, incluso en modo avión.
- [ ] Al volver la red, B ve "A usó su comodín". El botón no vuelve a aparecer hasta mañana.

## Aflojar y endurecer
- [ ] A baja Redes a 3 min → se aplica al instante; B ve "endureció un límite".
- [ ] A sube a 30 min → aviso "Le mandamos el cambio a B"; sigue valiendo 3 min.
- [ ] B ve "3 min → 30 min" y aprueba → en A queda 30 min.
- [ ] A cambia Instagram por Notas (mismo número de apps) → se pide aprobación.
- [ ] A intenta borrar el grupo → se pide aprobación.

## Horario de bloqueo
- [ ] A pone bloqueo 23:00–07:00 (o una franja cercana para probar) → en la franja se bloquea solo.
- [ ] Una franja que cruza medianoche no desbloquea a las 23:59 (probar con 23:30–00:30).
- [ ] Un pedido aprobado durante la franja desbloquea por los minutos dados.

## Trampas
- [ ] A le quita el permiso a Screen en Ajustes y abre la app → B recibe "A desactivó los permisos de Screen".
- [ ] A borra la app → a las ~24 h B recibe "A no reporta hace un día".
