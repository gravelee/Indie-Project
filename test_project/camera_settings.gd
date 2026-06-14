class_name CameraSettings extends Resource

# ZOOM min/max values are interpreted in world units. 1 world unit = 32px distance.
const ZOOM_MIN   : float = 5.0 # Camera minimum distance from the player.
const ZOOM_MAX   : float = 15.0 # Camera maximum distance from the player.
const ZOOM_STEPS : int   = 11 # Camera keyboard discrete zoom steps (5.0 - 15.0).
const ZOOM_STEP_VALUE : float = 1.0 # Actual zoom step value increase/decrease.

# PITCH values are negative degrees that the camera tilts in order to directly 
# see the player from above. 0° = camera parallel to player (not usable). -90° = directly overhead.
const PITCH_MIN   : float = -40.0 # Camera (mathematically) minimum pitch degrees (max tilt).
const PITCH_MAX   : float = -15.0 # Camera (mathematically) maximum pitch degrees (min tilt).
const PITCH_STEPS : int = 6 # Camera keyboard discrete pitch steps (-15.0 - -40.0).
const PITCH_STEP_VALUE : float = 5.0 # Actual pitch step value increase/decrease.

# ORBIT
@export var qe_orbit_enabled : bool  = true # True means that Q and E rotation keyboard buttons are enabled.
@export var invert_orbit     : bool  = false # True means that rotation input is inverted.
@export var orbit_sens       : float = 0.4 # Mouse rotation sensitivity.
@export var orbit_key_speed  : float = 90.0 # Keyboard keys rotation sensitivity.

# PITCH
@export var mouse_pitch_enabled : bool  = true # True means that when rmb + mouse vertical motion affects camera pitch.
@export var invert_pitch        : bool  = false # True means that pitch input is inverted.
@export var pitch_sens          : float = 0.13 # Mouse pitch sensitivity.
@export var outdoor_pitch_step  : int = 3 # Pitch step when player is outdoors.
@export var indoor_pitch_step   : int = 1 # Pitch step when player is indoors.

# ZOOM
@export var mouse_zoom_enabled : bool  = true # True means that when mouse wheel up or down (scrolling) affects camera zoom.
@export var invert_zoom        : bool  = true # True means that zoom input is inverted.
@export var zoom_sens          : float = 0.12 # Mouse zoom sensitivity.
@export var zoom_sens_rmb      : float = 0.18 # Mouse zoom sensitivity when holding rmb.
@export var outdoor_zoom_step  : int   = 3 # Zoom step when player is outdoors.
@export var indoor_zoom_step   : int   = 1 # Zoom step when player is indoors.

# MOVEMENT
@export var use_wasd   : bool = true # True means that wasd keys are enabled for movement.
@export var use_arrows : bool = true # True means that keyboard arrow keys are enabled for movement.

# VISUAL
@export var player_fade_alpha : int = 38 # Sets the player alpha value (transparency). Value range [0 - 255].
