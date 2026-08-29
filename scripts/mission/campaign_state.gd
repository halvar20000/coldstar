class_name CampaignState
extends RefCounted
## Where you are in the campaign and who is still alive to fly it. Saved as
## plain JSON in user:// so a save can be read, diffed and deleted by hand.

const SAVE_PATH := "user://campaign.json"

var node_id := ""
var roster: Array[Pilot] = []
var history: Array = []      # [[node_id, "COMPLETE"|"FAILED"], ...]

static func fresh(campaign: Campaign) -> CampaignState:
	var st := CampaignState.new()
	st.node_id = campaign.start_node
	st.roster = MissionRunner.default_roster()
	return st

static func load_or_new(campaign: Campaign) -> CampaignState:
	if not FileAccess.file_exists(SAVE_PATH):
		return fresh(campaign)
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return fresh(campaign)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return fresh(campaign)
	var data: Dictionary = parsed
	var st := CampaignState.new()
	st.node_id = data.get("node", campaign.start_node)
	st.history = data.get("history", [])
	for entry: Dictionary in data.get("roster", []):
		var p := Pilot.new()
		p.callsign = entry.get("callsign", "Two")
		p.name_full = entry.get("name", "Unnamed")
		p.skill = entry.get("skill", 0.6)
		p.alive = entry.get("alive", true)
		st.roster.append(p)
	if st.roster.is_empty():
		st.roster = MissionRunner.default_roster()
	# A node id that no longer exists (edited campaign) restarts cleanly.
	if campaign.node(st.node_id) == null:
		st.node_id = campaign.start_node
	return st

func save() -> void:
	var entries: Array = []
	for p in roster:
		entries.append({"callsign": p.callsign, "name": p.name_full, "skill": p.skill, "alive": p.alive})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("could not write campaign save")
		return
	f.store_string(JSON.stringify({"node": node_id, "roster": entries, "history": history}, "  "))
	f.close()

static func wipe() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func living_pilots() -> int:
	var n := 0
	for p in roster:
		if p.alive:
			n += 1
	return n

func lost_pilots() -> Array[Pilot]:
	var out: Array[Pilot] = []
	for p in roster:
		if not p.alive:
			out.append(p)
	return out

## Advance along the branch. Returns the next node id, or "" if the campaign
## is over — which it can be in either direction.
func advance(campaign: Campaign, complete: bool) -> String:
	history.append([node_id, "COMPLETE" if complete else "FAILED"])
	var n := campaign.node(node_id)
	if n == null:
		node_id = ""
	else:
		node_id = n.on_complete if complete else n.on_fail
	save()
	return node_id
