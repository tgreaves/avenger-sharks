extends Area2D

var angle = 0
var radius = 100
var centre


# Called when the node enters the scene tree for the first time.
func _ready():
    centre = position
    $MiniSharkAnimatedSprite2D.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    if get_parent().velocity.x > 0:
        $MiniSharkAnimatedSprite2D.set_flip_h(true)

    if get_parent().velocity.x < 0:
        $MiniSharkAnimatedSprite2D.set_flip_h(false)

    angle += 2 * delta

    var offset = Vector2(sin(angle), cos(angle)) * radius
    var pos = centre + offset
    position = pos


func set_circle_position(shark_number, total_sharks):
    var angle_degrees = (360 / total_sharks) * shark_number
    angle = deg_to_rad(angle_degrees)
