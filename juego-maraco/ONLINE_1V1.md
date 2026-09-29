# Online 1v1 (MVP)

Aliados (host) contra Alemanes (invitado) en la misión *Secure the Hedgerow*.
Las reglas son las de siempre, pero en la fase alemana, en lugar de la IA, juega
el segundo jugador.

## Cómo funciona

- **Lockstep determinista.** Por la red solo viajan las órdenes de los jugadores
  (`move`, `fire`, `overwatch`, `face`, `grenade`, `end_turn`, despliegue...).
  Los dos PCs ejecutan esas órdenes en el mismo orden y con la misma semilla de
  RNG, que elige el host. Así el resultado de cada tirada es idéntico en ambos.
- Cada orden lleva un hash del estado del emisor. Si el receptor tiene otro
  estado antes de ejecutarla, el HUD muestra **DESYNC DETECTED**.
- Solo puede dar órdenes quien tiene el turno. La revancha la inicia el host.
- Código:
  - `scripts/net/online_match.gd`: autoload `OnlineMatch`, con el transporte por
    Steam y por LAN.
  - `scripts/net/online_panel.gd`: el panel de lobby.
  - `scripts/battlefield.gd`: la capa de comandos (bloque "Online 1v1 command
    layer").
- En modo offline, la IA y los tests siguen igual que antes.

## Probar en una sola PC (sin Steam)

1. Abrir el proyecto dos veces. Desde el editor: *Debug > Customize Run
   Instances > 2*, o bien abrir dos ejecutables.
2. En la ventana A: **PLAY ONLINE 1v1 → HOST LAN**.
3. En la ventana B: **PLAY ONLINE 1v1 → JOIN LAN** (con `127.0.0.1`).
4. La ventana A juega con los Aliados: START MISSION, desplegar y BEGIN BATTLE.

Para jugar entre dos PCs de la misma red, el invitado pone la IP local del host.
El puerto es UDP 24744.

## Probar por Steam

1. Hace falta el **editor GodotSteam 4.20 para Godot 4.7**
   (`win64-g47-s164-gs420-editor.tar.xz`, en
   https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.20). Con el Godot
   normal, Steam no está disponible y solo aparece la opción LAN.
2. Cada jugador necesita Steam abierto con **su propia cuenta**.
3. Por ahora se usa el AppID de pruebas **480 (Spacewar)**. Cuando el juego
   tenga su propio AppID, se cambia en `DEVELOPMENT_APP_ID`.
4. El host pulsa **HOST LOBBY** y luego **INVITE FRIEND**, o **COPY LOBBY ID** y
   le pasa el número al amigo.
5. El invitado acepta la invitación de Steam, o pega el ID y pulsa **JOIN BY
   ID**.
6. **F10** abre y cierra el panel online en cualquier momento.

## Tests

```
godot --headless --path . --script tests/online_lockstep_test.gd -- <seed>
```

Este test conecta dos partidas en un mismo proceso y juega 8 turnos con
órdenes aleatorias de ambos bandos. Comprueba que los estados nunca divergen,
que el jugador que espera no puede actuar y que la revancha resetea a los dos.

## Pendiente (fuera del MVP)

- Reconexión y guardar la partida si alguien se desconecta. Ahora la partida
  queda en pausa.
- Despliegue alemán libre y elección de bando. Ahora el host siempre juega con
  los Aliados.
- Textos del HUD adaptados al bando alemán (el panel izquierdo sigue siendo el
  aliado).
- Exportar con las plantillas de GodotSteam para jugar sin el editor.
