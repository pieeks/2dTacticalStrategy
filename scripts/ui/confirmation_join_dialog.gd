extends ConfirmationDialog

## Dialog to enter a host IP before joining a multiplayer world.

signal join_confirmed(ip: String)

const DEFAULT_IP := "127.0.0.1"

@onready var ip_edit: LineEdit = $VBoxContainer/IpLineEdit


func _ready() -> void:
	title = "Join World"
	ok_button_text = "Join"
	dialog_hide_on_ok = true
	if ip_edit:
		ip_edit.text = DEFAULT_IP
		ip_edit.placeholder_text = DEFAULT_IP
	confirmed.connect(_on_confirmed)


func popup_join() -> void:
	if ip_edit and ip_edit.text.strip_edges().is_empty():
		ip_edit.text = DEFAULT_IP
	popup_centered()
	if ip_edit:
		ip_edit.grab_focus()
		ip_edit.select_all()


func _on_confirmed() -> void:
	var ip: String = DEFAULT_IP
	if ip_edit:
		ip = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = DEFAULT_IP
	join_confirmed.emit(ip)
