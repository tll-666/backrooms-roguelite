extends Area2D
class_name Bullet

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: float = 15.0
var lifetime: float = 3.0

## 状态效果：由 Weapon._spawn_bullet 注入，命中敌人时施加（如 "stun"）
var status_effect: String = ""
var effect_duration: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_generate_sprite()

func _generate_sprite() -> void:
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.85, 0.3, 1))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
		return

	if body is CharacterBody2D and not body is Player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if status_effect != "" and body.has_method("apply_status"):
			body.apply_status(status_effect, effect_duration)
		queue_free()

func _on_area_entered(_area: Area2D) -> void:
	pass
