extends CharacterBody2D

### --- STATE MACHINE --- ###
enum PlayerState { IDLE, RUN, DASH, ATTACK, HIT, DEAD }
var current_state: PlayerState = PlayerState.IDLE
var previous_state: PlayerState = PlayerState.IDLE

### --- WEAPON SYSTEM --- ###
@export var MAX_WEAPONS: int = 4  # Maximum number of weapon slots
var current_weapon_index: int = 0  # Currently selected weapon
var unlocked_weapons: Array[bool] = [true, false, false, false]  # Which weapons are unlocked
var weapons: Array[Node] = []  # Array to hold weapon nodes

### --- CORE CONSTANTS --- ###
# Movement
const SPEED = 125.0                     # Normal movement speed
# Dash
const DASH_SPEED = 300.0                # Dash velocity
const DASH_DURATION = 0.25              # Time dash lasts 
const DASH_COOLDOWN = 0.05               # Delay between dashes
# Combat
const ATTACK_DURATION = 0.3             # How long attack locks movement  
# Collision
const IGNORE_LAYER_3_MASK = ~(1 << 2)   # Mask to ignore layer 3 (bit 2)
const LAYER_3_MASK = (1 << 2)           # Mask only layer 3 (bit 2)
const DASH_INVULN_DURATION := 0.5
var dash_invuln_timer := 0.0  

### --- PLAYER HEALTH --- ###
@export var max_health: int = 3          # Maximum HP for player
var health: int                          # Current HP

### --- HEALTH BAR --- ###
var hearts_list: Array[TextureRect] = []   # List of heart UI nodes
@onready var hearts_parent: HBoxContainer = $HealthBar/HBoxContainer  # Reference to the container holding heart UI elements

### --- PLAYER MELEE ORBS --- ###
@export var MAX_MELEE_ORBS: int = 3      # Maximum number of orbs
var current_orb_charges := 0             # Start with zero orbs

### --- MELEE ORB BAR --- ###
var melee_orb_list: Array[TextureRect] = [] # List of melee orb UI nodes
@onready var melee_orbs_parent: HBoxContainer = $MeleeOrbBar/HBoxContainer # Reference to the container holding melee orb UI elements
var orb_reset_timer := 0.0               # Timer for delaying orb consumption
const ORB_RESET_DELAY := 0.1             # Delay time before orbs reset

### --- PLAYER DASH SLABS --- ###
@export var MAX_DASH_SLABS: int = 1
var current_dash_slabs := MAX_DASH_SLABS

### --- DASH SLAB BAR --- ###
var dash_slab_list: Array[TextureRect] = [] # List of dash slash UI nodes
@onready var dash_slabs_parent: HBoxContainer = $DashSlabBar/HBoxContainer # Reference to the container holding dash slab UI elements 
var dash_recharge_timer := 0.0
const DASH_SLAB_RECHARGE_TIME = 0.75  

### --- INVULNERABILITY --- ###
const INVULN_DURATION := 1.0            # Seconds invulnerable after hit
var invuln_timer := 0.0                 # Invulnerability countdown
var is_invulnerable := false            # True while invulnerable

### --- NODE REFERENCES --- ###
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D # Character sprite
@onready var melee_area: Area2D = $MeleeArea2D # Melee hit area

### --- BULLET SYSTEM --- ###
const BULLET_SCENE = preload("res://Assets/Weapons/Bullet 1/bullet_2.tscn")

### --- STATE TIMERS --- ###
var dash_timer := 0.0                   # Counts down dash duration
var dash_cooldown_timer := 0.0          # Time until next dash
var attack_timer := 0.0                 # Attack duration countdown
var hit_timer := 0.0                    # Hit animation countdown

### --- INPUT TRACKING --- ###
var move_direction := Vector2.ZERO      # Combined movement input
var aim_direction := Vector2.RIGHT      # Current mouse aim direction

### --- LOCKED DIRECTION --- ###
var is_direction_locked := false        # True while dash/attack in progress
var locked_aim_direction := Vector2.RIGHT  # Stored direction at action start

### --- COMBAT STATE --- ###
var current_attack_animation := ""      # Attack animation name
var attack_after_dash := false          # Attack after dash ends

### --- COLLISION MASK STATE --- ###
var original_collision_mask := 0        # Stores default collision mask
var original_collision_layer := 0       # Stores default collision layer  

### --- KNOCKBACK STATE --- ###
var knockback_velocity := Vector2.ZERO  # Velocity applied from knockback
const KNOCKBACK_DECAY := 800.0           # Rate at which knockback slows down

### --- BLINKING STATE FOR LAST HEART --- ###
var blink_timer := 0.0                   # Timer for blinking effect
const BLINK_INTERVAL := 0.5              # Seconds for blink on/off

func _ready() -> void:
	# Initialize health and disable melee area until needed
	health = max_health                     # Set starting HP
	melee_area.monitoring = false
	melee_area.visible = false
	melee_area.connect("body_entered", Callable(self, "_on_melee_area_body_entered"))
	# Store initial collision mask and layer
	original_collision_mask = collision_mask
	original_collision_layer = collision_layer

	# Initialize weapons array
	for i in range(MAX_WEAPONS):
		var weapon_node = get_node_or_null("Weapon_" + str(i + 1))
		if weapon_node:
			weapons.append(weapon_node)
			# Disable all weapons initially
			weapon_node.visible = false
			weapon_node.set_process(false)
			weapon_node.set_process_input(false)
		else:
			# Add null placeholder if weapon doesn't exist
			weapons.append(null)
	
	# Only enable the first weapon if it's actually unlocked
	if unlocked_weapons.size() > 0 and unlocked_weapons[0] and weapons.size() > 0 and weapons[0]:
		weapons[0].visible = true
		weapons[0].set_process(true)
		weapons[0].set_process_input(true)
		# Connect hit signal for melee orb generation
		if weapons[0].has_signal("hit_target"):
			weapons[0].connect("hit_target", Callable(self, "_on_weapon_hit"))
	else:
		# Ensure no weapon is active if none are unlocked
		current_weapon_index = -1

	# Initialize hearts_list from hearts_parent children 
	for heart_node in hearts_parent.get_children():
		if heart_node is TextureRect:
			hearts_list.append(heart_node)

	# Heart container position
	hearts_parent.position += Vector2(55, 15)  

	# Enable processing to run _process for blinking hearts
	set_process(true)

	# Initialize melee orb list from melee orb UI container
	for orb_node in melee_orbs_parent.get_children():
		if orb_node is TextureRect:
			melee_orb_list.append(orb_node)

	# Melee orb container position
	melee_orbs_parent.position += Vector2(110, 30)
	
	# Initialize dash slab list from dash slab UI container
	for slab_node in dash_slabs_parent.get_children():
		if slab_node is TextureRect:
			dash_slab_list.append(slab_node)
	
	# Dash slab container position
	dash_slabs_parent.position += Vector2(105, 30) 

	update_health_bar()       # Initial update of health bar display
	update_melee_orb_bar()    # Initial update of melee orb bar display
	update_dash_slab_bar()    # Initial update of dash slab bar display
	
	# Start in IDLE state
	change_state(PlayerState.IDLE)

func change_state(new_state: PlayerState) -> void:
	# Exit current state
	match current_state:
		PlayerState.ATTACK:
			_exit_attack_state()
		PlayerState.DASH:
			_exit_dash_state()
		PlayerState.HIT:
			_exit_hit_state()
	
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
	match new_state:
		PlayerState.IDLE:
			_enter_idle_state()
		PlayerState.RUN:
			_enter_run_state()
		PlayerState.DASH:
			_enter_dash_state()
		PlayerState.ATTACK:
			_enter_attack_state()
		PlayerState.HIT:
			_enter_hit_state()
		PlayerState.DEAD:
			_enter_dead_state()

func _input(event: InputEvent) -> void:
	# Weapon switching - only allow switching to unlocked weapons
	if event.is_action_pressed("weapon_1") and unlocked_weapons.size() > 0 and unlocked_weapons[0]:
		switch_weapon(0)
	elif event.is_action_pressed("weapon_2") and unlocked_weapons.size() > 1 and unlocked_weapons[1]:
		switch_weapon(1)
	elif event.is_action_pressed("weapon_3") and unlocked_weapons.size() > 2 and unlocked_weapons[2]:
		switch_weapon(2)
	elif event.is_action_pressed("weapon_4") and unlocked_weapons.size() > 3 and unlocked_weapons[3]:
		switch_weapon(3)

func switch_weapon(index: int):
	# Don't switch to the same weapon or invalid index
	if index == current_weapon_index or index < 0 or index >= weapons.size():
		return
	
	# Disable current weapon if it exists
	if current_weapon_index >= 0 and current_weapon_index < weapons.size() and weapons[current_weapon_index]:
		weapons[current_weapon_index].visible = false
		weapons[current_weapon_index].set_process(false)
		weapons[current_weapon_index].set_process_input(false)
		# Disconnect hit signal
		if weapons[current_weapon_index].has_signal("hit_target"):
			if weapons[current_weapon_index].is_connected("hit_target", Callable(self, "_on_weapon_hit")):
				weapons[current_weapon_index].disconnect("hit_target", Callable(self, "_on_weapon_hit"))
	
	# Enable new weapon
	current_weapon_index = index
	if weapons.size() > current_weapon_index and weapons[current_weapon_index]:
		weapons[current_weapon_index].visible = true
		weapons[current_weapon_index].set_process(true)
		weapons[current_weapon_index].set_process_input(true)
		# Connect hit signal for melee orb generation
		if weapons[current_weapon_index].has_signal("hit_target"):
			weapons[current_weapon_index].connect("hit_target", Callable(self, "_on_weapon_hit"))

func get_current_weapon():
	if current_weapon_index >= 0 and weapons.size() > current_weapon_index and weapons[current_weapon_index]:
		return weapons[current_weapon_index]
	return null

func _process(delta: float) -> void:
	if health == 1 and hearts_list.size() > 0:
		blink_timer += delta
		var blink_phase = int(blink_timer / BLINK_INTERVAL) % 2
		var last_heart = hearts_list[health - 1]
		if blink_phase == 0:
			last_heart.modulate = Color(1, 1, 1, 1)  # fully visible
		else:
			last_heart.modulate = Color(1, 1, 1, 0.3)  # dimmed to create blink
		# Hide or dim all other hearts above
		for i in range(hearts_list.size()):
			if i == health - 1:
				continue
			elif i < max_health:
				hearts_list[i].modulate = Color(1, 1, 1, 0.15)
			else:
				hearts_list[i].modulate = Color(1, 1, 1, 0.0)
	else:
		blink_timer = 0.0
		for i in range(hearts_list.size()):
			if i < health:
				hearts_list[i].modulate = Color(1, 1, 1, 1)    # full visible for active hearts
			elif i < max_health:
				hearts_list[i].modulate = Color(1, 1, 1, 0.15) # transparent for missing-but-allowed hearts
			else:
				hearts_list[i].modulate = Color(1, 1, 1, 0.0)  # fully invisible for hearts above max_health

func _physics_process(delta: float) -> void:
	# Update common systems
	_update_common_systems(delta)
	
	# Skip state processing if dead
	if current_state == PlayerState.DEAD:
		move_and_slide()
		return
	
	# Process current state
	match current_state:
		PlayerState.IDLE:
			_process_idle_state(delta)
		PlayerState.RUN:
			_process_run_state(delta)
		PlayerState.DASH:
			_process_dash_state(delta)
		PlayerState.ATTACK:
			_process_attack_state(delta)
		PlayerState.HIT:
			_process_hit_state(delta)
	
	# Apply knockback and movement
	_apply_movement_and_knockback(delta)
	
	# Update animations
	update_animations()
	
	# Update weapon visibility based on state
	_update_weapon_visibility()

func _update_common_systems(delta: float) -> void:
	# Get input
	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_aim_direction()
	
	# Update invulnerability timers
	if is_invulnerable:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			is_invulnerable = false

	if dash_invuln_timer > 0.0:
		dash_invuln_timer -= delta
		if dash_invuln_timer <= 0.0:
			dash_invuln_timer = 0.0

	# Update collision layers based on invulnerability
	if dash_invuln_timer > 0.0 or is_invulnerable:
		collision_layer = LAYER_3_MASK
		collision_mask = IGNORE_LAYER_3_MASK
	else:
		collision_layer = original_collision_layer
		collision_mask = original_collision_mask
	
	# Update orb reset timer
	if orb_reset_timer > 0.0:
		orb_reset_timer -= delta
		if orb_reset_timer <= 0.0:
			current_orb_charges = 0
			update_melee_orb_bar()
	
	# Update dash slab recharge
	if current_dash_slabs < MAX_DASH_SLABS:
		dash_recharge_timer += delta
		if dash_recharge_timer >= DASH_SLAB_RECHARGE_TIME:
			current_dash_slabs += 1
			dash_recharge_timer = 0.0
			update_dash_slab_bar()
	
	# Update dash cooldown
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			dash_cooldown_timer = 0.0

func _apply_movement_and_knockback(delta: float) -> void:
	# Apply knockback decay
	if knockback_velocity.length() > 0:
		var decay_amount = KNOCKBACK_DECAY * delta
		if knockback_velocity.length() <= decay_amount:
			knockback_velocity = Vector2.ZERO
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, decay_amount)
	
	# Combine movement and knockback
	velocity += knockback_velocity
	move_and_slide()

### --- STATE ENTER/EXIT/PROCESS FUNCTIONS --- ###

func _enter_idle_state() -> void:
	velocity = Vector2.ZERO

func _enter_run_state() -> void:
	pass

func _enter_dash_state() -> void:
	if current_dash_slabs <= 0:
		change_state(PlayerState.IDLE)
		return

	# Consume one dash slab
	current_dash_slabs -= 1
	dash_recharge_timer = 0.0
	update_dash_slab_bar()

	# Set dash velocity and timer
	dash_timer = DASH_DURATION
	velocity = aim_direction * DASH_SPEED
	
	# Set invulnerability
	dash_invuln_timer = DASH_INVULN_DURATION
	
	# Lock direction
	locked_aim_direction = aim_direction
	is_direction_locked = true
	
	# Make player intensely golden while dashing
	animated_sprite_2d.modulate = Color(1.5, 1.2, 0.3, 1.0)  # More intense golden color

func _exit_dash_state() -> void:
	dash_cooldown_timer = DASH_COOLDOWN
	is_direction_locked = false
	# Reset color after dash
	animated_sprite_2d.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Back to normal white

func _enter_attack_state() -> void:
	attack_timer = ATTACK_DURATION
	velocity = Vector2.ZERO
	
	# Spawn bullet from pistol's Marker2D
	spawn_melee_bullet()
	
	# Lock direction
	locked_aim_direction = aim_direction
	is_direction_locked = true
	
	# Start orb reset timer
	orb_reset_timer = ORB_RESET_DELAY

func spawn_melee_bullet() -> void:
	var bullet = BULLET_SCENE.instantiate()
	
	# Get the current weapon's muzzle Marker2D
	var current_weapon = get_current_weapon()
	if current_weapon and current_weapon.has_node("Marker2D"):
		var muzzle = current_weapon.get_node("Marker2D")
		# Set bullet position to muzzle's global position
		bullet.position = muzzle.global_position
		# Set bullet rotation to match weapon's aim direction
		bullet.rotation = current_weapon.global_rotation
	else:
		# Fallback: use player's position and aim direction
		bullet.position = global_position
		bullet.rotation = locked_aim_direction.angle()
	
	# Set bullet damage based on current orb charges
	if bullet.has_method("set_damage"):
		bullet.set_damage(2 + current_orb_charges)
	
	# Add bullet to the scene
	get_parent().add_child(bullet)
	
	# Note: We don't connect the hit_target signal for melee bullets
	# so they don't recharge melee orbs

func _exit_attack_state() -> void:
	is_direction_locked = false
	current_attack_animation = ""

func _enter_hit_state() -> void:
	hit_timer = 0.5
	velocity = Vector2.ZERO

func _exit_hit_state() -> void:
	pass

func _enter_dead_state() -> void:
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	
	# Hide all weapons
	for weapon in weapons:
		if is_instance_valid(weapon):
			weapon.visible = false
			weapon.set_process(false)
			weapon.set_process_input(false)
	
	animated_sprite_2d.play("Death")
	if not animated_sprite_2d.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animated_sprite_2d.connect("animation_finished", Callable(self, "_on_animation_finished"))

func _process_idle_state(_delta: float) -> void:
	# Check for state transitions
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and current_dash_slabs > 0:
		change_state(PlayerState.DASH)
		return
	
	if Input.is_action_just_pressed("melee") and current_orb_charges > 0:
		current_attack_animation = "Swing_1"
		change_state(PlayerState.ATTACK)
		return
	
	if move_direction.length() > 0.1:
		change_state(PlayerState.RUN)
		return
	
	# Process idle state
	velocity = move_direction * SPEED

func _process_run_state(_delta: float) -> void:
	# Check for state transitions
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and current_dash_slabs > 0:
		change_state(PlayerState.DASH)
		return
	
	if Input.is_action_just_pressed("melee") and current_orb_charges > 0:
		current_attack_animation = "Swing_1"
		change_state(PlayerState.ATTACK)
		return
	
	if move_direction.length() <= 0.1:
		change_state(PlayerState.IDLE)
		return
	
	# Process run state
	velocity = move_direction * SPEED

func _process_dash_state(delta: float) -> void:
	# Update dash timer
	dash_timer -= delta
	
	# Check for queued attack during dash
	if Input.is_action_just_pressed("melee") and current_orb_charges > 0:
		attack_after_dash = true
	
	# Check for state transition
	if dash_timer <= 0.0:
		if attack_after_dash:
			current_attack_animation = "Swing_2"
			change_state(PlayerState.ATTACK)
			attack_after_dash = false
		else:
			change_state(PlayerState.IDLE)
		return

func _process_attack_state(delta: float) -> void:
	# Update attack timer
	attack_timer -= delta
	
	# Check for state transition
	if attack_timer <= 0.0:
		change_state(PlayerState.IDLE)
		return

func _process_hit_state(delta: float) -> void:
	# Update hit timer
	hit_timer -= delta
	
	# Check for state transition
	if hit_timer <= 0.0:
		change_state(PlayerState.IDLE)
		return

func _update_aim_direction() -> void:
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()

func _update_weapon_visibility() -> void:
	var current_weapon = get_current_weapon()
	if not current_weapon:
		return
	
	# Hide weapon during certain states
	if current_state == PlayerState.DASH or current_state == PlayerState.ATTACK or current_state == PlayerState.HIT:
		current_weapon.visible = false
		current_weapon.set_process(false)
		current_weapon.set_process_input(false)
	else:
		current_weapon.visible = true
		current_weapon.set_process(true)
		current_weapon.set_process_input(true)

func update_animations() -> void:
	# Handle sprite orientation
	if is_direction_locked:
		var dir = locked_aim_direction
		animated_sprite_2d.rotation = dir.angle()                 
		animated_sprite_2d.rotation_degrees = wrap(animated_sprite_2d.rotation_degrees, 0, 360)  
		if animated_sprite_2d.rotation_degrees > 90 and animated_sprite_2d.rotation_degrees < 270:
			animated_sprite_2d.scale.y = -1                       
		else:
			animated_sprite_2d.scale.y = 1                        
		animated_sprite_2d.flip_h = false                         
	else:
		animated_sprite_2d.rotation = 0
		animated_sprite_2d.scale.y = 1
		if move_direction.x != 0:
			animated_sprite_2d.flip_h = move_direction.x < 0
	
	# Play appropriate animation based on state
	match current_state:
		PlayerState.DEAD:
			animated_sprite_2d.play("Death")
		PlayerState.HIT:
			animated_sprite_2d.play("Hit")
		PlayerState.ATTACK:
			animated_sprite_2d.play(current_attack_animation)
		PlayerState.DASH:
			animated_sprite_2d.play("Dash")
		PlayerState.RUN:
			animated_sprite_2d.play("Run")
		PlayerState.IDLE:
			animated_sprite_2d.play("Idle")

### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or current_state == PlayerState.DEAD or dash_invuln_timer > 0.0:
		return
	
	health -= amount
	update_health_bar()

	is_invulnerable = true
	invuln_timer = INVULN_DURATION

	knockback_velocity = +knockback_dir.normalized() * 100  

	change_state(PlayerState.HIT)

	if health <= 0:
		change_state(PlayerState.DEAD)
func die() -> void:
	change_state(PlayerState.DEAD)

func update_health_bar() -> void:
	for i in range(hearts_list.size()):
		if i < health:
			hearts_list[i].modulate = Color(1, 1, 1, 1)     # Full visible for active hearts
		elif i < max_health:
			hearts_list[i].modulate = Color(1, 1, 1, 0.15)  # Dimmed for missing-but-allowed hearts
		else:
			hearts_list[i].modulate = Color(1, 1, 1, 0.0)   # Invisible for hearts beyond max_health

func update_melee_orb_bar() -> void:
	for i in range(melee_orb_list.size()):
		if i < current_orb_charges:
			melee_orb_list[i].modulate = Color(1, 1, 1, 1)     # Full visible for active orbs
		elif i < MAX_MELEE_ORBS:
			melee_orb_list[i].modulate = Color(1, 1, 1, 0.15)  # Dimmed for missing-but-allowed orbs
		else:
			melee_orb_list[i].modulate = Color(1, 1, 1, 0.0)   # Invisible for orbs beyond MAX_MELEE_ORBS

### --- ADD MELEE ORB ON WEAPON HIT --- ###
func add_melee_orb() -> void:
	if current_orb_charges < MAX_MELEE_ORBS:
		current_orb_charges += 1
		update_melee_orb_bar()

func _on_weapon_hit(_collider) -> void:
	add_melee_orb()

func _on_melee_area_body_entered(body: Node) -> void:
	if body == self:
		return  # Don't hit yourself

	if body.has_method("apply_damage"):
		var damage = 2 + current_orb_charges
		body.apply_damage(damage)
		print("Melee hit:", body.name, "Damage:", damage)

func update_dash_slab_bar() -> void:
	for i in range(dash_slab_list.size()):
		if i < current_dash_slabs:
			dash_slab_list[i].modulate = Color(1, 1, 1, 1)    # Fully visible for available slabs
		elif i < MAX_DASH_SLABS:
			dash_slab_list[i].modulate = Color(1, 1, 1, 0.15) # Dimmed for used slabs within max slabs
		else:
			dash_slab_list[i].modulate = Color(1, 1, 1, 0)    # Fully invisible for slabs above max slabs

### --- UNLOCK WEAPONS --- ###
func unlock_weapon(weapon_index: int) -> void:
	if weapon_index >= 0 and weapon_index < MAX_WEAPONS:
		unlocked_weapons[weapon_index] = true
		# Auto-switch to newly unlocked weapon if no weapon is currently active
		if current_weapon_index == -1:
			switch_weapon(weapon_index)

### --- FREE PLAYER PROCESS --- ###
func _on_animation_finished():
	if current_state == PlayerState.DEAD:
		queue_free()  # Removes the player node
