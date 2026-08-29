class_name CraftGroup
extends Resource
## One flight of craft in a mission: what they are, when they turn up, and what
## they were told to do. Everything here is data — adding a mission must never
## mean adding code, which is the rule that decides whether this project still
## has legs at mission thirty.

enum Arrival {
	START,                 ## already in the area when the mission opens
	AFTER_TIME,            ## arrival_delay seconds after mission start
	ON_GROUP_DESTROYED,    ## when every craft in arrival_group is dead
	ON_GROUP_ARRIVED,      ## when arrival_group turns up
	PLAYER_NEAR_POINT,     ## when the player comes within arrival_radius
}

enum Order {
	WAIT,     ## hold station, fight only what comes to you
	PATROL,   ## loop the waypoints, engage anything hostile nearby
	ATTACK,   ## hunt order_target's craft
	ESCORT,   ## stay with order_target and kill what threatens it
	GOTO,     ## fly the waypoints and leave; do not go looking for a fight
}

@export var id: String = "group"
@export var profile: ShipProfile
@export var count: int = 3
@export var skill: float = 0.6
## Blank means "whatever the profile says".
@export var faction_override: String = ""
## Fill this flight from the campaign's surviving pilots rather than spawning
## anonymous craft. A flight of three with only two pilots left launches as two.
@export var use_roster: bool = false

@export_group("Placement")
@export var spawn_point: Vector3 = Vector3.ZERO
@export var spawn_spread: float = 140.0
@export var facing_point: Vector3 = Vector3.ZERO

@export_group("Arrival")
@export var arrival: Arrival = Arrival.START
@export var arrival_delay: float = 0.0
@export var arrival_group: String = ""
@export var arrival_radius: float = 1800.0
@export var arrival_point: Vector3 = Vector3.ZERO

@export_group("Orders")
@export var order: Order = Order.PATROL
@export var order_target: String = ""
@export var waypoints: Array[Vector3] = []
## GOTO/ESCORT craft that run out of waypoints jump out rather than milling
## around forever. Departing is a mission outcome, not a despawn.
@export var depart_at_end: bool = true

func faction() -> String:
	return faction_override if faction_override != "" else (profile.faction if profile else "dominion")
