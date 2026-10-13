extends ConfirmationDialog

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")

signal join_confirmed(ip: String, port: int)

const DEFAULT_IP := "127.0.0.1"
const DEFAULT_PORT := 4242

@onready var ip_edit: LineEdit = $VBoxContainer/IpLineEdit
@onready var ip_label: Label = $VBoxContainer/Label
@onready var port_edit: LineEdit = $VBoxContainer/PortLineEdit
@onready var port_label: Label = $VBoxContainer/PortLabel


func _ready() -> void:
	dialog_hide_on_ok = true
	exclusive = false
	hide()
	if ip_edit:
		ip_edit.text = DEFAULT_IP
		ip_edit.placeholder_text = DEFAULT_IP
	if port_edit:
		port_edit.text = str(DEFAULT_PORT)
		port_edit.placeholder_text = str(DEFAULT_PORT)
	confirmed.connect(_on_confirmed)
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(_on_close_requested)
	canceled.connect(_on_canceled)
	_apply_static_texts()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()


func _apply_static_texts() -> void:
	title = tr("ui.join.title")
	ok_button_text = tr("ui.join.ok")
	if ip_label:
		ip_label.text = tr("ui.join.host_ip")
	if port_label:
		port_label.text = tr("ui.join.port")


## Show join prompt; keep exclusive only while visible.
func popup_join() -> void:
	_apply_static_texts()
	if ip_edit and ip_edit.text.strip_edges().is_empty():
		ip_edit.text = DEFAULT_IP
	if port_edit and port_edit.text.strip_edges().is_empty():
		port_edit.text = str(DEFAULT_PORT)
	exclusive = true
	popup_centered()
	if ip_edit:
		ip_edit.grab_focus()
		ip_edit.select_all()


func _release_modal() -> void:
	exclusive = false
	hide()


func _on_visibility_changed() -> void:
	if not visible:
		exclusive = false


func _on_close_requested() -> void:
	_release_modal()


func _on_canceled() -> void:
	_release_modal()


func _on_confirmed() -> void:
	var ip: String = DEFAULT_IP
	if ip_edit:
		ip = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = DEFAULT_IP
	var port := DEFAULT_PORT
	if port_edit:
		var parsed := int(port_edit.text.strip_edges())
		if parsed > 0 and parsed < 65536:
			port = parsed
	_release_modal()
	join_confirmed.emit(ip, port)
