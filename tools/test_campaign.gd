extends SceneTree
## Campaign branching and persistence, checked without flying anything.
##   Godot --headless --path . --script tools/test_campaign.gd

var fails := 0

func _init() -> void:
	var campaign: Campaign = load("res://data/campaigns/accord.tres")
	CampaignState.wipe()

	var st := CampaignState.fresh(campaign)
	_check("starts at the sweep", st.node_id == "sweep", st.node_id)
	_check("roster launches full", st.living_pilots() == 3, st.living_pilots())

	# Losing the sweep must branch, not repeat.
	var next := st.advance(campaign, false)
	_check("failing the sweep falls back", next == "regroup", next)

	# Losses persist across a save/load cycle.
	st.roster[0].alive = false
	st.save()
	var reloaded := CampaignState.load_or_new(campaign)
	_check("save keeps the branch", reloaded.node_id == "regroup", reloaded.node_id)
	_check("dead pilots stay dead", reloaded.living_pilots() == 2, reloaded.living_pilots())
	_check("lost pilot is named", reloaded.lost_pilots()[0].callsign == st.roster[0].callsign,
		reloaded.lost_pilots()[0].callsign)

	# Winning the fallback rejoins the main line; winning that ends the campaign.
	_check("regroup rejoins the convoy", reloaded.advance(campaign, true) == "convoy", reloaded.node_id)
	_check("the convoy ends it", reloaded.advance(campaign, true) == "", reloaded.node_id)
	_check("history recorded", reloaded.history.size() == 3, reloaded.history)

	# Losing the fallback ends it the other way.
	var doomed := CampaignState.fresh(campaign)
	doomed.advance(campaign, false)
	_check("losing the fallback ends it", doomed.advance(campaign, false) == "", doomed.node_id)

	# Every mission the campaign points at must actually load.
	for n in campaign.nodes:
		var m := load(n.mission_path) as Mission
		_check("node %s loads a mission" % n.id, m != null and m.goals.size() > 0,
			m.title if m != null else "null")

	CampaignState.wipe()
	print("--- campaign test: %s ---" % ("all checks passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)

func _check(label: String, ok: bool, value: Variant) -> void:
	if not ok:
		fails += 1
	print("  %s %-32s (%s)" % ["PASS" if ok else "FAIL", label, value])
