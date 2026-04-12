extends Node2D

# =============================================================================
# HUD.GD
#
# Responsibilities:
#   - Draw HP and energy bars above the player sprite every frame
#
# The player is always at the camera centre, so bars are drawn relative
# to the viewport centre — no world-to-screen conversion needed.
# =============================================================================


# ── Bar dimensions (mirrors settings.py) ──────────────────────────────────────

const BAR_W      := 60.0
const HP_H       := 5.0
const EN_H       := 3.0
const BAR_GAP    := 3.0
const BAR_OFFSET := 60.0   # pixels above viewport centre


# ── Colors ─────────────────────────────────────────────────────────────────────

const COLOR_BG         := Color(0.15, 0.15, 0.15)
const COLOR_HP_HIGH    := Color(0.24, 0.78, 0.31)   # green  — above 75%
const COLOR_HP_MID     := Color(0.90, 0.78, 0.16)   # yellow — 25-75%
const COLOR_HP_LOW     := Color(0.86, 0.24, 0.24)   # red    — below 25%
const COLOR_ENERGY     := Color(1.00, 0.55, 0.00)   # orange


# ── Reference ─────────────────────────────────────────────────────────────────

var player_stats : Stats   # set by game.gd after player is ready


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(_delta: float) -> void:

	queue_redraw()


# LOOP
func _draw() -> void:

	if not player_stats:
		return

	var vp     := get_viewport().get_visible_rect()
	var cx     := vp.size.x * 0.5
	var cy     := vp.size.y * 0.5
	var bar_x  := cx - BAR_W * 0.5
	var top_y  := cy - BAR_OFFSET - HP_H - EN_H - BAR_GAP

	# ── HP bar ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(bar_x, top_y, BAR_W, HP_H), COLOR_BG)
	draw_rect(Rect2(bar_x, top_y, BAR_W * player_stats.hp_pct(), HP_H),
			  _hp_color(player_stats.hp_pct()))

	# ── Energy bar ─────────────────────────────────────────────────────────────
	var en_y := top_y + HP_H + BAR_GAP
	draw_rect(Rect2(bar_x, en_y, BAR_W, EN_H), COLOR_BG)
	draw_rect(Rect2(bar_x, en_y, BAR_W * player_stats.energy_pct(), EN_H), COLOR_ENERGY)


# =============================================================================
# HELPERS
# =============================================================================

# Called: _draw().
func _hp_color(pct: float) -> Color:

	if pct > 0.75:   	return COLOR_HP_HIGH
	elif pct > 0.25: 	return COLOR_HP_MID
	else:           	return COLOR_HP_LOW
