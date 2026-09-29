extends SceneTree
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for hostile in [false, true]:
		var squad := Squad.new(hostile)
		squad.end_turn()
		squad.apply_suppression(1)
		check(squad.suppression_duration_text() == "THROUGH NEXT OWN PHASE", "Off-phase status explains duration")
		squad.end_turn()
		check(squad.suppression == 1, "Other phase end cannot recover suppression")
		squad.begin_turn()
		check(squad.suppression == 1 and squad.effective_movement() == 3, "Suppression persists into own phase")
		check(squad.suppression_duration_text() == "ACTIVE THIS PHASE", "Current phase duration is visible")
		squad.spend_action("move")
		check(squad.suppression == 1, "Acting does not recover suppression")
		squad.end_turn()
		check(squad.suppression == 0, "Suppression recovers at own phase end")
		squad.apply_suppression(2)
		squad.apply_suppression(1)
		squad.begin_turn()
		check(squad.is_pinned() and not squad.can_perform("overwatch") and squad.accuracy_penalty() == 15, "PINNED penalties persist after off-phase refresh")
		squad.apply_suppression(1)
		check(squad.suppression_duration_text() == "ACTIVE + NEXT OWN PHASE", "At-cap refresh extends duration")
		squad.end_turn()
		check(squad.is_pinned(), "Own-phase refresh prevents immediate recovery")
		squad.end_turn()
		check(squad.is_pinned(), "Repeated end is idempotent")
		squad.begin_turn()
		check(squad.is_pinned(), "Refreshed suppression lasts entire following phase")
		squad.apply_suppression(0)
		squad.end_turn()
		check(squad.suppression == 0, "Zero suppression does not refresh duration")
		squad.apply_suppression(2)
		squad.restore()
		check(squad.suppression == 0 and squad.suppression_phases_remaining == 0, "Battle reset clears duration")
	print("SUPPRESSION DURATION CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
