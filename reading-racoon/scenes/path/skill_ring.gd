class_name SkillRing
extends Control
## A sub-skill's mastery ring on a world banner (D-007): fills with BKT progress,
## turns gold when mastered. Display only; teachers see the real P(L) later (FR-06).

var progress := 0.0
var mastered := false
var review := false
var icon := ""
var caption := ""


func setup(p_icon: String, p_caption: String, p_progress: float, p_mastered: bool,
		p_review: bool) -> void:
	icon = p_icon
	caption = p_caption
	progress = p_progress
	mastered = p_mastered
	review = p_review
	custom_minimum_size = Vector2(112, 128)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var c := Vector2(size.x / 2, 46)
	var r := 38.0
	draw_circle(c, r, Color(1, 1, 1, 0.25))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 9, true)
	var fill := Color("ffc531") if mastered else Color.WHITE
	if progress > 0.0:
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * progress, 48, fill, 9, true)
	var ic := "👑" if mastered else icon
	var w := font.get_string_size(ic, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string(font, c + Vector2(-w / 2, 12), ic, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
	var label := caption + (" ↺" if review else "")
	w = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(size.x / 2 - w / 2, 118), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color.WHITE)
