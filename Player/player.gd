extends CharacterBody3D

@onready var camera = $Camera3D
@onready var collision_shape = $CollisionShape3D
@onready var mesh_instance = $MeshInstance3D

const SPEED = 10.0
const JUMP_VELOCITY = 10.0
const GROUND_ACC = 50
const AIR_ACC = 10

const CROUCH_HEIGHT = 1.1
const STAND_HEIGHT = 2

const MOUSE_SENSITIVITY = 0.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var slide_factor = Vector3.ZERO
var acc = 0.0
var double_jump = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_up_direction(Vector3.UP)
	
func stand(delta):
	var current_height = move_toward(collision_shape.get_shape().get_height(), STAND_HEIGHT, delta * 5)
	camera.transform.origin.y = (current_height / 2) - 0.375
	mesh_instance.get_mesh().set_height(current_height)
	collision_shape.get_shape().set_height(current_height)
	pass

func crouch(delta):
	var current_height = move_toward(collision_shape.get_shape().get_height(), CROUCH_HEIGHT, delta * 5)
	camera.transform.origin.y = (current_height / 2) - 0.375
	mesh_instance.get_mesh().set_height(current_height)
	collision_shape.get_shape().set_height(current_height)
	pass

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.005 * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * 0.005 * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_ceiling_only():
		velocity.y = -gravity * delta;
	
	if is_on_wall_only():
		double_jump = true
		acc = GROUND_ACC
		velocity += -get_wall_normal()
		
		var velocity_cross = velocity.cross(get_wall_normal())
		
		if velocity.y > 0:
			velocity.y -= gravity * delta * 0.2
		else:
			if velocity_cross.y > 1 or velocity_cross.y < -1:
				# start wall sliding
				velocity.y -= gravity * delta * 0.2
			else:
				velocity.y -= gravity * delta

		# if negative then facing wall
		# if close to 1 then facing away from wall
		var dot_product = get_wall_normal().dot(-transform.basis.z)
		var look_dir = get_wall_normal().cross(-transform.basis.z)
		if -0.5 < dot_product and dot_product< 0.5 and (velocity_cross.y > 1 or velocity_cross.y < -1):
			if look_dir.y < 0:
				camera.rotation.z = move_toward(camera.rotation.z, PI/5, delta)
			else:
				camera.rotation.z = move_toward(camera.rotation.z, -PI/5, delta)
		else:
			camera.rotation.z = move_toward(camera.rotation.z, 0, delta)

	elif not is_on_floor():
		velocity.y -= gravity * delta
		acc = AIR_ACC
		camera.rotation.z = move_toward(camera.rotation.z, 0, delta)
	else:
		acc = GROUND_ACC
		double_jump = true
		camera.rotation.z = move_toward(camera.rotation.z, 0, delta)

		
	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall_only():
			velocity.y = JUMP_VELOCITY
			velocity += get_wall_normal() * JUMP_VELOCITY
		elif double_jump:
			if velocity.y < 0:
				velocity.y = JUMP_VELOCITY
			else:
				velocity.y += JUMP_VELOCITY
			double_jump = false

		
	if Input.is_action_pressed("crouch"):
		if is_on_floor():
			slide_factor = Vector3( get_floor_normal().x, 0, get_floor_normal().z ).normalized()
		else:
			slide_factor = Vector3.ZERO
		crouch(delta)
	else:
		stand(delta)
		slide_factor = Vector3.ZERO

	velocity.x = move_toward(velocity.x, direction.x * SPEED, acc * delta)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, acc * delta)
	velocity += slide_factor
	move_and_slide()
