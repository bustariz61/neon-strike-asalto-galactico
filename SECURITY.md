# Arquitectura y Seguridad del Proyecto — Neon Strike: Asalto Galáctico

Este documento detalla las medidas de seguridad de estructura, integridad de datos, empaquetado de recursos y privilegios mínimos aplicadas en el código fuente y en los binarios compilados para **PC (Windows x86_64)** y **Android (APK)**.

## 1. Estructura Segura del Proyecto

```text
app/
├── assets/
│   ├── icon.png          # Icono principal 512x512
│   ├── icon.ico          # Icono nativo Windows multi-resolución (256..16px)
│   ├── icon_fg.png       # Capa frontal de icono adaptativo Android
│   ├── icon_bg.png       # Capa de fondo de icono adaptativo Android
│   ├── splash.png        # Imagen de arranque (Boot Splash 1280x720)
│   └── game_cover.png    # Imagen promocional del juego (1280x720)
├── build/
│   ├── windows/
│   │   └── NeonStrike.exe  # Ejecutable PC autocontenido (con PCK embebido)
│   └── android/
│       └── NeonStrike.apk  # Paquete Android firmado (v1/v2/v3)
├── scenes/
│   ├── main_menu.tscn
│   └── game.tscn
├── scripts/
│   ├── autoload/
│   │   ├── game.gd       # Estado global + Guardado cifrado AES-256 + HMAC-SHA256
│   │   └── sfx.gd        # Motor de audio procedural sin archivos externos vulnerables
│   ├── game/
│   │   ├── game.gd       # Controlador de partida
│   │   ├── player.gd     # Lógica del jugador
│   │   ├── enemy.gd      # IA de los 7 tipos de enemigos
│   │   ├── boss.gd       # IA de los 3 jefes multifase
│   │   ├── bullet.gd     # Proyectiles y colisiones
│   │   ├── pickup.gd     # Botín y potenciadores
│   │   ├── fx.gd         # Efectos visuales
│   │   └── touch_controls.gd # Controles táctiles Twin-Stick para Android
│   ├── background.gd
│   ├── main_menu.gd
│   ├── options_panel.gd
│   └── ui.gd
├── export_presets.cfg    # Perfiles de exportación endurecidos (PC y Android)
├── project.godot
├── README.md
└── SECURITY.md
```

## 2. Protección e Integridad de Datos de Guardado (AES-256 + HMAC-SHA256)

En `scripts/autoload/game.gd`, el progreso del jugador (`user://neon_strike_save.sec`) está protegido en dos capas:
1. **Cifrado Simétrico AES-256**: Se utiliza `FileAccess.open_encrypted_with_pass()` con una clave derivada mediante `SHA-256`.
2. **Firma de Integridad HMAC-SHA256**: El JSON interno se firma con `_compute_hmac(payload)` usando `HashingContext.HASH_SHA256`. Si el archivo es modificado externamente, la firma deja de coincidir y el juego rechaza la carga adulterada.
3. **Saneamiento y Validación de Límites (`_sanitize_state()`)**:
   - Todos los valores numéricos (`credits`, `unlocked_level`, `difficulty`, niveles de `upgrades`, `stars`, `best`, `stats`) se restringen estrictamente a sus rangos válidos con `clampi` / `clampf`.
   - El nombre del piloto se filtra mediante lista blanca de caracteres (`A-Z`, `0-9`, `_`, `-`, espacio) y longitud máxima de 14 caracteres (`sanitize_pilot_name`), previniendo inyecciones de texto o desbordamientos de interfaz.
   - Las listas de armas y logros se validan contra los catálogos oficiales (`WEAPONS` y `ACHIEVEMENTS`).

## 3. Seguridad de Binarios y Empaquetado

- **Ejecutable de PC (`build/windows/NeonStrike.exe`)**:
  - Compilado en modo **Release** (`export-release`) sin consola de depuración expuesta.
  - **PCK Embebido** (`binary_format/embed_pck=true`) para distribuir un único archivo ejecutable autocontenido y dificultar la manipulación accidental de recursos sueltos.
- **Paquete Android (`build/android/NeonStrike.apk`)**:
  - **Principio de Mínimo Privilegio**: El manifiesto de Android no solicita permisos peligrosos ni acceso a red (`INTERNET=false`, sin acceso a contactos, ubicación ni almacenamiento externo).
  - **Firma Criptográfica APK Signature Scheme v2/v3**: El APK está firmado y alineado mediante `apksigner` y verificable con `apksigner verify`.
  - **Orientación Horizontal Fija y Controles Táctiles Integrados**: Detecta automáticamente Android / pantallas táctiles y activa los joysticks virtuales Twin-Stick junto con los botones de Dash y Bomba EMP.
