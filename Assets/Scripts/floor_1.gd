extends Node2D

### --- NODE REFERENCES --- ###
@onready var player: CharacterBody2D = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var bread: CharacterBody2D = $Bread

### --- ENEMY SCENES --- ###
var burger_scene: PackedScene = preload("res://Assets/Scenes/bread.tscn")
