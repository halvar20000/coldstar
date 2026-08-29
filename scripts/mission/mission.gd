class_name Mission
extends Resource
## A whole mission as data: who flies, who turns up, and what counts as winning.

@export var title: String = "Untitled"
@export var subtitle: String = ""
@export_multiline var briefing: String = ""
@export var player_profile: ShipProfile
@export var player_start: Vector3 = Vector3.ZERO
@export var player_facing: Vector3 = Vector3(0, 0, -1000)
@export var groups: Array[CraftGroup] = []
@export var goals: Array[MissionGoal] = []
## 0 = no limit. A limit that expires fails any goal still pending.
@export var time_limit: float = 0.0

func group_by_id(id: String) -> CraftGroup:
	for g in groups:
		if g.id == id:
			return g
	return null
