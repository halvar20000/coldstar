class_name Campaign
extends Resource

@export var title: String = "Campaign"
@export var start_node: String = ""
@export var nodes: Array[CampaignNode] = []

func node(id: String) -> CampaignNode:
	for n in nodes:
		if n.id == id:
			return n
	return null
