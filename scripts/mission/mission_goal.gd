class_name MissionGoal
extends Resource
## A single line in the objectives list, and the condition behind it.
## Primary goals decide the mission; secondary ones only decide the debrief.

enum Kind {
	DESTROY_GROUP,       ## every craft in group_id dead
	PROTECT_GROUP,       ## fails the moment group_id is wiped out
	GROUP_DEPARTS,       ## group_id reaches the end of its route and jumps out
	PLAYER_REACH_POINT,  ## player within radius of point
	SURVIVE_TIME,        ## still alive after `seconds`
}

enum Status { PENDING, COMPLETE, FAILED }

@export var kind: Kind = Kind.DESTROY_GROUP
@export var text: String = ""
@export var primary: bool = true
@export var group_id: String = ""
@export var point: Vector3 = Vector3.ZERO
@export var radius: float = 600.0
@export var seconds: float = 0.0

## Runtime only — reset by the runner on every launch, never saved.
var status: Status = Status.PENDING

func label() -> String:
	if text != "":
		return text
	match kind:
		Kind.DESTROY_GROUP: return "Destroy %s" % group_id
		Kind.PROTECT_GROUP: return "Protect %s" % group_id
		Kind.GROUP_DEPARTS: return "See %s clear the area" % group_id
		Kind.PLAYER_REACH_POINT: return "Reach the waypoint"
		Kind.SURVIVE_TIME: return "Survive %d seconds" % int(seconds)
	return "Objective"
