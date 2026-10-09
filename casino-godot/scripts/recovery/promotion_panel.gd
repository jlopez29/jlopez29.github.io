extends VBoxContainer
signal claim_requested(id: String)
const UI = preload("res://scripts/recovery/workbench_ui.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var sim: CasinoSimulation
var rows := {}
var scratch_progress := {}
func _ready() -> void:
	add_theme_constant_override("separation",12)
	UI.text(self,"EARNED PROMOTIONS",24)
	UI.text(self,"Preissued results stay with your ticket. Unclaimed tickets do not expire. Credit is capped at your eligible wallet gap.")
	for ticket in sim.recovery.state.tickets:
		var card := UI.card(self,Color("302b24"))
		var art := preload("res://scripts/recovery_ticket.gd").new()
		art.ticket_id=ticket.id
		art.caption=str(ticket.kind).to_upper()+" / EARNED"
		card.add_child(art)
		var status := UI.text(card,"")
		var rules := UI.text(card,odds(str(ticket.kind)),15)
		rules.hide()
		UI.button(card,"Odds & rules",func(): rules.visible=not rules.visible)
		var scratch: Control
		if ticket.kind=="scratch" and not ticket.claimed:
			scratch=preload("res://scripts/recovery_scratch_card.gd").new()
			scratch.erased=scratch_progress.get(ticket.id, {})
			scratch_progress[ticket.id]=scratch.erased
			card.add_child(scratch)
			scratch.scratched.connect(func(): claim_requested.emit(str(ticket.id)))
		var action := UI.button(card,"Reveal without scratching" if ticket.kind=="scratch" else "Check drawing",func(): claim_requested.emit(str(ticket.id)))
		rows[ticket.id]={"status":status,"action":action,"scratch":scratch}
	update_values()
static func odds(kind: String) -> String:
	var counts := {}
	for roll in range(100):
		var award := Recovery.award_for(kind,roll)
		counts[award]=int(counts.get(award,0))+1
	var parts: Array[String]=[]
	for award in counts: parts.append("%d%% $%d" % [counts[award],award])
	return "Published prize odds: "+" / ".join(parts)+". Credit = min(prize, wallet gap)."
func update_values() -> void:
	for ticket in sim.recovery.state.tickets:
		if not rows.has(ticket.id): continue
		var row: Dictionary=rows[ticket.id]
		var wait := maxi(0,int(ticket.draw_utc)-sim.recovery.now())
		var eligible: bool=sim.recovery.can_refill(sim)
		row.action.visible=not ticket.claimed
		row.action.disabled=wait>0 or not eligible
		row.status.text="Prize $%.2f / Credited $%.2f / %s" % [ticket.award,ticket.granted,"No award this time" if ticket.award==0 else "Saved result"] if ticket.claimed else "Draw in "+UI.clock(wait)+" / REAL TIME" if wait>0 else "Ready to check" if ticket.kind=="raffle" else "Rub the silver coating or use accessible reveal."
		if not ticket.claimed and not eligible:
			row.status.text+="\nTicket kept: no wallet gap. Use later." if sim.owner_bankroll>=Recovery.TARGET else "\nSettle active bet before revealing. Ticket kept."
		if is_instance_valid(row.scratch):
			row.scratch.mouse_filter=Control.MOUSE_FILTER_STOP if eligible else Control.MOUSE_FILTER_IGNORE
			if row.scratch.complete and not ticket.claimed: row.scratch.reset_after_failure()
