class_name CampaignNode
extends Resource
## One stop in a campaign, and where each outcome sends you. Losing branches
## rather than blocks: the war goes badly and you fly the consequences, which is
## the thing Wing Commander did better than X-Wing's "fly it again".

@export var id: String = "node"
@export var mission_path: String = ""
## Node id to go to next. Empty means the campaign ends here.
@export var on_complete: String = ""
@export var on_fail: String = ""
