extends CharacterBody2D

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
@export var MAX_MELEE_ORBS: int = 2      # Maximum number of orbs
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
# Note: Removed pistol_1 reference as we'll use the weapons array instead

### --- MOVEMENT STATE --- ###
var is_dashing := false                 # True during dash
var dash_timer := 0.0                   # Counts down dash duration
var dash_cooldown_timer := 0.0          # Time until next dash
var can_dash := true                    # Dash available
# Queued actions
var attack_after_dash := false          # Attack after dash ends

### --- INPUT TRACKING --- ###
var move_direction := Vector2.ZERO      # Combined movement input
var aim_direction := Vector2.RIGHT      # Current mouse aim direction

### --- LOCKED DIRECTION --- ###
var is_direction_locked := false        # True while dash/attack in progress
var locked_aim_direction := Vector2.RIGHT  # Stored direction at action start

### --- COMBAT STATE --- ###
var is_attacking := false               # During attack animation
var attack_timer := 0.0                 # Attack duration countdown
var current_attack_animation := ""      # Attack animation name
var is_dead := false                    # True after death initiated
var is_hit := false                     # True during hit animation
var hit_timer := 0.0                    # Hit animation countdown

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

	# Initialize weapons array - FIXED: Ensure weapons are in correct order
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
	
	# FIXED: Only enable the first weapon if it's actually unlocked
	# Don't enable any weapon by default if none are unlocked
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
	# --- SKIP EVERYTHING IF DEAD --- #
	if is_dead:
		move_and_slide()  # Allow any last motion to complete
		return

	# --- INVULNERABILITY TIMER --- #
	if is_invulnerable:
		invuln_timer -= delta
	if invuln_timer <= 0.0:
		is_invulnerable = false

	# --- DASH INVULN TIMER --- #
	if dash_invuln_timer > 0.0:
		dash_invuln_timer -= delta
	if dash_invuln_timer <= 0.0:
		dash_invuln_timer = 0.0  # Just to be sure it doesn't go negative

	# --- Manage collision layers based on invulnerability states --- #
	if dash_invuln_timer > 0.0 or is_invulnerable:
		collision_layer = LAYER_3_MASK
		collision_mask = IGNORE_LAYER_3_MASK
	else:
		collision_layer = original_collision_layer
		collision_mask = original_collision_mask

	### --- INPUT PROCESSING --- ###
	# Get combined movement input (4-directional)
	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Get mouse position for aiming
	_update_aim_direction()
	
	### --- TIMER MANAGEMENT --- ###
	# Handle attack duration
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			current_attack_animation = ""
			# Disable melee hit detection
			melee_area.monitoring = false
			melee_area.visible = false
			# Unlock look direction at end of attack
			is_direction_locked = false

	# Handle hit animation duration
	if is_hit:
		hit_timer -= delta
		if hit_timer <= 0.0:
			is_hit = false

	### --- ORB RESET TIMER --- ###
	if orb_reset_timer > 0.0:
		orb_reset_timer -= delta
		if orb_reset_timer <= 0.0:
			# CONSUME ALL ORBS ON MELEE after delay
			current_orb_charges = 0
			update_melee_orb_bar()

	### --- ACTION INITIATION --- ###
	# Start dash if available AND dash slabs are present
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking and not is_hit and current_dash_slabs > 0:
		start_dash()
		# Lock look direction at dash start
		locked_aim_direction = aim_direction
		is_direction_locked = true

	# Queue melee **during** dash → Swing_2
	if is_dashing and Input.is_action_just_pressed("melee") and not is_hit:
		if current_orb_charges > 0:
			attack_after_dash = true

	# Normal attack
	if Input.is_action_just_pressed("melee") and not is_dashing and not is_attacking and not is_hit:
		if current_orb_charges > 0:
			start_attack()
			current_attack_animation = "Swing_1"
			_enable_melee()
			# Start timer to consume orbs shortly after melee starts (instead of instantly)
			orb_reset_timer = ORB_RESET_DELAY
			# Lock look direction at attack start
			locked_aim_direction = aim_direction
			is_direction_locked = true

	### --- DASH PHYSICS --- ###
	if is_dashing:
		# End dash when timer expires
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_cooldown_timer = DASH_COOLDOWN

			
			# Execute queued attack
			if attack_after_dash and current_orb_charges > 0:
				start_attack()
				current_attack_animation = "Swing_2"
				_enable_melee()
				# Start timer to consume orbs shortly after melee starts (instead of instantly)
				orb_reset_timer = ORB_RESET_DELAY
				attack_after_dash = false
				# Lock look direction for the queued attack
				locked_aim_direction = aim_direction
				is_direction_locked = true

	### --- REGULAR MOVEMENT --- ###
	else:
		# Apply movement if not attacking or hit
		if not is_attacking and not is_hit:
			velocity = move_direction * SPEED
		else:
			velocity = Vector2.ZERO  # Freeze movement during attack or hit

	### --- APPLY KNOCKBACK VELOCITY --- ###
	# Knockback overrides movement velocity additively, decays over time
	if knockback_velocity.length() > 0:
		velocity += knockback_velocity
		var decay_amount = KNOCKBACK_DECAY * delta
		if knockback_velocity.length() <= decay_amount:
			knockback_velocity = Vector2.ZERO
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, decay_amount)
	
	### --- PHYSICS UPDATE --- ###
	move_and_slide()

	### --- DASH COOLDOWN TIMER --- ###
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			dash_cooldown_timer = 0.0
			# Allow dash if slabs available
			if current_dash_slabs > 0:
				can_dash = true

	### --- DASH SLAB RECHARGE --- ###
	if current_dash_slabs < MAX_DASH_SLABS:
		dash_recharge_timer += delta
		if dash_recharge_timer >= DASH_SLAB_RECHARGE_TIME:
			current_dash_slabs += 1
			dash_recharge_timer = 0.0
			update_dash_slab_bar()
			# If cooldown finished, allow dash immediately
			if dash_cooldown_timer <= 0.0:
				can_dash = true

	### --- ANIMATION SYSTEM --- ###
	update_animations()

	### --- WEAPON STATE --- ###
	var current_weapon = get_current_weapon()
	if is_dashing or is_attacking or is_hit:
		if current_weapon:
			current_weapon.visible = false
			current_weapon.set_process(false)
			current_weapon.set_process_input(false)
	else:
		if current_weapon:
			current_weapon.visible = true
			current_weapon.set_process(true)
			current_weapon.set_process_input(true)

	### --- SPRITE ORIENTATION --- ###
	if is_dashing or is_attacking:
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

func _update_aim_direction() -> void:
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()

func start_dash():
	if current_dash_slabs <= 0:
		return  # No dash slabs left, can't dash

	# Consume one dash slab and reset recharge timer
	current_dash_slabs -= 1
	dash_recharge_timer = 0.0

	# Start dash state
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false

	# Set dash velocity in aim direction
	velocity = aim_direction * DASH_SPEED

	# Temporarily move to ghost collision layer during dash
	collision_layer = LAYER_3_MASK
	collision_mask = IGNORE_LAYER_3_MASK

	# Set the invulnerability timer for dash
	dash_invuln_timer = DASH_INVULN_DURATION

	# Update the dash slab UI
	update_dash_slab_bar()

	# Queue melee attack if melee input pressed and orbs available
	if Input.is_action_just_pressed("melee") and current_orb_charges > 0:
		attack_after_dash = true
	else:
		attack_after_dash = false

func update_dash_recharge(delta: float) -> void:
	if current_dash_slabs < MAX_DASH_SLABS:
		dash_recharge_timer += delta
		if dash_recharge_timer >= DASH_COOLDOWN:
			current_dash_slabs += 1
			dash_recharge_timer = 0.0
			update_dash_slab_bar()

func start_attack():
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity = Vector2.ZERO  

func _enable_melee():
	melee_area.position = aim_direction * 20
	melee_area.monitoring = true
	melee_area.visible = true

func _on_melee_area_body_entered(body: Node) -> void:
	if body == self:
		return  # Don't hit yourself

	if body.has_method("apply_damage"):
		var damage = 2 + current_orb_charges
		body.apply_damage(damage)
		print("Melee hit:", body.name, "Damage:", damage)


func update_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		if dash_cooldown_timer == 0.0:
			can_dash = true
	update_dash_slab_bar()                      # Always refresh dash slab UI

func update_dash_slab_bar() -> void:
	for i in range(dash_slab_list.size()):
		if i < current_dash_slabs:
			dash_slab_list[i].modulate = Color(1, 1, 1, 1)    # Fully visible for available slabs
		elif i < MAX_DASH_SLABS:
			dash_slab_list[i].modulate = Color(1, 1, 1, 0.15) # Dimmed for used slabs within max slabs
		else:
			dash_slab_list[i].modulate = Color(1, 1, 1, 0)    # Fully invisible for slabs above max slabs

func update_animations() -> void:
	if is_dead:
		animated_sprite_2d.play("Death")
	elif is_hit:
		animated_sprite_2d.play("Hit")
	elif is_attacking and current_attack_animation != "":
		animated_sprite_2d.play(current_attack_animation)
	elif is_dashing:
		animated_sprite_2d.play("Dash")
	elif move_direction.length() > 0.1:
		animated_sprite_2d.play("Run")
	else:
		animated_sprite_2d.play("Idle")

### --- DAMAGE & DEATH --- ###
func apply_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or is_dead or dash_invuln_timer > 0.0:
		return
	health -= amount
	update_health_bar()

	is_invulnerable = true
	invuln_timer = INVULN_DURATION

	collision_layer = 0
	collision_mask = 0

	knockback_velocity = knockback_dir.normalized() * 350

	is_hit = true
	hit_timer = 0.5

	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	
	# Hide all weapons when player dies
	for weapon in weapons:
		if is_instance_valid(weapon):
			weapon.visible = false
			weapon.set_process(false)
			weapon.set_process_input(false)
	
	animated_sprite_2d.play("Death")
	if not animated_sprite_2d.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animated_sprite_2d.connect("animation_finished", Callable(self, "_on_animation_finished"))

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

### --- UNLOCK WEAPONS --- ###
func unlock_weapon(weapon_index: int) -> void:
	if weapon_index >= 0 and weapon_index < MAX_WEAPONS:
		unlocked_weapons[weapon_index] = true
		# Auto-switch to newly unlocked weapon if no weapon is currently active
		if current_weapon_index == -1:
			switch_weapon(weapon_index)

### --- FREE PLAYER PROCESS --- ###
func _on_animation_finished():
	if is_dead:
		queue_free()  # Removes the player node
