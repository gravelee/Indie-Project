class_name CameraSettings extends Resource

# ---------------------------------------------------------------------------
# Zoom constants
# Distances are in world units (1 world unit = 32px = 1 tile).
# ---------------------------------------------------------------------------

# Closest the camera can get to the player.
const ZOOM_MIN        : float = 5.0
# Furthest the camera can pull back from the player.
const ZOOM_MAX        : float = 15.0
# Number of discrete steps across the zoom range for keyboard control.
const ZOOM_STEPS      : int   = 11
# World-unit distance per keyboard zoom step.
const ZOOM_STEP_VALUE : float = 1.0


# ---------------------------------------------------------------------------
# Pitch constants
# Pitch is negative degrees — camera tilts down to see the player from above.
# 0° = camera level with player (unusable). -90° = directly overhead.
# Valid range: -15° (shallow, more side view) to -40° (steep, more top-down).
# ---------------------------------------------------------------------------

# Steepest allowed pitch (maximum downward tilt, mathematically the minimum value).
const PITCH_MIN        : float = -40.0
# Shallowest allowed pitch (minimum downward tilt, mathematically the maximum value).
const PITCH_MAX        : float = -15.0
# Number of discrete steps across the pitch range for keyboard control.
const PITCH_STEPS      : int   = 6
# Degree change per keyboard pitch step.
const PITCH_STEP_VALUE : float = 5.0


# ---------------------------------------------------------------------------
# Orbit settings — horizontal camera rotation around the player.
# ---------------------------------------------------------------------------

# True: Q and E keys rotate the camera.
@export var qe_orbit_enabled : bool  = true
# True: orbit input direction is flipped.
@export var invert_orbit     : bool  = false
# Degrees per pixel of horizontal mouse movement while RMB is held.
@export var orbit_sens       : float = 0.4
# Degrees per second of rotation while Q or E is held.
@export var orbit_key_speed  : float = 90.0


# ---------------------------------------------------------------------------
# Pitch settings — vertical camera tilt.
# ---------------------------------------------------------------------------

# True: vertical mouse movement while RMB is held adjusts pitch.
@export var mouse_pitch_enabled : bool  = true
# True: pitch input direction is flipped.
@export var invert_pitch        : bool  = false
# Degrees per pixel of vertical mouse movement while RMB is held.
@export var pitch_sens          : float = 0.13
# Pitch step index applied when the player is outdoors (higher = steeper tilt).
@export var outdoor_pitch_step  : int   = 3
# Pitch step index applied when the player is indoors (lower = shallower tilt, wider view).
@export var indoor_pitch_step   : int   = 1


# ---------------------------------------------------------------------------
# Zoom settings — camera distance from the player.
# ---------------------------------------------------------------------------

# True: mouse wheel and trackpad pan gesture adjust zoom.
@export var mouse_zoom_enabled : bool  = true
# True: zoom input direction is flipped (scroll up = zoom out instead of in).
@export var invert_zoom        : bool  = true
# Zoom distance change per scroll tick (without RMB held).
@export var zoom_sens          : float = 0.12
# Zoom distance change per scroll tick while RMB is held (faster pan-zoom).
@export var zoom_sens_rmb      : float = 0.18
# Zoom step index applied when the player is outdoors (higher = further out).
@export var outdoor_zoom_step  : int   = 3
# Zoom step index applied when the player is indoors (lower = closer in, tighter view).
@export var indoor_zoom_step   : int   = 1


# ---------------------------------------------------------------------------
# Movement input settings — which keys drive player movement.
# Read by player.gd each frame to decide which keys are active.
# ---------------------------------------------------------------------------

# True: WASD keys move the player.
@export var use_wasd   : bool = true
# True: arrow keys move the player.
@export var use_arrows : bool = true


# ---------------------------------------------------------------------------
# Visual settings
# ---------------------------------------------------------------------------

# Alpha value applied to the player sprite when an obstacle is between the camera and the player.
# Range 0 (invisible) to 255 (fully opaque). 38 ≈ 15% opacity.
@export var player_fade_alpha : int = 38
