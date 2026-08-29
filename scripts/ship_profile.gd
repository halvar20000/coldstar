class_name ShipProfile
extends Resource
## Every number that decides how a craft feels. Tunable live in the F3 panel.
## Distances are metres, speeds m/s, rotation rates deg/s. Keep the whole arena
## inside ~20 km so 32-bit float precision never becomes visible.

@export var display_name: String = "Unnamed"
@export var faction: String = "accord"          # "accord" (player) or "dominion"
@export var silhouette: String = "lancet"       # which procedural hull to build

@export_group("Flight")
## Speed at the balanced power setting (2 engine pips).
@export var rated_speed: float = 140.0
@export var throttle_accel: float = 55.0
@export var throttle_decel: float = 70.0
@export var pitch_rate: float = 78.0
@export var yaw_rate: float = 30.0
@export var roll_rate: float = 130.0
## How fast the actual rotation rate chases the commanded one. Low = mushy
## controls, high = twitchy/arcade. This single number carries most of the feel.
@export var control_response: float = 5.0
## How fast the velocity vector re-aligns with the nose. X-Wing has effectively
## no drift, so keep this high; drop it to see Newtonian sliding.
@export var inertia_response: float = 6.0

@export_group("Afterburner")
## Wing Commander's answer to a faster opponent: a burst you have to spend.
## Set ab_fuel to 0 on craft that have none.
@export var ab_speed_mult: float = 1.75
@export var ab_accel_mult: float = 2.4
@export var ab_fuel: float = 100.0
@export var ab_burn: float = 24.0          # fuel/s while lit
@export var ab_recharge: float = 8.0       # fuel/s once cool
@export var ab_recharge_delay: float = 1.6 # seconds after cutting it

@export_group("Survivability")
@export var hull_max: float = 100.0
@export var shield_max: float = 100.0           # per side (fore / aft)
@export var shield_recharge: float = 7.0        # points/s at 1.0 power factor
@export var hit_radius: float = 11.0

@export_group("Guns")
@export var cannon_count: int = 4
@export var laser_capacity: float = 100.0
@export var laser_recharge: float = 11.0        # points/s at 1.0 power factor
@export var laser_cost: float = 6.0             # per cannon per shot
@export var laser_damage: float = 9.0
@export var bolt_speed: float = 900.0
@export var bolt_life: float = 2.2              # 900 * 2.2 -> ~2 km reach
@export var convergence: float = 500.0
