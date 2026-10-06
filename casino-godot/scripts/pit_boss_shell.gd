extends RefCounted
# The world owns the viewport. Navigation, drawers and inspectors are overlays.
static func place(control: Control, at: Vector2, extent: Vector2) -> void:
	control.position = at
	control.size = extent

static func layout(ui: Control, dimensions: Vector2) -> void:
	var w := dimensions.x
	var h := dimensions.y
	var mobile: bool = ui.mobile
	var playing: bool = ui.sim.joined >= 0 or not ui.sim.owner_play.is_empty()
	var top := 78.0 if mobile else 88.0
	ui.backdrop.size = dimensions
	place(ui.hud_bar, Vector2.ZERO, Vector2(w, top))
	place(ui.logo, Vector2(16, 12), Vector2(44, 44))
	ui.logo.visible = not mobile and not playing
	ui.brand.text = "PIT BOSS"
	ui.brand.add_theme_font_size_override("font_size", 27 if not mobile else 14)
	place(ui.brand, Vector2(68, 10) if not mobile else Vector2(10, 4), Vector2(150, 36))
	ui.brand.show()
	ui.subtitle.visible = not mobile and not playing
	place(ui.subtitle, Vector2(20, 53), Vector2(165, 20))
	ui.subtitle.add_theme_font_size_override("font_size", 12)
	ui.header_actions.visible = not mobile and not playing
	ui.mobile_menu.visible = not playing
	ui.mobile_speed.show()
	ui.doors_button.visible = not playing
	ui.nav_rail.visible = not mobile and not playing
	ui.bottom_nav.visible = mobile and not playing and not ui.requires_floor_targeting()
	place(ui.nav_rail, Vector2(12, top + 16), Vector2(96, h - top - 32))
	place(ui.bottom_nav, Vector2(6, h - 52), Vector2(w - 12, 46))
	ui.alert_button.visible = not playing and not ui.requires_floor_targeting()
	ui.doors_button.visible = not playing and not ui.requires_floor_targeting()
	if mobile:
		place(ui.stats, Vector2(10, 29), Vector2(w - 176, 32))
		ui.stats.add_theme_font_size_override("font_size", 22)
		place(ui.hud_summary, Vector2(10, 58), Vector2(w - 22, 20))
		ui.hud_summary.add_theme_font_size_override("font_size", 14)
		place(ui.mobile_menu, Vector2(w - 62, 3), Vector2(56, 44))
		place(ui.mobile_speed, Vector2(w - 118, 3), Vector2(50, 44))
		place(ui.doors_button, Vector2(w - 110, 48), Vector2(104, 28))
		ui.doors_button.custom_minimum_size.y = 28
		ui.doors_button.add_theme_font_size_override("font_size", 12)
		place(ui.alert_button, Vector2(w - 68, top + 10), Vector2(60, 44))
		ui.alert_button.add_theme_font_size_override("font_size", 16)
		ui.guest_metric.hide()
		ui.reputation_metric.hide()
		ui.staff_metric.hide()
		ui.status.hide()
	else:
		var x := 206.0
		var metrics: Array = [ui.stats, ui.hud_summary, ui.guest_metric, ui.reputation_metric]
		var widths := [174.0, 156.0, 118.0, 126.0]
		if not ui.sim.staff.is_empty() and w >= 1380:
			metrics.append(ui.staff_metric)
			widths.append(130.0)
		ui.staff_metric.visible = metrics.has(ui.staff_metric)
		for i in range(metrics.size()):
			var metric: Label = metrics[i]
			metric.show()
			metric.add_theme_font_size_override("font_size", 26 if i == 0 else 24 if i != 1 else 22)
			place(metric, Vector2(x + 10, 37), Vector2(widths[i] - 20, 34))
			x += widths[i] + 8
		place(ui.status, Vector2(x + 4, 14), Vector2(100, 58))
		ui.status.add_theme_font_size_override("font_size", 17)
		ui.status.show()
		place(ui.header_actions, Vector2(w - 290, 8), Vector2(98, 44))
		place(ui.mobile_speed, Vector2(w - 184, 8), Vector2(54, 44))
		place(ui.mobile_menu, Vector2(w - 118, 8), Vector2(106, 44))
		place(ui.doors_button, Vector2(w - 274, 58), Vector2(196, 26))
		ui.doors_button.custom_minimum_size.y = 26
		ui.doors_button.add_theme_font_size_override("font_size", 13)
		place(ui.alert_button, Vector2(w - 140, top + 14), Vector2(124, 44))
	if is_instance_valid(ui.mobile_dev):
		ui.mobile_dev.visible = not playing and not mobile
		place(ui.mobile_dev, Vector2(114, 5) if mobile else Vector2(14, h - 58), Vector2(60, 44))
		ui.mobile_dev.add_theme_font_size_override("font_size", 14)
	# Existing labels use retained background cards; no separate dashboard viewport.
	var card_metrics: Array = [ui.stats, ui.hud_summary, ui.guest_metric, ui.reputation_metric, ui.staff_metric]
	for i in range(ui.metric_panels.size()):
		var metric: Label = card_metrics[i]
		var card: Panel = ui.metric_panels[i]
		card.visible = not mobile and not playing and metric.visible
		place(card, Vector2(metric.position.x - 8, 8), Vector2(metric.size.x + 16, 72))
	var floor_bottom := 54.0 if mobile else 0.0
	if mobile and ui.requires_floor_targeting(): floor_bottom = 58
	place(ui.floor_view, Vector2(0, top), Vector2(w, h - top - floor_bottom))
	place(ui.floor_actions, Vector2(12 if mobile else 124, h - 52), Vector2(w - 24 if mobile else 330, 44))
	if mobile and not ui.requires_floor_targeting():
		place(ui.floor_actions, Vector2(8, h - 104), Vector2(minf(w - 16, 330), 44))
	place(ui.mode_hint, Vector2(16 if mobile else 124, top + 8), Vector2(w - (90 if mobile else 310), 28))
	ui.mode_hint.add_theme_font_size_override("font_size", 15)
	# Context panels cover the world temporarily; they never resize the desktop floor.
	var contextual: bool = ui.page in ["table", "guest"] and not ui.context_expanded
	if contextual:
		var sheet_height := minf(290, h * 0.38) if mobile else 250.0
		var sheet_width := w - 12 if mobile else minf(920, w - 260)
		place(ui.inspector_panel, Vector2(6 if mobile else (w - sheet_width) / 2, h - sheet_height - (58 if mobile else 14)), Vector2(sheet_width, sheet_height))
	else:
		var width := w - 12 if mobile else minf(920, w - 220)
		place(ui.inspector_panel, Vector2(6 if mobile else (w - width) / 2, top + 12), Vector2(width, h - top - (70 if mobile else 28)))
	var drawer_width := minf(400, w - 16)
	place(ui.events_panel, Vector2(w - drawer_width - 8, top + 64), Vector2(drawer_width, h - top - (124 if mobile else 80)))
	var overview_width := minf(440, w - 16)
	place(ui.side_panel, Vector2((w - overview_width) / 2, top + 12), Vector2(overview_width, h - top - (70 if mobile else 28)))
	# Existing play presentation is retained while the management shell is corrected.
	ui.play_return.visible = playing
	if playing:
		ui.logo.hide()
		ui.subtitle.hide()
		ui.guest_metric.hide()
		ui.reputation_metric.hide()
		ui.staff_metric.hide()
		ui.status.hide()
		ui.brand.add_theme_font_size_override("font_size", 12)
		place(ui.brand, Vector2(8, 0), Vector2(110, 18))
		place(ui.stats, Vector2(8, 18), Vector2(maxf(120, w - 210), 20))
		place(ui.hud_summary, Vector2(8, 38), Vector2(maxf(120, w - 210), 20))
		ui.stats.add_theme_font_size_override("font_size", 14)
		ui.hud_summary.add_theme_font_size_override("font_size", 14)
		ui.stats.show()
		ui.hud_summary.show()
		place(ui.play_return, Vector2(w - 196, 4), Vector2(130, 44))
		place(ui.mobile_speed, Vector2(w - 60, 4), Vector2(52, 44))
		place(ui.game_view, Vector2(4, 62), dimensions - Vector2(8, 66))
		place(ui.table_scroll, Vector2(4, 62), dimensions - Vector2(8, 66))
		ui.felt.custom_minimum_size = Vector2(0, maxf(h - 66, 580 if w > h else 900))
