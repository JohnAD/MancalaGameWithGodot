extends TextureButton


func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass


func pressed():
	get_tree().change_scene("res://SettingsMain.tscn")