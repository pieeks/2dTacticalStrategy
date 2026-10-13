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
	if ip_edit:
		ip_edit.text = DEFAULT_IP
		ip_edit.placeholder_text = DEFAULT_IP
	if port_edit:
		port_edit.text = str(DEFAULT_PORT)
		port_edit.placeholder_text = str(DEFAULT_PORT)
	confirmed.connect(_on_confirmed)
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


func popup_join() -> void:
	_apply_static_texts()
	if ip_edit and ip_edit.text.strip_edges().is_empty():
		ip_edit.text = DEFAULT_IP
	if port_edit and port_edit.text.strip_edges().is_empty():
		port_edit.text = str(DEFAULT_PORT)
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
	var port := DEFAULT_PORT
	if port_edit:
		var parsed := int(port_edit.text.strip_edges())
		if parsed > 0 and parsed < 65536:
			port = parsed
	join_confirmed.emit(ip, port)
