extends Node
## GroupManager — session groups of player peers (Invite/Accept/Leave/Kick).
## Host-authoritative; clients mirror local membership via rpc_sync_group_state.

signal group_changed
signal invite_received(from_peer_id: int)
signal invite_cleared

const MAX_GROUP_SIZE := 4

## Local mirrored state (solo when group_id empty).
var group_id: String = ""
var leader_peer_id: int = 0
var members: Array[int] = []
## Local pending invite from this peer (0 = none).
var pending_invite_from: int = 0

## Host-only: group_id -> { "leader": int, "members": Array[int] }
var _groups: Dictionary = {}
## Host-only: peer_id -> group_id
var _peer_to_group: Dictionary = {}
## Host-only: invitee_peer -> inviter_peer
var _pending_invites: Dictionary = {}

var _group_id_seq: int = 0


func _ready() -> void:
	if NetworkManagerTest != null and NetworkManagerTest.has_signal("peer_disconnected"):
		if not NetworkManagerTest.peer_disconnected.is_connected(_on_peer_disconnected):
			NetworkManagerTest.peer_disconnected.connect(_on_peer_disconnected)


func get_group_id() -> String:
	return group_id


func get_members() -> Array:
	return members.duplicate()


func get_leader_peer_id() -> int:
	return leader_peer_id


## True when local peer is in a multi-peer session group (not Node.is_in_group).
func is_in_session_group() -> bool:
	return group_id != "" and members.size() >= 2


func is_leader() -> bool:
	return is_in_session_group() and leader_peer_id == _local_id()


## True when this local peer is grouped with peer_id.
func is_grouped_with(peer_id: int) -> bool:
	if peer_id == _local_id():
		return is_in_session_group()
	return group_id != "" and members.has(peer_id)


## Host-aware check for any two peers (QuestManager).
func is_grouped_with_peers(peer_a: int, peer_b: int) -> bool:
	if peer_a == peer_b:
		return false
	if multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var ga := str(_peer_to_group.get(peer_a, ""))
		var gb := str(_peer_to_group.get(peer_b, ""))
		return ga != "" and ga == gb
	# Client: only know own group membership.
	if group_id.is_empty():
		return false
	return members.has(peer_a) and members.has(peer_b)


func has_pending_invite() -> bool:
	return pending_invite_from != 0


func has_pending_invite_from(peer_id: int) -> bool:
	return pending_invite_from != 0 and pending_invite_from == peer_id


## Clear local + host group state (session teardown).
func reset_session_state() -> void:
	_groups.clear()
	_peer_to_group.clear()
	_pending_invites.clear()
	_apply_clear_invite()
	_apply_group_state("", 0, [])


## Request create (usually implicit on first invite). Returns local group_id hint (may be empty until sync).
func create_group() -> String:
	_request_create()
	return group_id


func invite(peer_id: int) -> void:
	if peer_id <= 0 or peer_id == _local_id():
		return
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_host_invite(_local_id(), peer_id)
	else:
		rpc_id(1, "rpc_request_invite", peer_id)


func accept_invite() -> void:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_host_accept(_local_id())
	else:
		rpc_id(1, "rpc_request_accept")


func decline_invite() -> void:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_host_decline(_local_id())
	else:
		rpc_id(1, "rpc_request_decline")


func leave() -> void:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_host_leave(_local_id())
	else:
		rpc_id(1, "rpc_request_leave")


func kick(peer_id: int) -> void:
	if peer_id <= 0 or peer_id == _local_id():
		return
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_host_kick(_local_id(), peer_id)
	else:
		rpc_id(1, "rpc_request_kick", peer_id)


func _local_id() -> int:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return 0
	return multiplayer.get_unique_id()


func _request_create() -> void:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_host_ensure_group_for(_local_id())
	else:
		rpc_id(1, "rpc_request_create")


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer == null or not multiplayer.is_server():
		return
	_host_remove_peer(peer_id, true)


# --- Client → Host RPCs ---

@rpc("any_peer", "reliable")
func rpc_request_create() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_host_ensure_group_for(sender)


@rpc("any_peer", "reliable")
func rpc_request_invite(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_host_invite(sender, target_peer_id)


@rpc("any_peer", "reliable")
func rpc_request_accept() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_host_accept(sender)


@rpc("any_peer", "reliable")
func rpc_request_decline() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_host_decline(sender)


@rpc("any_peer", "reliable")
func rpc_request_leave() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_host_leave(sender)


@rpc("any_peer", "reliable")
func rpc_request_kick(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_host_kick(sender, target_peer_id)


# --- Host → Clients ---

@rpc("authority", "reliable")
func rpc_notify_invite(from_peer_id: int) -> void:
	_apply_invite(from_peer_id)


@rpc("authority", "reliable")
func rpc_clear_invite() -> void:
	_apply_clear_invite()


@rpc("authority", "reliable")
func rpc_sync_group_state(new_group_id: String, new_leader: int, new_members: Array) -> void:
	_apply_group_state(new_group_id, new_leader, new_members)


func _apply_invite(from_peer_id: int) -> void:
	pending_invite_from = from_peer_id
	invite_received.emit(from_peer_id)


func _apply_clear_invite() -> void:
	pending_invite_from = 0
	invite_cleared.emit()


func _apply_group_state(new_group_id: String, new_leader: int, new_members: Array) -> void:
	group_id = str(new_group_id)
	leader_peer_id = int(new_leader)
	members.clear()
	for m in new_members:
		members.append(int(m))
	if group_id.is_empty():
		leader_peer_id = 0
	group_changed.emit()


# --- Host logic ---

func _host_ensure_group_for(peer_id: int) -> String:
	var existing := str(_peer_to_group.get(peer_id, ""))
	if existing != "":
		return existing
	_group_id_seq += 1
	var gid := "g_%d_%d" % [Time.get_ticks_msec(), _group_id_seq]
	_groups[gid] = {"leader": peer_id, "members": [peer_id]}
	_peer_to_group[peer_id] = gid
	_sync_group_to_members(gid)
	return gid


func _host_invite(inviter: int, invitee: int) -> void:
	if invitee <= 0 or invitee == inviter:
		return
	if not _peer_connected(invitee) or not _peer_connected(inviter):
		return
	# Invitee already in a multi-peer group → reject.
	var invitee_gid := str(_peer_to_group.get(invitee, ""))
	if invitee_gid != "" and _group_member_count(invitee_gid) >= 2:
		return
	# Invitee already has pending invite.
	if _pending_invites.has(invitee):
		return
	var inviter_gid := str(_peer_to_group.get(inviter, ""))
	if inviter_gid.is_empty():
		inviter_gid = _host_ensure_group_for(inviter)
	if _group_member_count(inviter_gid) >= MAX_GROUP_SIZE:
		return
	_pending_invites[invitee] = inviter
	_send_notify_invite(invitee, inviter)
	print("GroupManager: invite ", inviter, " -> ", invitee)


func _host_accept(invitee: int) -> void:
	if not _pending_invites.has(invitee):
		return
	var inviter: int = int(_pending_invites[invitee])
	_pending_invites.erase(invitee)
	_send_clear_invite(invitee)
	if not _peer_connected(inviter) or not _peer_connected(invitee):
		return
	var gid := str(_peer_to_group.get(inviter, ""))
	if gid.is_empty():
		gid = _host_ensure_group_for(inviter)
	if _group_member_count(gid) >= MAX_GROUP_SIZE:
		return
	# Remove invitee from any solo stub group first.
	var old_gid := str(_peer_to_group.get(invitee, ""))
	if old_gid != "" and old_gid != gid:
		_host_remove_peer_from_group(invitee, old_gid)
	var g: Dictionary = _groups.get(gid, {})
	var mlist: Array = g.get("members", []).duplicate()
	if not mlist.has(invitee):
		mlist.append(invitee)
	g["members"] = mlist
	_groups[gid] = g
	_peer_to_group[invitee] = gid
	_sync_group_to_members(gid)
	print("GroupManager: accept ", invitee, " joined ", gid)


func _host_decline(invitee: int) -> void:
	if not _pending_invites.has(invitee):
		return
	_pending_invites.erase(invitee)
	_send_clear_invite(invitee)
	print("GroupManager: decline ", invitee)


func _host_leave(peer_id: int) -> void:
	_host_remove_peer(peer_id, false)


func _host_kick(requester: int, target: int) -> void:
	var gid := str(_peer_to_group.get(requester, ""))
	if gid.is_empty():
		return
	var g: Dictionary = _groups.get(gid, {})
	if int(g.get("leader", 0)) != requester:
		return
	if target == requester:
		return
	if str(_peer_to_group.get(target, "")) != gid:
		return
	_host_remove_peer_from_group(target, gid)
	_sync_solo(target)
	_sync_group_to_members(gid)
	print("GroupManager: kick ", target, " from ", gid)


func _host_remove_peer(peer_id: int, from_disconnect: bool) -> void:
	if _pending_invites.has(peer_id):
		_pending_invites.erase(peer_id)
	# Clear pending invites this peer sent.
	var clear_targets: Array = []
	for invitee in _pending_invites.keys():
		if int(_pending_invites[invitee]) == peer_id:
			clear_targets.append(invitee)
	for invitee2 in clear_targets:
		_pending_invites.erase(invitee2)
		if _peer_connected(int(invitee2)):
			_send_clear_invite(int(invitee2))
	var gid := str(_peer_to_group.get(peer_id, ""))
	if gid.is_empty():
		return
	_host_remove_peer_from_group(peer_id, gid)
	if not from_disconnect and _peer_connected(peer_id):
		_sync_solo(peer_id)
	_sync_group_to_members(gid)
	print("GroupManager: remove peer ", peer_id, " disconnect=", from_disconnect)


func _host_remove_peer_from_group(peer_id: int, gid: String) -> void:
	_peer_to_group.erase(peer_id)
	if not _groups.has(gid):
		return
	var g: Dictionary = _groups[gid]
	var mlist: Array = g.get("members", []).duplicate()
	mlist.erase(peer_id)
	if mlist.is_empty():
		_groups.erase(gid)
		return
	g["members"] = mlist
	if int(g.get("leader", 0)) == peer_id:
		g["leader"] = int(mlist[0])
	_groups[gid] = g
	# Solo stub left: dissolve and sync remaining as solo.
	if mlist.size() < 2:
		for leftover in mlist:
			_peer_to_group.erase(int(leftover))
			_sync_solo(int(leftover))
		_groups.erase(gid)


func _sync_group_to_members(gid: String) -> void:
	if not _groups.has(gid):
		return
	var g: Dictionary = _groups[gid]
	var mlist: Array = g.get("members", [])
	if mlist.size() < 2:
		return
	var leader := int(g.get("leader", 0))
	var payload: Array = mlist.duplicate()
	for peer in mlist:
		_send_group_state(int(peer), gid, leader, payload)


func _sync_solo(peer_id: int) -> void:
	_send_group_state(peer_id, "", 0, [])


func _send_group_state(peer_id: int, gid: String, leader: int, mlist: Array) -> void:
	if peer_id == _local_id():
		_apply_group_state(gid, leader, mlist)
	elif _peer_connected(peer_id):
		rpc_id(peer_id, "rpc_sync_group_state", gid, leader, mlist)


func _send_notify_invite(invitee: int, inviter: int) -> void:
	if invitee == _local_id():
		_apply_invite(inviter)
	elif _peer_connected(invitee):
		rpc_id(invitee, "rpc_notify_invite", inviter)


func _send_clear_invite(invitee: int) -> void:
	if invitee == _local_id():
		_apply_clear_invite()
	elif _peer_connected(invitee):
		rpc_id(invitee, "rpc_clear_invite")


func _group_member_count(gid: String) -> int:
	if not _groups.has(gid):
		return 0
	var g: Dictionary = _groups[gid]
	var mlist: Array = g.get("members", [])
	return mlist.size()


func _peer_connected(peer_id: int) -> bool:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	if peer_id == multiplayer.get_unique_id():
		return true
	return multiplayer.get_peers().has(peer_id)
