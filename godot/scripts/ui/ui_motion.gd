class_name UiMotion
extends RefCounted
## Shared easing helpers for the frame screens (title/ending/credits/pause).
## DEMO_PLAN.md's M4 gate: "every UI element eases in and out over
## 150-250ms -- nothing pops or teleports." Centralized once here rather
## than each of the four new screens hand-rolling its own tween, matching
## world_affordances.gd/lens_math.gd's own pattern of pulling shared math
## out to one place instead of copying it.
##
## `target_alpha` is an explicit parameter, not inferred from the control's
## current modulate.a. An earlier version read it from current state, which
## every caller here defeated: each screen's own _ready()/show handler
## already sets `control.modulate.a = 0.0` up front (so the control starts
## correctly hidden long before its eventual fade-in trigger, which for
## things like Settings/feedback panels can be much later than _ready()).
## By the time fade_in()/fade_rise_in() ran, "current alpha" was always
## that same 0.0 -- every fade animated 0 -> 0, visibly a no-op. Found by
## screenshotting the title and ending screens (frame_shots_route.gd) and
## seeing fully-transparent text/frame despite the tweens reporting
## "finished". Explicit beats implicit here.

const DEFAULT_DURATION := 0.2      # mid-point of the authored 150-250ms band
const RISE_SCALE_FROM := 0.94       # how small a "rise in" starts before settling to scale 1


## Fades `control` in to `target_alpha`, easing in a small scale-up at the
## same time -- the standard "arrive" motion for a card, menu, or line of
## text. Returns the Tween so callers that need to chain/await further can
## (`await UiMotion.fade_rise_in(x).finished`).
##
## Scale, not position: an earlier version animated `position` from a
## "start" point back to its resting `position`, reserved from a read of
## `control.position` at call time. For any control laid out by a
## Container (CenterContainer/VBoxContainer -- every screen this file
## serves), that "resting position" only reads correctly once the
## container has actually sorted its children, which for a control still
## invisible at read time can be a stale (0, 0) -- and once the tween
## finishes writing that stale value onto `position`, nothing re-sorts the
## container afterward to correct it, since a plain property write doesn't
## trigger a re-layout. Scale/pivot never touches `position`, so it can
## never fight the container that owns it.
static func fade_rise_in(control: CanvasItem, duration: float = DEFAULT_DURATION, target_alpha: float = 1.0) -> Tween:
	control.visible = true
	control.modulate.a = 0.0
	if control is Control:
		var c := control as Control
		c.pivot_offset = c.size / 2.0
	control.scale = Vector2(RISE_SCALE_FROM, RISE_SCALE_FROM)

	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", target_alpha, duration)
	tween.tween_property(control, "scale", Vector2.ONE, duration)
	return tween


## Fades `control` out in place (no motion -- reserved for the "arrive"
## direction only, matching how a card should recede: settle back to
## invisible, not fly or shrink off). Sets `visible = false` on completion
## unless `hide_when_done` is false.
static func fade_out(control: CanvasItem, duration: float = DEFAULT_DURATION, hide_when_done: bool = true) -> Tween:
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, duration)
	if hide_when_done:
		tween.tween_callback(func() -> void: control.visible = false)
	return tween


## Simple crossfade-in with no motion -- for full-screen fades (the
## black hold-to-fade at the end of the ending screen) where a rise/scale
## would read as a UI card rather than a scene transition.
static func fade_in(control: CanvasItem, duration: float = DEFAULT_DURATION, target_alpha: float = 1.0) -> Tween:
	control.visible = true
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", target_alpha, duration)
	return tween
