class_name CameraSettings extends Resource

# ---------------------------------------------------------------------------
# Shared camera limits — used by both CameraRig and GameUI.
# ---------------------------------------------------------------------------

const ZOOM_MIN   : float = 5.0
const ZOOM_MAX   : float = 15.0
const ZOOM_STEPS : int   = 11     # discrete steps: 5,6,7,8,9,10,11,12,13,14,15

const PITCH_MIN  : float = -40.0
const PITCH_MAX  : float = -15.0
const PITCH_STEP : float = 5.0    # discrete steps: -15,-20,-25,-30,-35,-40

# ---------------------------------------------------------------------------
# User-configurable values — edited via the settings page, saved to disk.
# ---------------------------------------------------------------------------

# ORBIT
@export var qe_orbit_enabled : bool  = true
@export var invert_orbit     : bool  = false
@export var orbit_sens       : float = 0.4    # mouse drag (max 0.5)
@export var orbit_key_speed  : float = 90.0   # Q/E degrees per second

# PITCH
@export var mouse_pitch_enabled : bool  = true
@export var invert_pitch        : bool  = false
@export var pitch_sens          : float = 0.13  # mouse drag (0.10–0.15)
@export var outdoor_pitch       : float = -30.0 # preset applied on zone enter
@export var indoor_pitch        : float = -20.0 # preset applied on zone enter

# ZOOM
@export var mouse_zoom_enabled : bool  = true
@export var invert_zoom        : bool  = false
@export var zoom_sens          : float = 0.12  # analog scroll (max 0.3)
@export var outdoor_zoom_step  : int   = 3     # preset applied on zone enter
@export var indoor_zoom_step   : int   = 1     # preset applied on zone enter

# MOVEMENT
@export var use_wasd   : bool = true
@export var use_arrows : bool = true

# VISUAL
@export var player_fade_alpha : int = 38  # 0-255 → min sprite alpha when camera is forced close
