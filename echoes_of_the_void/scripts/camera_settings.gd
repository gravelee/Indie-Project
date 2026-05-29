class_name CameraSettings extends Resource

# ---------------------------------------------------------------------------
# Shared camera limits — used by both CameraRig and GameUI.
# ---------------------------------------------------------------------------
const ZOOM_MIN   : float = 5.0
const ZOOM_MAX   : float = 15.0
const ZOOM_STEPS : int   = 11      # discrete steps: 5,6,7,8,9,10,11,12,13,14,15
const PITCH_MIN  : float = -40.0
const PITCH_MAX  : float = -15.0
const PITCH_STEP : float = 5.0

# ---------------------------------------------------------------------------
# User-configurable values — edited via the settings page, saved to disk.
# ---------------------------------------------------------------------------

# Presets (applied when is_indoors changes or slider moves)
@export var outdoor_zoom_step  : int   = 3
@export var outdoor_pitch      : float = -30.0
@export var indoor_zoom_step   : int   = 1
@export var indoor_pitch       : float = -20.0

# Mouse enables
@export var mouse_zoom_enabled  : bool = true
@export var mouse_pitch_enabled : bool = true

# Inversions
@export var invert_orbit : bool = false
@export var invert_pitch : bool = false
@export var invert_zoom  : bool = false

# Sensitivities
@export var orbit_sens      : float = 0.4    # mouse orbit (max 0.5)
@export var pitch_sens      : float = 0.13   # mouse pitch (0.10–0.15)
@export var zoom_sens       : float = 0.12   # analog scroll zoom (max 0.3)
@export var orbit_key_speed : float = 90.0   # Q/E degrees per second

# Keyboard toggles
@export var qe_orbit_enabled : bool = true
@export var use_wasd         : bool = true
@export var use_arrows       : bool = true

# Visual
@export var player_fade_alpha : int = 38   # 0-255 → min alpha when camera is forced close
