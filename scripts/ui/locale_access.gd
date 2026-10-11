extends RefCounted

## Safe accessor for the LocaleManager autoload (path-based, no bare autoload global).


static func get_lm(from: Node) -> Node:
	if from == null or from.get_tree() == null:
		return null
	return from.get_tree().root.get_node_or_null("LocaleManager")
