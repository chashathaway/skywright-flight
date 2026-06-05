flight_core = {
	pilots = {},
	parachutes = {},
}

local terrain_surface_cache = {}
local terrain_surface_cache_count = 0

local GRAVITY = 9.81
local GROUND_Y = 1.35
local TERRAIN_SCAN_BELOW = 512
local TERRAIN_SURFACE_CACHE_US = 250000
local TERRAIN_SURFACE_CACHE_MAX = 4096
local HUD_UPDATE_INTERVAL = 0.12

local TRAINER = {
	thrust_accel = 18.0,
	lift_coeff = 0.045,
	drag_coeff = 0.012,
	stall_drag_coeff = 0.025,
	brake_drag_coeff = 0.08,
	stall_speed = 10.5,
	control_speed = 18.0,
	pitch_rate = 0.95,
	roll_rate = 1.55,
	yaw_control = 1.0,
	rudder_rate = 0.55,
	rudder_count = 1.0,
	adverse_yaw = 0.0,
	yaw_damper = 0.76,
	yaw_roll_coupling = 0.0,
	stall_sensitivity = 1.0,
	plane_gravity_effect = 1.0,
	speed_lower_limit = 3.0,
	pitch_damper = 0.82,
	roll_damper = 0.80,
	ground_friction = 0.55,
	max_speed = 70.0,
	max_dive_speed = 115.0,
	dive_descent_start = 8.0,
	dive_descent_full = 42.0,
	dive_gravity_multiplier = 1.35,
	side_slip_drag = 1.15,
	crash_descent_speed = 9.0,
	crash_min_speed = 13.0,
	crash_fast_speed = 34.0,
	crash_block_speed = 8.0,
	crash_fatal_speed = 18.0,
	safe_taxi_speed = 5.5,
	plane_color = "random",
}

local CONFIG_STORAGE = minetest.get_mod_storage()
local PLANE_COLORS = {
	white = "flight_core_plane_back_main.png",
	orange = "orange_plane.png",
	blue = "blue_plane.png",
	purple = "purple_plane.png",
	green = "green_plane.png",
	yellow = "yellow_plane.png",
}
local PLANE_COLOR_NAMES = { "white", "orange", "blue", "purple", "green", "yellow" }

local CONFIG_FIELDS = {
	{ key = "plane_color", label = "Plane color", alias = { "color", "colour" }, kind = "text", choices = PLANE_COLOR_NAMES },
	{ key = "pitch_rate", label = "Pitch", alias = { "pitch" }, danger = 3.0 },
	{ key = "roll_rate", label = "Roll", alias = { "roll" }, danger = 4.0 },
	{ key = "yaw_control", label = "Yaw", alias = { "yaw" }, danger = 3.0 },
	{ key = "rudder_rate", label = "Rutter sensitivity", alias = { "rudder", "rutter", "yaw_sensitivity" }, danger = 2.0 },
	{ key = "rudder_count", label = "Number of rutters", alias = { "rudders", "rutters", "number_of_rutters" }, danger = 4.0 },
	{ key = "adverse_yaw", label = "Adverse yaw", alias = { "adverse" }, danger = 1.2 },
	{ key = "yaw_damper", label = "Yaw damper", alias = { "damper" }, danger = 1.1 },
	{ key = "yaw_roll_coupling", label = "Yaw roll coupling", alias = { "yaw_roll", "coupling" }, danger = 1.4 },
	{ key = "stall_sensitivity", label = "Stall sensitivity", alias = { "stall" }, danger = 3.0 },
	{ key = "plane_gravity_effect", label = "Plane gravity effect", alias = { "gravity" }, danger = 3.0 },
	{ key = "max_speed", label = "Speed range upper limit", alias = { "speed_upper", "max_speed", "upper_speed" }, danger = 180.0 },
	{ key = "speed_lower_limit", label = "Speed range lower limit", alias = { "speed_lower", "min_speed", "lower_speed" }, danger = 30.0 },
	{ key = "thrust_accel", label = "Thrust", alias = { "thrust" }, danger = 45.0 },
	{ key = "lift_coeff", label = "Lift", alias = { "lift" }, danger = 0.12 },
	{ key = "drag_coeff", label = "Drag", alias = { "drag" }, danger = 0.08 },
	{ key = "stall_drag_coeff", label = "Stall drag", alias = { "stall_drag" }, danger = 0.15 },
	{ key = "brake_drag_coeff", label = "Brake drag", alias = { "brake_drag" }, danger = 0.25 },
	{ key = "side_slip_drag", label = "Side-slip drag", alias = { "sideslip", "slip_drag" }, danger = 4.0 },
	{ key = "ground_friction", label = "Ground friction", alias = { "friction" }, danger = 2.0 },
	{ key = "max_dive_speed", label = "Dive speed limit", alias = { "dive_speed" }, danger = 240.0 },
	{ key = "dive_gravity_multiplier", label = "Dive gravity ramp", alias = { "dive_gravity" }, danger = 5.0 },
	{ key = "control_speed", label = "Control speed range", alias = { "control_speed" }, danger = 50.0 },
}

local CONFIG_INDEX = {}
for index, field in ipairs(CONFIG_FIELDS) do
	field.index = index
	CONFIG_INDEX[field.key] = field
	for _, alias in ipairs(field.alias or {}) do
		CONFIG_INDEX[alias] = field
	end
end

flight_core.config_fields = CONFIG_FIELDS

-- Chase camera pipeline:
-- * The aircraft stores physics attitude in radians: pitch, yaw, roll.
-- * The player is not attached to the plane in chase view. Instead, the server
--   positions the player behind/above the aircraft every step and aims the
--   camera at a point above the plane. This keeps the plane visible in front of
--   the view and avoids first-person parent-visibility quirks.
-- * Luanti player cameras expose yaw and pitch only. There is no player camera
--   roll parameter in this API, so the real horizon cannot bank in first person.
--   This chase view avoids that limitation by showing the aircraft model roll
--   and pitch in front of the camera.
-- * Attachment rotations are degrees; object rotations and look angles are radians.
local PILOT_MOUNT_POS = { x = 0, y = 7, z = -22 }
local CHASE_TARGET_FORWARD = 8
local CHASE_TARGET_UP = 4
local PILOT_EYE_FIRST = { x = 0, y = 0, z = 0 }
local PILOT_EYE_BACK = { x = 0, y = 9, z = -30 }
local PILOT_EYE_FRONT = { x = 0, y = 5, z = 10 }
local SHADOW_NODE_TOP_DELTA = GROUND_Y - 0.53
local SHADOW_MAX_ALTITUDE = 140
local SHADOW_BASE_X = 17
local SHADOW_BASE_Z = 7.2
local CRASH_BLAST_RADIUS = 3.2
local MISSILE_SPEED = 210
local MISSILE_LIFETIME = 6.0
local MISSILE_COOLDOWN = 1.1
local MISSILE_LOCK_RANGE = 95
local MISSILE_HOMING_RATE = 1.15
local MISSILE_DIRECT_HIT_RADIUS = 2.1
local MISSILE_CRIPPLE_RADIUS = 4.2
local MISSILE_SCRAMBLE_RADIUS = 7.0
local MISSILE_TARGET_SCAN_INTERVAL = 0.12
local MISSILE_PROXIMITY_SCAN_INTERVAL = 0.08
local MISSILE_ANIM_FPS = 18
local AIRCRAFT_TOUCH_RADIUS = 4.0
local AIRCRAFT_TOUCH_SCAN_INTERVAL = 0.18
local PARACHUTE_MAX_FALL_SPEED = 4.2
local PARACHUTE_TARGET_DESCENT = 2.2
local PARACHUTE_GRAVITY = 0.18
local PARACHUTE_OPEN_GRACE = 0.45
local MANUAL_FORM = "flight_core:manual"
local MANUAL_TEXT = table.concat({
	"SKYWRIGHT FLIGHT QUICK MANUAL",
	"Reopen anytime with /manual, /flightmanual, or /controls.",
	"",
	"Getting Started",
	"  /plane spawns and enters a trainer aircraft.",
	"  /exitplane leaves the aircraft normally.",
	"  /manual, /flightmanual, or /controls opens this manual again.",
	"",
	"Basic Flight",
	"  W / S: pitch nose down / up.",
	"  A / D: roll left / right.",
	"  Jump / Sneak: throttle up / down.",
	"  Place / right-click: brake.",
	"  Aux + A / D: rudder left / right.",
	"",
	"Flight Style",
	"  Turns are bank-and-pull. Roll the plane, then pull back with S.",
	"  At steep bank angles, pulling back turns the nose through the bank.",
	"  If you stall, lower the nose and build speed.",
	"",
	"Camera",
	"  The game uses chase view so the plane can visibly roll and pitch.",
	"  Luanti's normal player camera cannot roll the world horizon.",
	"",
	"Missiles and Dogfighting",
	"  Punch / left-click or /fire launches a missile.",
	"  Missiles are early heat seekers: they bend toward nearby aircraft,",
	"  but hits are not guaranteed.",
	"  Direct hits destroy planes. Close hits cripple or scramble controls.",
	"  Plane-to-plane contact crashes both aircraft.",
	"",
	"Ejecting and Parachute",
	"  Shift+E or /eject ejects and leaves the plane flying unpiloted.",
	"  After ejecting, press Jump / Space while airborne to toggle parachute.",
	"  /p, /chute, /parachute, or Shift+Place also toggle parachute.",
	"  Press the parachute toggle again while airborne to cut it.",
	"  The chute closes automatically after safe ground contact.",
	"  /pilotreset restores normal movement if an aircraft link is ever lost.",
	"",
	"Configuration Console",
	"  /fcfg toggles the small HUD console.",
	"  /fedit opens the editable console.",
	"  /fset key value changes a setting live.",
	"  /fsave saves your current preferred settings.",
	"  /freset restores defaults.",
	"  /flist lists config keys.",
	"",
	"Plane Colors",
	"  New planes start with a random color.",
	"  Change color with /fset color blue, green, purple, orange, yellow,",
	"  white, or random. You can also edit color in /fedit.",
	"",
	"Airfield",
	"  New players are assigned one of 12 home runways around the origin.",
	"  Each runway points roughly toward 0,0,0 and is 150-200 nodes out.",
	"  Respawning returns you to your same runway so you can improve it.",
	"  /runway shows which runway is yours.",
	"  /airfield repairs your runway; /airfield all repairs the full ring.",
	"  /softlight relights nearby terrain if shadows look strange.",
	"",
	"Pilots on Foot",
	"  Dirt, sand, flowers, leaves, and wood can be dug by hand.",
	"  Wood is intentionally slower to dig than soil or flowers.",
	"  New chunks generate light flowers, grass, and thin trees.",
	"  /greenery lightly seeds plants and a few trees into existing terrain.",
	"",
	"Basic Crafting",
	"  Wood trunks craft into wood planks.",
	"  Two wood planks stacked vertically craft into sticks.",
	"  Pickaxes, axes, and shovels use normal wood/stone/iron patterns.",
	"  A stove is crafted from 8 stone or cobble blocks around an empty center.",
	"  Stoves cook sand into glass and cobble into stone.",
	"  Aircraft Scrap Iron cooks into ordinary iron ingots.",
	"  Ordinary iron ingots can cook into steel ingots.",
	"  Cracked Aircraft Glass cooks into ordinary glass.",
	"  A trainer kit crafts from 3 iron ingots, 1 glass block, and 2 sticks.",
	"  Use a trainer kit on foot to spawn and enter a plane.",
	"",
	"Known Engine Limits",
	"  Server mods cannot detect raw keys like P directly.",
	"  That is why parachute uses airborne Jump / Space instead of Shift+P.",
}, "\n")

minetest.register_craftitem("flight_core:iron_ingot", {
	description = "Aircraft Scrap Iron Ingot",
	inventory_image = "aircraft_scrap_iron.png",
})

minetest.register_node("flight_core:glass_block", {
	description = "Cracked Aircraft Glass Block",
	tiles = { "cracked_aircraft_glass.png" },
	inventory_image = "cracked_aircraft_glass.png",
	drawtype = "glasslike",
	paramtype = "light",
	sunlight_propagates = true,
	use_texture_alpha = "blend",
	groups = { oddly_breakable_by_hand = 1 },
})

minetest.register_node("flight_core:dirt_block", {
	description = "Scattered Dirt Block",
	tiles = { "dirt.png" },
	groups = { oddly_breakable_by_hand = 1 },
})

minetest.register_craftitem("flight_core:plane_kit", {
	description = "Skywright Trainer Kit",
	inventory_image = "plane_hud_icon.png",
	on_use = function(itemstack, user)
		if not user or not user:is_player() then
			return itemstack
		end

		local name = user:get_player_name()
		if flight_core.pilots[name] then
			minetest.chat_send_player(name, "Exit the current plane before using another trainer kit.")
			return itemstack
		end

		local ok, message = flight_core.spawn_plane(user)
		minetest.chat_send_player(name, message)
		if ok and not (minetest.is_creative_enabled and minetest.is_creative_enabled(name)) then
			itemstack:take_item(1)
		end
		return itemstack
	end,
	on_place = function(itemstack, placer)
		return minetest.registered_items["flight_core:plane_kit"].on_use(itemstack, placer)
	end,
})

minetest.register_craft({
	type = "cooking",
	output = "flight_world:iron_ingot",
	recipe = "flight_core:iron_ingot",
	cooktime = 5,
})

minetest.register_craft({
	type = "cooking",
	output = "flight_world:glass",
	recipe = "flight_core:glass_block",
	cooktime = 4,
})

minetest.register_craft({
	output = "flight_core:plane_kit",
	recipe = {
		{ "flight_world:iron_ingot", "flight_world:glass", "flight_world:iron_ingot" },
		{ "", "flight_world:iron_ingot", "" },
		{ "flight_world:stick", "", "flight_world:stick" },
	},
})

local function is_finite(v)
	return type(v) == "number" and v == v and v > -1000000 and v < 1000000
end

local function clamp(v, lo, hi)
	if not is_finite(v) then
		return lo
	end
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

local function finite_vec(v)
	return v and is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
end

local function finite_or(v, fallback)
	if is_finite(v) then
		return v
	end
	return fallback
end

local function copy_trainer_config(source)
	local config = {}
	source = source or TRAINER
	for _, field in ipairs(CONFIG_FIELDS) do
		if field.kind == "text" then
			config[field.key] = tostring(source[field.key] or TRAINER[field.key] or "")
		else
			config[field.key] = tonumber(source[field.key]) or TRAINER[field.key] or 0
		end
	end
	return config
end

local function storage_key(name)
	return "flight_config:" .. (name or "")
end

function flight_core.default_config()
	return copy_trainer_config(TRAINER)
end

function flight_core.load_config(name)
	local raw = CONFIG_STORAGE:get_string(storage_key(name))
	if raw and raw ~= "" then
		local loaded = minetest.deserialize(raw)
		if type(loaded) == "table" then
			return copy_trainer_config(loaded)
		end
	end
	return flight_core.default_config()
end

function flight_core.save_config(name, config)
	CONFIG_STORAGE:set_string(storage_key(name), minetest.serialize(copy_trainer_config(config)))
end

function flight_core.get_config_field(key)
	return CONFIG_INDEX[(key or ""):lower()]
end

local clear_old_damage_signature

function flight_core.get_config(name)
	if not flight_core.player_configs then
		flight_core.player_configs = {}
	end
	if not flight_core.player_configs[name] then
		flight_core.player_configs[name] = flight_core.load_config(name)
	end
	clear_old_damage_signature(flight_core.player_configs[name])
	return flight_core.player_configs[name]
end

function clear_old_damage_signature(config)
	if not config then
		return
	end

	-- Older combat code accidentally let missile damage mutate the player's
	-- preferred config table. If we see the exact crippled-engine signature,
	-- treat it as aircraft damage state and restore the user's next plane.
	if tonumber(config.max_speed) == 17
		and tonumber(config.max_dive_speed) == 22
		and tonumber(config.thrust_accel) and tonumber(config.thrust_accel) <= 4.5
		and tonumber(config.lift_coeff) and tonumber(config.lift_coeff) <= 0.018
		and tonumber(config.drag_coeff) and tonumber(config.drag_coeff) >= 0.04
		and tonumber(config.stall_sensitivity) and tonumber(config.stall_sensitivity) >= 2.2 then
		config.max_speed = TRAINER.max_speed
		config.max_dive_speed = TRAINER.max_dive_speed
		config.thrust_accel = TRAINER.thrust_accel
		config.lift_coeff = TRAINER.lift_coeff
		config.drag_coeff = TRAINER.drag_coeff
		config.stall_sensitivity = TRAINER.stall_sensitivity
	end
end

function flight_core.set_config_value(name, key, value)
	local field = flight_core.get_config_field(key)
	if not field then
		return false, "Unknown flight config key: " .. (key or "")
	end

	if field.kind == "text" then
		value = tostring(value or ""):lower():match("^%s*(.-)%s*$")
		if field.choices and not PLANE_COLORS[value] and value ~= "random" then
			return false, "Plane color must be random, " .. table.concat(field.choices, ", ") .. "."
		end
	else
		value = tonumber(value)
		if not is_finite(value) then
			return false, "Value must be a finite number."
		end
	end

	local config = flight_core.get_config(name)
	config[field.key] = value

	local pilot = flight_core.pilots[name]
	if pilot and pilot.object then
		local entity = pilot.object:get_luaentity()
		if entity then
			entity.config = entity.config or copy_trainer_config(config)
			entity.config[field.key] = value
			if field.key == "plane_color" then
				entity.plane_color = value
				if entity.update_texture then
					entity:update_texture()
				end
			end
		end
	end

	if field.kind == "text" then
		return true, string.format("%s = %s", field.label, value)
	end
	return true, string.format("%s = %.6g", field.label, value)
end

function flight_core.reset_config(name)
	flight_core.player_configs = flight_core.player_configs or {}
	flight_core.player_configs[name] = flight_core.default_config()
	CONFIG_STORAGE:set_string(storage_key(name), "")

	local pilot = flight_core.pilots[name]
	if pilot and pilot.object then
		local entity = pilot.object:get_luaentity()
		if entity then
			entity.config = copy_trainer_config(flight_core.player_configs[name])
			entity.plane_color = entity.config.plane_color
			if entity.update_texture then
				entity:update_texture()
			end
		end
	end
end

local function random_plane_color()
	return PLANE_COLOR_NAMES[math.random(1, #PLANE_COLOR_NAMES)]
end

local function resolve_plane_color(config, current)
	local color = tostring((config and config.plane_color) or current or "white"):lower()
	if color == "random" or not PLANE_COLORS[color] then
		color = random_plane_color()
	end
	return color
end

local function plane_texture_for_color(color)
	return PLANE_COLORS[color] or PLANE_COLORS.white
end

local function safe_vec(v, fallback)
	if finite_vec(v) then
		return v
	end
	return fallback or { x = 0, y = 0, z = 0 }
end

local function vadd(a, b)
	return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

local function vsub(a, b)
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function vmul(a, s)
	return { x = a.x * s, y = a.y * s, z = a.z * s }
end

local function vdot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function vcross(a, b)
	return {
		x = a.y * b.z - a.z * b.y,
		y = a.z * b.x - a.x * b.z,
		z = a.x * b.y - a.y * b.x,
	}
end

local function vlength(a)
	if not finite_vec(a) then
		return 0
	end
	return math.sqrt(vdot(a, a))
end

local function vnormalize(a)
	local len = vlength(a)
	if len < 0.0001 then
		return { x = 0, y = 0, z = 0 }
	end
	return vmul(a, 1 / len)
end

local function horizontal_speed(v)
	if not finite_vec(v) then
		return 0
	end
	return math.sqrt(v.x * v.x + v.z * v.z)
end

local function limit_vector(v, max_len)
	local len = vlength(v)
	if len <= max_len then
		return v
	end
	return vmul(vnormalize(v), max_len)
end

local orthonormalize_attitude

local function vcopy(v)
	return { x = v.x, y = v.y, z = v.z }
end

local function node_is_solid(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node or node.name == "air" or node.name == "ignore" then
		return false
	end

	local def = minetest.registered_nodes[node.name]
	return def and def.walkable
end

local function drop_node_item(pos, node_name)
	local drop_pos = { x = pos.x + 0.5, y = pos.y + 0.5, z = pos.z + 0.5 }
	local item = minetest.add_item(drop_pos, ItemStack(node_name))
	if item then
		item:set_velocity({
			x = (math.random() - 0.5) * 1.2,
			y = 1.4 + math.random() * 0.8,
			z = (math.random() - 0.5) * 1.2,
		})
	end
end

local function armor_hit_particles(pos, broken)
	minetest.add_particlespawner({
		amount = broken and 24 or 12,
		time = 0.08,
		minpos = { x = pos.x + 0.15, y = pos.y + 0.15, z = pos.z + 0.15 },
		maxpos = { x = pos.x + 0.85, y = pos.y + 0.85, z = pos.z + 0.85 },
		minvel = { x = -2.0, y = 0.4, z = -2.0 },
		maxvel = { x = 2.0, y = 2.4, z = 2.0 },
		minacc = { x = 0, y = -5, z = 0 },
		maxacc = { x = 0, y = -3, z = 0 },
		minexptime = 0.12,
		maxexptime = 0.35,
		minsize = broken and 1.8 or 0.9,
		maxsize = broken and 3.2 or 1.8,
		collisiondetection = false,
		texture = "[fill:8x8:#d7dde2",
		glow = 5,
	})
end

local function damage_blast_resistant_node(pos, node_name)
	local required_hits = minetest.get_item_group(node_name, "skywright_blast_resistant")
	if required_hits <= 0 then
		return false, false
	end

	local meta = minetest.get_meta(pos)
	local hits = meta:get_int("skywright_blast_hits") + 1
	if hits >= required_hits then
		minetest.remove_node(pos)
		drop_node_item(pos, node_name)
		armor_hit_particles(pos, true)
		return true, true
	end

	meta:set_int("skywright_blast_hits", hits)
	local def = minetest.registered_nodes[node_name]
	local label = def and def.description or "Armored block"
	meta:set_string("infotext", string.format("%s: %d/%d missile hits absorbed", label, hits, required_hits))
	armor_hit_particles(pos, false)
	return true, false
end

local function cache_key_for_surface(pos)
	return tostring(math.floor((pos.x or 0) + 0.5)) .. ":" .. tostring(math.floor((pos.z or 0) + 0.5))
end

local function cache_surface_y(key, y, now)
	if not terrain_surface_cache[key] then
		terrain_surface_cache_count = terrain_surface_cache_count + 1
	end
	terrain_surface_cache[key] = { y = y, time = now }

	if terrain_surface_cache_count > TERRAIN_SURFACE_CACHE_MAX then
		terrain_surface_cache = {}
		terrain_surface_cache_count = 0
	end
end

local function raycast_surface_y_at(pos, start_y, end_y)
	if not minetest.raycast then
		return nil
	end

	local ray = minetest.raycast(
		{ x = pos.x, y = start_y, z = pos.z },
		{ x = pos.x, y = end_y, z = pos.z },
		true,
		false
	)

	for pointed in ray do
		if pointed.type == "node" and pointed.under and node_is_solid(pointed.under) then
			return pointed.under.y + GROUND_Y
		end
	end
	return nil
end

local function terrain_surface_y_at(pos)
	local start_y = math.floor((pos.y or GROUND_Y) + 3)
	local end_y = start_y - TERRAIN_SCAN_BELOW
	local now = minetest.get_us_time()
	local key = cache_key_for_surface(pos)
	local cached = terrain_surface_cache[key]
	if cached and now - cached.time <= TERRAIN_SURFACE_CACHE_US then
		return cached.y
	end

	local raycast_y = raycast_surface_y_at(pos, start_y, end_y)
	if raycast_y then
		cache_surface_y(key, raycast_y, now)
		return raycast_y
	end

	for y = start_y, end_y, -1 do
		if node_is_solid({ x = pos.x, y = y, z = pos.z }) then
			local surface_y = y + GROUND_Y
			cache_surface_y(key, surface_y, now)
			return surface_y
		end
	end

	cache_surface_y(key, GROUND_Y, now)
	return GROUND_Y
end

local function terrain_shadow_y_at(pos)
	return terrain_surface_y_at(pos) - SHADOW_NODE_TOP_DELTA
end

local function aircraft_surface_y(self, pos)
	orthonormalize_attitude(self)

	local samples = {
		pos,
		vadd(pos, vmul(self.forward, 2.6)),
		vadd(pos, vmul(self.forward, -1.8)),
		vadd(pos, vmul(self.right, 2.8)),
		vadd(pos, vmul(self.right, -2.8)),
	}
	local surface_y = GROUND_Y

	for _, sample in ipairs(samples) do
		surface_y = math.max(surface_y, terrain_surface_y_at(sample))
	end

	return surface_y
end

local function impact_node_is_near_aircraft(node_pos, aircraft_pos)
	if not node_pos or not finite_vec(aircraft_pos) then
		return false
	end

	-- Raycasts can touch terrain below a fast-moving probe even though the
	-- aircraft body is still well above it. Treat block hits here as obstacle
	-- impacts only when the solid node is roughly at aircraft-body height.
	-- Ground/landing impacts are handled separately by aircraft_surface_y().
	local node_center_y = node_pos.y + 0.5
	return math.abs(node_center_y - aircraft_pos.y) <= 2.4
end

local function detect_block_impact(self, old_pos, new_pos)
	orthonormalize_attitude(self)

	-- These probes represent the nose and wing roots. The oversized visible
	-- sprite is deliberately not the collision shape, so flight stays playable.
	local offsets = {
		vmul(self.forward, 3.2),
		vadd(vmul(self.forward, 1.2), vmul(self.right, 2.7)),
		vadd(vmul(self.forward, 1.2), vmul(self.right, -2.7)),
		vadd(vmul(self.forward, -1.8), vmul(self.up, 0.5)),
	}

	for _, offset in ipairs(offsets) do
		local from_pos = vadd(old_pos, offset)
		local to_pos = vadd(new_pos, offset)
		local ray = minetest.raycast(from_pos, to_pos, true, false)

		for pointed in ray do
			if pointed.type == "node"
				and pointed.under
				and node_is_solid(pointed.under)
				and impact_node_is_near_aircraft(pointed.under, to_pos) then
				return {
					pos = pointed.intersection_point or to_pos,
					node_pos = pointed.under,
					node = minetest.get_node(pointed.under).name,
				}
			end
		end

		local check_pos = vector.round(to_pos)
		if node_is_solid(check_pos) and impact_node_is_near_aircraft(check_pos, to_pos) then
			return {
				pos = to_pos,
				node_pos = check_pos,
				node = minetest.get_node(check_pos).name,
			}
		end
	end

	return nil
end

local function rotate_about_axis(v, axis, angle)
	axis = vnormalize(axis)
	if vlength(axis) < 0.001 then
		return vcopy(v)
	end

	local c = math.cos(angle)
	local s = math.sin(angle)
	return vadd(vadd(vmul(v, c), vmul(vcross(axis, v), s)), vmul(axis, vdot(axis, v) * (1 - c)))
end

local function yaw_to_forward(yaw)
	local dir = minetest.yaw_to_dir(yaw or 0)
	return { x = dir.x, y = 0, z = dir.z }
end

local basis_from_angles

local function set_attitude_from_yaw(self, yaw)
	self.forward = yaw_to_forward(yaw)
	self.up = { x = 0, y = 1, z = 0 }
	self.right = vnormalize(vcross(self.up, self.forward))
	if vlength(self.right) < 0.001 then
		self.right = { x = 1, y = 0, z = 0 }
	end
	self.up = vnormalize(vcross(self.forward, self.right))
end

local function ensure_attitude(self)
	if finite_vec(self.forward) and finite_vec(self.right) and finite_vec(self.up) then
		return
	end

	local forward, up, right = basis_from_angles(self.pitch or 0, self.yaw or 0, self.roll or 0)
	self.forward = forward
	self.right = right
	self.up = up
end

function orthonormalize_attitude(self)
	ensure_attitude(self)

	self.forward = vnormalize(self.forward)
	if vlength(self.forward) < 0.001 then
		self.forward = { x = 0, y = 0, z = 1 }
	end

	self.right = vsub(self.right, vmul(self.forward, vdot(self.right, self.forward)))
	self.right = vnormalize(self.right)
	if vlength(self.right) < 0.001 then
		self.right = vnormalize(vcross({ x = 0, y = 1, z = 0 }, self.forward))
	end
	if vlength(self.right) < 0.001 then
		self.right = { x = 1, y = 0, z = 0 }
	end

	self.up = vnormalize(vcross(self.forward, self.right))
	self.right = vnormalize(vcross(self.up, self.forward))
end

local function update_display_angles(self)
	orthonormalize_attitude(self)

	local horizontal = math.sqrt(self.forward.x * self.forward.x + self.forward.z * self.forward.z)
	self.yaw = minetest.dir_to_yaw({ x = self.forward.x, y = 0, z = self.forward.z })
	self.pitch = math.atan2(self.forward.y, math.max(horizontal, 0.0001))
	self.roll = math.atan2(vdot(self.right, { x = 0, y = 1, z = 0 }), vdot(self.up, { x = 0, y = 1, z = 0 }))
end

local function object_rotation(self)
	orthonormalize_attitude(self)
	return vector.dir_to_rotation(self.forward, self.up)
end

local function safe_dir_rotation(dir, up)
	dir = vnormalize(safe_vec(dir, { x = 0, y = 0, z = 1 }))
	if vlength(dir) < 0.001 then
		dir = { x = 0, y = 0, z = 1 }
	end

	up = vnormalize(safe_vec(up, { x = 0, y = 1, z = 0 }))
	if vlength(up) < 0.001 then
		up = { x = 0, y = 1, z = 0 }
	end

	-- vector.dir_to_rotation() asserts that forward and up are perpendicular.
	-- Project the reference up vector onto the plane normal to direction so
	-- vertical and near-vertical missile shots never pass an invalid pair.
	up = vsub(up, vmul(dir, vdot(dir, up)))
	if vlength(up) < 0.001 then
		if math.abs(dir.y) > 0.8 then
			up = { x = 1, y = 0, z = 0 }
		else
			up = { x = 0, y = 1, z = 0 }
		end
		up = vsub(up, vmul(dir, vdot(dir, up)))
	end
	up = vnormalize(up)

	return vector.dir_to_rotation(dir, up)
end

function basis_from_angles(pitch, yaw, roll)
	pitch = clamp(pitch or 0, -1.2, 1.2)
	yaw = clamp(yaw or 0, -10000, 10000)
	roll = clamp(roll or 0, -10000, 10000)

	local cp = math.cos(pitch)
	local yaw_dir = yaw_to_forward(yaw)
	local forward = {
		x = yaw_dir.x * cp,
		y = math.sin(pitch),
		z = yaw_dir.z * cp,
	}
	forward = vnormalize(forward)

	local world_up = { x = 0, y = 1, z = 0 }
	local right = vnormalize(vcross(world_up, forward))
	if vlength(right) < 0.01 then
		right = { x = 1, y = 0, z = 0 }
	end
	local up = vnormalize(vcross(forward, right))

	-- Roll rotates the wing/right axis and lift/up axis around the nose.
	local cr = math.cos(roll)
	local sr = math.sin(roll)
	local rolled_right = vadd(vmul(right, cr), vmul(up, sr))
	local rolled_up = vsub(vmul(up, cr), vmul(right, sr))

	return forward, vnormalize(rolled_up), vnormalize(rolled_right)
end

local function get_player(name)
	local player = minetest.get_player_by_name(name or "")
	if player and player:is_player() then
		return player
	end
	return nil
end

local function reset_bad_state(self, pos)
	self.velocity = { x = 0, y = 0, z = 0 }
	self.throttle = clamp(self.throttle or 0, 0, 1)
	self.pitch = 0
	self.roll = 0
	self.pitch_rate = 0
	self.roll_rate = 0
	self.yaw_rate = 0
	self.airspeed = 0
	self.altitude = 0
	self.vertical_speed = 0
	self.grounded = true
	self.stall = false
	self.braking = true
	set_attitude_from_yaw(self, self.yaw or 0)

	if finite_vec(pos) then
		self.object:set_pos({ x = pos.x, y = math.max(pos.y, GROUND_Y), z = pos.z })
	else
		self.object:set_pos({ x = 0, y = GROUND_Y, z = 0 })
	end
end

local function aircraft_config(self)
	return self.config or TRAINER
end

local function set_camera_mode(player, mode)
	if player.set_camera then
		player:set_camera({ mode = mode })
	end
end

local function get_camera_state(player)
	if player.get_camera then
		return player:get_camera()
	end
	return nil
end

local function chase_camera_position(self)
	local pos = safe_vec(self.object:get_pos(), { x = 0, y = GROUND_Y, z = 0 })
	return vadd(vadd(pos, vmul(self.up, PILOT_MOUNT_POS.y)), vmul(self.forward, PILOT_MOUNT_POS.z))
end

local function look_from_direction(dir)
	dir = vnormalize(dir)
	local horizontal = math.sqrt(dir.x * dir.x + dir.z * dir.z)

	return {
		yaw = minetest.dir_to_yaw({ x = dir.x, y = 0, z = dir.z }),
		pitch = -math.atan2(dir.y, math.max(horizontal, 0.0001)),
	}
end

local function chase_look_from_aircraft(self)
	orthonormalize_attitude(self)
	local camera_pos = chase_camera_position(self)
	local target = vadd(vadd(safe_vec(self.object:get_pos(), camera_pos), vmul(self.forward, CHASE_TARGET_FORWARD)), vmul(self.up, CHASE_TARGET_UP))
	return look_from_direction(vsub(target, camera_pos))
end

local function sync_pilot_view(player, self)
	player:set_pos(chase_camera_position(self))
	local look = chase_look_from_aircraft(self)
	-- While piloting, mouse look is deliberately overwritten every frame so
	-- aircraft attitude/camera chase geometry, not normal player mouselook,
	-- controls the view. Opening the config editor captures the mouse for
	-- numeric editing instead of letting it affect flight movement.
	player:set_look_horizontal(look.yaw)
	player:set_look_vertical(clamp(look.pitch, -1.45, 1.45))
end

local function set_player_pilot_state(player, plane)
	local name = player:get_player_name()
	local old_physics = player:get_physics_override()
	local first, back, front = player:get_eye_offset()

	flight_core.pilots[name] = {
		object = plane,
		old_physics = old_physics,
		eye_first = first,
		eye_back = back,
		eye_front = front,
		camera = get_camera_state(player),
	}

	local entity = plane:get_luaentity()
	if entity then
		player:set_pos(chase_camera_position(entity))
	end
	player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
	player:set_eye_offset(PILOT_EYE_FIRST, PILOT_EYE_BACK, PILOT_EYE_FRONT)
	set_camera_mode(player, "first")

	if flight_hud and flight_hud.show then
		flight_hud.show(player)
	end
end

local function restore_player_from_pilot(player, pilot, exit_pos)
	player:set_detach()
	player:set_physics_override(pilot.old_physics or { speed = 1, jump = 1, gravity = 1 })
	player:set_eye_offset(
		pilot.eye_first or { x = 0, y = 0, z = 0 },
		pilot.eye_back or { x = 0, y = 0, z = 0 },
		pilot.eye_front or { x = 0, y = 0, z = 0 }
	)
	if pilot.camera and pilot.camera.mode then
		set_camera_mode(player, pilot.camera.mode)
	else
		set_camera_mode(player, "first")
	end
	if finite_vec(exit_pos) then
		player:set_pos(exit_pos)
	end
	if flight_hud and flight_hud.hide then
		flight_hud.hide(player)
	end
end

local function release_stale_pilot(name, reason)
	local player = get_player(name)
	local pilot = flight_core.pilots[name]
	if not player or not pilot then
		flight_core.pilots[name] = nil
		return false
	end

	local pos = player:get_pos()
	restore_player_from_pilot(player, pilot, pos)
	flight_core.pilots[name] = nil
	flight_core.set_parachute(player, false, true)
	minetest.chat_send_player(name, reason or "Aircraft link lost. Pilot controls restored.")
	minetest.log("warning", "[flight_core] Released stale pilot state for " .. name)
	return true
end

function flight_core.exit_plane(player, message, options)
	options = options or {}
	local name = player:get_player_name()
	local pilot = flight_core.pilots[name]
	if not pilot then
		return false, "You are not piloting a plane."
	end

	local plane = pilot.object
	local exit_pos = player:get_pos()
	local entity = plane and plane:get_luaentity()
	if plane and plane:get_pos() then
		exit_pos = plane:get_pos()
		if options.eject and entity then
			orthonormalize_attitude(entity)
			exit_pos = vadd(vadd(exit_pos, vmul(entity.right, 2.3)), vmul(entity.up, 1.7))
		else
			exit_pos = { x = exit_pos.x + 3, y = math.max(exit_pos.y + 1, GROUND_Y + 1), z = exit_pos.z }
		end
	end

	if entity then
		entity.pilot_name = nil
		if options.eject then
			entity.unpiloted = true
			entity.braking = false
		else
			entity.unpiloted = false
			entity.throttle = 0
			entity.braking = true
		end
	end

	restore_player_from_pilot(player, pilot, exit_pos)
	flight_core.pilots[name] = nil

	if message then
		minetest.chat_send_player(name, message)
	end
	return true, "Exited plane."
end

function flight_core.eject_player(player)
	local name = player:get_player_name()
	local pilot = flight_core.pilots[name]
	if not pilot or not pilot.object then
		return false, "You are not piloting a plane."
	end

	local entity = pilot.object:get_luaentity()
	local plane_velocity = entity and safe_vec(entity.velocity) or { x = 0, y = 0, z = 0 }
	local plane_up = entity and safe_vec(entity.up, { x = 0, y = 1, z = 0 }) or { x = 0, y = 1, z = 0 }
	local ok, message = flight_core.exit_plane(player, "Ejected! Press Jump/Space, /p, or Shift+Place to toggle parachute.", { eject = true })
	if ok then
		player:set_velocity(vadd(plane_velocity, vmul(plane_up, 2.5)))
	end
	return ok, message
end

local function player_touching_ground(player)
	local pos = player:get_pos()
	if not finite_vec(pos) then
		return false
	end

	local y = math.floor(pos.y - 0.6)
	local samples = {
		{ x = pos.x, z = pos.z },
		{ x = pos.x + 0.28, z = pos.z },
		{ x = pos.x - 0.28, z = pos.z },
		{ x = pos.x, z = pos.z + 0.28 },
		{ x = pos.x, z = pos.z - 0.28 },
	}

	for _, sample in ipairs(samples) do
		if node_is_solid({ x = math.floor(sample.x + 0.5), y = y, z = math.floor(sample.z + 0.5) }) then
			return true
		end
	end
	return false
end

function flight_core.set_parachute(player, active, quiet)
	local name = player:get_player_name()
	if active and flight_core.pilots[name] then
		if not quiet then
			minetest.chat_send_player(name, "Parachute can only open after you leave or eject from the plane.")
		end
		return false
	end

	if active then
		if not flight_core.parachutes[name] then
			flight_core.parachutes[name] = {
				old_physics = player:get_physics_override(),
				old_armor_groups = player.get_armor_groups and player:get_armor_groups() or nil,
				landed = false,
				age = 0,
			}
		end
		player:set_physics_override({ gravity = PARACHUTE_GRAVITY })
		if player.set_armor_groups then
			local groups = {}
			if flight_core.parachutes[name].old_armor_groups then
				for key, value in pairs(flight_core.parachutes[name].old_armor_groups) do
					groups[key] = value
				end
			end
			groups.fall_damage_add_percent = -100
			player:set_armor_groups(groups)
		end
		if not quiet then
			minetest.chat_send_player(name, "Parachute open.")
		end
	else
		local chute = flight_core.parachutes[name]
		if chute then
			player:set_physics_override(chute.old_physics or { gravity = 1 })
			if player.set_armor_groups and chute.old_armor_groups then
				player:set_armor_groups(chute.old_armor_groups)
			end
			flight_core.parachutes[name] = nil
			if not quiet then
				minetest.chat_send_player(name, "Parachute closed.")
			end
		end
	end
	return true
end

function flight_core.toggle_parachute(player)
	local name = player:get_player_name()
	return flight_core.set_parachute(player, flight_core.parachutes[name] == nil)
end

local function cap_parachute_fall_speed(player, chute)
	local velocity = safe_vec(player:get_velocity())
	local age = chute and chute.age or 0
	local changed = false

	if velocity.y < -PARACHUTE_MAX_FALL_SPEED then
		velocity.y = -PARACHUTE_MAX_FALL_SPEED
		changed = true
	elseif age > PARACHUTE_OPEN_GRACE and velocity.y > 0.35 then
		velocity.y = velocity.y * 0.45
		changed = true
	elseif age > PARACHUTE_OPEN_GRACE * 2 and velocity.y > -PARACHUTE_TARGET_DESCENT then
		velocity.y = math.min(velocity.y, -PARACHUTE_TARGET_DESCENT)
		changed = true
	end

	if changed then
		player:set_velocity(velocity)
	end
end

local function damage_player_for_crash(player, severity)
	if not player or not player:is_player() then
		return
	end

	if severity >= TRAINER.crash_fatal_speed then
		player:set_hp(0, { type = "set_hp", from = "flight_core:aircraft_crash" })
		return
	end

	local damage = math.floor(clamp((severity - TRAINER.safe_taxi_speed) * 1.8, 4, 18))
	player:set_hp(math.max(0, player:get_hp() - damage), { type = "set_hp", from = "flight_core:aircraft_crash" })
end

local function random_scatter_velocity(power)
	local angle = math.random() * math.pi * 2
	local outward = 1.5 + math.random() * power
	return {
		x = math.cos(angle) * outward,
		y = 2.0 + math.random() * power,
		z = math.sin(angle) * outward,
	}
end

local function drop_crash_item(pos, item_name, count, power)
	for i = 1, count do
		local drop_pos = {
			x = pos.x + (math.random() - 0.5) * 1.2,
			y = pos.y + 0.8 + math.random() * 0.8,
			z = pos.z + (math.random() - 0.5) * 1.2,
		}
		local item = minetest.add_item(drop_pos, ItemStack(item_name))
		if item then
			item:set_velocity(random_scatter_velocity(power))
		end
	end
end

local function make_crash_crater(pos, radius)
	local r = math.floor(radius + 0.5)
	local center = vector.round(pos)

	for x = center.x - r, center.x + r do
		for y = center.y - r, center.y + r do
			for z = center.z - r, center.z + r do
				local dist = math.sqrt((x - center.x) ^ 2 + (y - center.y) ^ 2 + (z - center.z) ^ 2)
				if dist <= radius and math.random() < 0.78 then
					local p = { x = x, y = y, z = z }
					if node_is_solid(p) then
						local node_name = minetest.get_node(p).name
						local absorbed = damage_blast_resistant_node(p, node_name)
						if not absorbed then
							minetest.remove_node(p)
						end
					end
				end
			end
		end
	end
end

local function spawn_crash_explosion(pos, severity, scale)
	local blast_pos = safe_vec(pos, { x = 0, y = GROUND_Y, z = 0 })
	scale = clamp(scale or 1, 0.25, 5.0)
	local power = clamp((severity or 12) / 12, 1.0, 3.4)
	local radius = clamp((CRASH_BLAST_RADIUS + power * 0.35) * scale, 3.0, 18.0)

	make_crash_crater(blast_pos, radius)

	minetest.add_particlespawner({
		amount = math.floor(80 * scale),
		time = 0.25,
		minpos = { x = blast_pos.x - scale, y = blast_pos.y + 0.2, z = blast_pos.z - scale },
		maxpos = { x = blast_pos.x + scale, y = blast_pos.y + 1.5 * scale, z = blast_pos.z + scale },
		minvel = { x = -5 * scale, y = 3, z = -5 * scale },
		maxvel = { x = 5 * scale, y = 9 * scale, z = 5 * scale },
		minacc = { x = 0, y = -6, z = 0 },
		maxacc = { x = 0, y = -3, z = 0 },
		minexptime = 0.35,
		maxexptime = 0.8 + scale * 0.12,
		minsize = 3 * scale,
		maxsize = 7 * scale,
		collisiondetection = false,
		texture = "[fill:8x8:#ff8a1c",
		glow = 8,
	})

	minetest.add_particlespawner({
		amount = math.floor(65 * scale),
		time = 0.9,
		minpos = { x = blast_pos.x - 1.4 * scale, y = blast_pos.y + 0.4, z = blast_pos.z - 1.4 * scale },
		maxpos = { x = blast_pos.x + 1.4 * scale, y = blast_pos.y + 2.2 * scale, z = blast_pos.z + 1.4 * scale },
		minvel = { x = -1.5 * scale, y = 1.5, z = -1.5 * scale },
		maxvel = { x = 1.5 * scale, y = 4.0 * scale, z = 1.5 * scale },
		minacc = { x = 0, y = -0.4, z = 0 },
		maxacc = { x = 0, y = 0.2, z = 0 },
		minexptime = 1.2,
		maxexptime = 2.4 + scale * 0.28,
		minsize = 5 * scale,
		maxsize = 12 * scale,
		collisiondetection = false,
		texture = "[fill:8x8:#2c2c2ccc",
	})

	drop_crash_item(blast_pos, "flight_core:iron_ingot", math.max(1, math.floor(2 * scale)), 4.2 * scale)
	drop_crash_item(blast_pos, "flight_core:glass_block", math.max(1, math.floor(scale)), 3.3 * scale)
	drop_crash_item(blast_pos, "flight_core:dirt_block", math.max(3, math.floor(7 * scale)), 3.6 * scale)
end

local function crash_aircraft(self, pos, impact_speed, reason)
	if self.crashed then
		return true
	end

	self.crashed = true
	local crash_pos = safe_vec(pos, self.object:get_pos() or { x = 0, y = GROUND_Y, z = 0 })
	crash_pos.y = math.max(crash_pos.y, terrain_surface_y_at(crash_pos))
	self.object:set_pos(crash_pos)
	self.throttle = 0
	self.velocity = { x = 0, y = 0, z = 0 }
	if self.shadow_object then
		self.shadow_object:remove()
		self.shadow_object = nil
	end
	local severity = math.max(impact_speed or 0, self.airspeed or 0)
	spawn_crash_explosion(crash_pos, severity)

	local player = get_player(self.pilot_name)
	if player then
		flight_core.exit_plane(player, reason or string.format("Aircraft crash! Impact %.1f m/s.", severity))
		player:set_pos({ x = crash_pos.x + 4, y = crash_pos.y + 2, z = crash_pos.z })
		damage_player_for_crash(player, severity)
	end

	self.object:remove()
	return true
end

local function aircraft_entities_near(pos, radius)
	local found = {}
	for _, object in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
		local entity = object:get_luaentity()
		if entity and entity.name == "flight_core:biplane" and not entity.crashed then
			found[#found + 1] = entity
		end
	end
	return found
end

local function scramble_aircraft_config(entity, amount)
	entity.config = copy_trainer_config(entity.config or flight_core.default_config())
	local fields = {}
	for _, field in ipairs(CONFIG_FIELDS) do
		if field.kind ~= "text" then
			fields[#fields + 1] = field
		end
	end
	for i = 1, math.min(#fields, amount or 8) do
		local field = fields[math.random(1, #fields)]
		local value = tonumber(entity.config[field.key]) or TRAINER[field.key] or 1
		local sign = math.random() < 0.18 and -1 or 1
		local multiplier = 0.35 + math.random() * 2.4
		entity.config[field.key] = value * multiplier * sign
	end
end

local function cripple_aircraft(entity)
	entity.config = copy_trainer_config(entity.config or flight_core.default_config())
	entity.config.max_speed = 17
	entity.config.max_dive_speed = 22
	entity.config.thrust_accel = math.min(entity.config.thrust_accel or TRAINER.thrust_accel, 4.5)
	entity.config.lift_coeff = math.min(entity.config.lift_coeff or TRAINER.lift_coeff, 0.018)
	entity.config.drag_coeff = math.max(entity.config.drag_coeff or TRAINER.drag_coeff, 0.04)
	entity.config.stall_sensitivity = math.max(entity.config.stall_sensitivity or TRAINER.stall_sensitivity, 2.2)
end

local function notify_pilot(entity, message)
	local player = get_player(entity.pilot_name)
	if player then
		minetest.chat_send_player(entity.pilot_name, message)
	end
end

local function damage_aircraft_from_missile(entity, hit_pos, miss_distance, shooter_name)
	if not entity or entity.crashed then
		return
	end

	local hit = safe_vec(hit_pos, entity.object:get_pos() or { x = 0, y = GROUND_Y, z = 0 })
	local distance = miss_distance or 99
	if distance <= MISSILE_DIRECT_HIT_RADIUS then
		crash_aircraft(entity, hit, MISSILE_SPEED, "Aircraft destroyed by missile strike!")
	elseif distance <= MISSILE_CRIPPLE_RADIUS then
		cripple_aircraft(entity)
		entity.velocity = vmul(safe_vec(entity.velocity), 0.55)
		notify_pilot(entity, "Missile blast! Engine crippled: max speed forced to 17.")
	elseif distance <= MISSILE_SCRAMBLE_RADIUS then
		scramble_aircraft_config(entity, 10)
		notify_pilot(entity, "Missile near miss! Flight configuration scrambled. Open /fedit fast.")
	end
end

local function missile_explosion(pos, severity)
	spawn_crash_explosion(pos, severity or MISSILE_SPEED, 5)
end

local function nearest_missile_target(self, pos, dir)
	local best = nil
	local best_score = math.huge

	for _, entity in ipairs(aircraft_entities_near(pos, MISSILE_LOCK_RANGE)) do
		if entity.object ~= self.owner_object and entity.pilot_name ~= self.owner_name then
			local target_pos = entity.object:get_pos()
			if finite_vec(target_pos) then
				local to_target = vsub(target_pos, pos)
				local distance = vlength(to_target)
				local alignment = vdot(vnormalize(to_target), dir)
				-- These are early, marginal heat seekers: they strongly prefer
				-- targets already near the nose and barely notice aircraft behind.
				if alignment > -0.15 then
					local score = distance - alignment * 34
					if score < best_score then
						best = entity
						best_score = score
					end
				end
			end
		end
	end

	return best
end

local function missile_texture_frame(frame)
	return "missile_animated.png^[verticalframe:18:" .. tostring(frame % 18)
end

local function launch_missile_from_aircraft(entity, player)
	if not entity or entity.crashed or not entity.object then
		return false, "No aircraft is ready to fire."
	end
	if (entity.missile_cooldown or 0) > 0 then
		return false, "Missile cooling down."
	end

	orthonormalize_attitude(entity)
	local pos = safe_vec(entity.object:get_pos(), { x = 0, y = GROUND_Y, z = 0 })
	local launch_pos = vadd(vadd(pos, vmul(entity.forward, 5.5)), vmul(entity.up, 0.7))
	local missile = minetest.add_entity(launch_pos, "flight_core:missile")
	if not missile then
		return false, "Could not launch missile."
	end

	local missile_entity = missile:get_luaentity()
	if missile_entity then
		missile_entity.owner_object = entity.object
		missile_entity.owner_name = entity.pilot_name
		missile_entity.velocity = vmul(vnormalize(entity.forward), MISSILE_SPEED)
		missile_entity.life = MISSILE_LIFETIME
	end
	missile:set_rotation(safe_dir_rotation(entity.forward, entity.up))
	entity.missile_cooldown = MISSILE_COOLDOWN

	if player then
		minetest.chat_send_player(player:get_player_name(), "Missile away.")
	end
	return true, "Missile launched."
end

local function shadow_texture_for_altitude(altitude)
	local fade = 1 - clamp((altitude or 0) / SHADOW_MAX_ALTITUDE, 0, 1)
	local opacity = math.floor(clamp(35 + fade * 190, 0, 225))
	return "flight_core_plane_shadow.png^[opacity:" .. opacity
end

local function update_aircraft_shadow(self, pos, surface_y)
	if not finite_vec(pos) then
		return
	end

	surface_y = surface_y or terrain_surface_y_at(pos)
	local ground_y = surface_y - SHADOW_NODE_TOP_DELTA
	local altitude = math.max(0, pos.y - surface_y)
	if altitude > SHADOW_MAX_ALTITUDE then
		if self.shadow_object then
			self.shadow_object:remove()
			self.shadow_object = nil
		end
		return
	end

	if not self.shadow_object or not self.shadow_object:get_pos() then
		self.shadow_object = minetest.add_entity({ x = pos.x, y = ground_y + 0.035, z = pos.z }, "flight_core:plane_shadow")
		if not self.shadow_object then
			return
		end
		local shadow_entity = self.shadow_object:get_luaentity()
		if shadow_entity then
			shadow_entity.owner = self.object
		end
	end

	local fade = 1 - clamp(altitude / SHADOW_MAX_ALTITUDE, 0, 1)
	-- Close to the ground, make the shadow large and crisp enough to act as a
	-- landing-height cue. Higher up, shrink and fade it so it feels farther
	-- away instead of becoming a giant dark blotch.
	local scale = 0.55 + fade * 0.75
	local size_x = SHADOW_BASE_X * scale
	local size_z = SHADOW_BASE_Z * scale
	local opacity_bucket = math.floor((35 + fade * 190) / 12)

	self.shadow_object:set_pos({ x = pos.x, y = ground_y + 0.035, z = pos.z })
	self.shadow_object:set_rotation({ x = 0, y = minetest.dir_to_yaw({ x = self.forward.x, y = 0, z = self.forward.z }) + math.pi, z = 0 })

	local shadow_entity = self.shadow_object:get_luaentity()
	if shadow_entity
		and (shadow_entity.opacity_bucket ~= opacity_bucket
			or math.abs((shadow_entity.size_x or 0) - size_x) > 0.25
			or math.abs((shadow_entity.size_z or 0) - size_z) > 0.25) then
		shadow_entity.opacity_bucket = opacity_bucket
		shadow_entity.size_x = size_x
		shadow_entity.size_z = size_z
		self.shadow_object:set_properties({
			visual_size = { x = size_x, y = 1, z = size_z },
			textures = { shadow_texture_for_altitude(altitude) },
		})
	end
end

local function apply_controls(self, dtime, player)
	dtime = clamp(dtime or 0, 0, 0.2)
	local cfg = aircraft_config(self)
	local ctrl = player:get_player_control()
	self.missile_cooldown = math.max(0, (self.missile_cooldown or 0) - dtime)

	if ctrl.aux1 and ctrl.sneak then
		if not self.eject_button_down then
			self.eject_button_down = true
			flight_core.eject_player(player)
		end
		return true
	end
	self.eject_button_down = false

	-- Luanti gives server mods movement actions, not raw key identities. WASD,
	-- arrow keys, or any other client binding all arrive here as the same
	-- up/down/left/right controls, so true "extra" arrow bindings must be done
	-- in the player's client keymap rather than in this server-side mod.
	if ctrl.jump then
		self.throttle = clamp(self.throttle + dtime * 0.32, 0, 1)
	end
	if ctrl.sneak then
		self.throttle = clamp(self.throttle - dtime * 0.42, 0, 1)
	end

	local pitch_input = 0
	if ctrl.up then
		pitch_input = pitch_input - 1
	end
	if ctrl.down then
		pitch_input = pitch_input + 1
	end

	local roll_input = 0
	local rudder_input = 0
	if ctrl.aux1 then
		if ctrl.left then
			rudder_input = rudder_input - 1
		end
		if ctrl.right then
			rudder_input = rudder_input + 1
		end
	else
		if ctrl.left then
			roll_input = 1
		end
		if ctrl.right then
			roll_input = -1
		end
	end

	self.braking = ctrl.place or false
	if ctrl.dig and not self.fire_button_down then
		launch_missile_from_aircraft(self, player)
	end
	self.fire_button_down = ctrl.dig or false

	local speed = finite_or(self.forward_airspeed or self.airspeed or 0, 0)
	local lower_limit = finite_or(cfg.speed_lower_limit, TRAINER.speed_lower_limit)
	local control_speed = finite_or(cfg.control_speed, TRAINER.control_speed)
	local divisor = control_speed - lower_limit
	if math.abs(divisor) < 0.0001 then
		divisor = divisor < 0 and -0.0001 or 0.0001
	end
	local authority = clamp((speed - lower_limit) / divisor, 0.16, 1)
	if self.stall then
		authority = authority * 0.45
	end

	local rudder_power = finite_or(cfg.yaw_control, TRAINER.yaw_control)
		* finite_or(cfg.rudder_rate, TRAINER.rudder_rate)
		* finite_or(cfg.rudder_count, TRAINER.rudder_count)
	self.pitch_rate = self.pitch_rate * finite_or(cfg.pitch_damper, TRAINER.pitch_damper)
		+ pitch_input * finite_or(cfg.pitch_rate, TRAINER.pitch_rate) * authority * 0.18
	self.roll_rate = self.roll_rate * finite_or(cfg.roll_damper, TRAINER.roll_damper)
		+ roll_input * finite_or(cfg.roll_rate, TRAINER.roll_rate) * authority * 0.22
		+ rudder_input * finite_or(cfg.yaw_roll_coupling, TRAINER.yaw_roll_coupling) * authority * 0.08
	self.yaw_rate = self.yaw_rate * finite_or(cfg.yaw_damper, TRAINER.yaw_damper)
		+ rudder_input * rudder_power * authority * 0.22
		- roll_input * finite_or(cfg.adverse_yaw, TRAINER.adverse_yaw) * authority * 0.12

	if self.grounded then
		local steer = 0
		if ctrl.left then
			steer = steer - 1
		end
		if ctrl.right then
			steer = steer + 1
		end
		self.yaw_rate = self.yaw_rate + steer * clamp(horizontal_speed(self.velocity) / 8, 0.15, 0.7) * dtime
		self.roll_rate = self.roll_rate - self.roll * 3.0 * dtime
	end
end

local function integrate_physics(self, dtime)
	dtime = clamp(dtime or 0, 0, 0.2)
	local pos = safe_vec(self.object:get_pos(), { x = 0, y = GROUND_Y, z = 0 })
	self.velocity = safe_vec(self.velocity)
	self.throttle = clamp(self.throttle or 0, 0, 1)
	local cfg = aircraft_config(self)
	orthonormalize_attitude(self)
	self.pitch_rate = finite_or(self.pitch_rate, 0)
	self.roll_rate = finite_or(self.roll_rate, 0)
	self.yaw_rate = finite_or(self.yaw_rate, 0)

	local forward, up, right = self.forward, self.up, self.right
	local speed = vlength(self.velocity)
	local forward_speed = math.max(0, vdot(self.velocity, forward))
	local vdir = vnormalize(self.velocity)

	local angle_of_attack = math.asin(clamp(vdot(vdir, up), -1, 1))
	local stall_sensitivity = finite_or(cfg.stall_sensitivity, TRAINER.stall_sensitivity)
	local stall_threshold = 0.78 / math.max(math.abs(stall_sensitivity), 0.0001)
	self.stall = forward_speed < TRAINER.stall_speed * stall_sensitivity or math.abs(angle_of_attack) > stall_threshold

	-- Aircraft attitude is stored as local axes. Roll rotates around the nose,
	-- pitch rotates around the wing/right axis, and rudder yaws around aircraft
	-- up. Banked turns now come from banking then pulling, not from flat world yaw.
	local pitch_angle = -self.pitch_rate * dtime
	self.forward = rotate_about_axis(self.forward, self.right, pitch_angle)
	self.up = rotate_about_axis(self.up, self.right, pitch_angle)

	self.right = rotate_about_axis(self.right, self.forward, self.roll_rate * dtime)
	self.up = rotate_about_axis(self.up, self.forward, self.roll_rate * dtime)

	self.forward = rotate_about_axis(self.forward, self.up, self.yaw_rate * dtime)
	self.right = rotate_about_axis(self.right, self.up, self.yaw_rate * dtime)
	orthonormalize_attitude(self)
	forward, up, right = self.forward, self.up, self.right

	if self.stall and not self.grounded then
		-- A stall bleeds lift, adds drag, weakens controls, and makes the nose fall.
		local nose_drop = (0.35 + clamp((TRAINER.stall_speed * stall_sensitivity - forward_speed) / math.max(TRAINER.stall_speed, 0.0001), 0, 1) * 0.55) * dtime
		self.forward = rotate_about_axis(self.forward, self.right, nose_drop)
		self.up = rotate_about_axis(self.up, self.right, nose_drop)
		orthonormalize_attitude(self)
		self.roll_rate = self.roll_rate * 0.96
	end

	if self.grounded then
		local ground_yaw = minetest.dir_to_yaw({ x = self.forward.x, y = 0, z = self.forward.z })
		set_attitude_from_yaw(self, ground_yaw)
		self.roll_rate = self.roll_rate * math.max(0, 1 - 4 * dtime)
	end

	forward, up, right = self.forward, self.up, self.right
	speed = vlength(self.velocity)
	forward_speed = math.max(0, vdot(self.velocity, forward))
	vdir = vnormalize(self.velocity)

	angle_of_attack = clamp(math.asin(clamp(vdot(vdir, up), -1, 1)), -1.2, 1.2)
	stall_sensitivity = finite_or(cfg.stall_sensitivity, TRAINER.stall_sensitivity)
	stall_threshold = 0.72 / math.max(math.abs(stall_sensitivity), 0.0001)
	self.stall = forward_speed < TRAINER.stall_speed * stall_sensitivity or math.abs(angle_of_attack) > stall_threshold

	local lift_factor = self.stall and 0.18 or clamp(0.58 + angle_of_attack * 0.95, 0.12, 1.35)
	-- Lift is based on airflow over the wings and angle of attack, not total
	-- vertical speed. Nose-up raises lift until stall; nose-down lowers lift.
	local lift = vmul(up, finite_or(cfg.lift_coeff, TRAINER.lift_coeff) * forward_speed * forward_speed * lift_factor)
	-- Thrust always pushes through the aircraft nose. If the nose points down,
	-- power helps the dive; if the nose points up, power helps the climb.
	local thrust = vmul(forward, finite_or(cfg.thrust_accel, TRAINER.thrust_accel) * self.throttle)
	local descent_speed = math.max(0, -self.velocity.y)
	local dive_factor = clamp(
		(descent_speed - TRAINER.dive_descent_start) / (TRAINER.dive_descent_full - TRAINER.dive_descent_start),
		0,
		1
	)
	-- As a dive steepens, let gravity "run away" a bit: fast downward motion
	-- increases effective gravity and opens the speed limiter toward a higher
	-- dive speed. This gives steep descents the accelerating, dangerous feel
	-- expected from an old flight sim while keeping the numbers bounded.
	local gravity_scale = finite_or(cfg.plane_gravity_effect, TRAINER.plane_gravity_effect)
		* (1 + dive_factor * finite_or(cfg.dive_gravity_multiplier, TRAINER.dive_gravity_multiplier))
	local gravity = { x = 0, y = -GRAVITY * gravity_scale, z = 0 }

	local drag_coeff = finite_or(cfg.drag_coeff, TRAINER.drag_coeff)
	if self.stall then
		drag_coeff = drag_coeff + finite_or(cfg.stall_drag_coeff, TRAINER.stall_drag_coeff)
	end
	if self.braking then
		drag_coeff = drag_coeff + finite_or(cfg.brake_drag_coeff, TRAINER.brake_drag_coeff)
	end
	drag_coeff = drag_coeff + math.abs(angle_of_attack) * 0.018
	local drag = vmul(vdir, -drag_coeff * speed * speed)
	local side_speed = vdot(self.velocity, right)
	local side_slip_drag = vmul(right, -side_speed * finite_or(cfg.side_slip_drag, TRAINER.side_slip_drag))

	local accel = vadd(vadd(thrust, lift), vadd(vadd(gravity, drag), side_slip_drag))

	if self.grounded then
		accel.x = accel.x - self.velocity.x * finite_or(cfg.ground_friction, TRAINER.ground_friction)
		accel.z = accel.z - self.velocity.z * finite_or(cfg.ground_friction, TRAINER.ground_friction)
		if self.braking then
			accel.x = accel.x - self.velocity.x * 1.2
			accel.z = accel.z - self.velocity.z * 1.2
		end
	end

	self.velocity = vadd(self.velocity, vmul(accel, dtime))
	local configured_max_speed = finite_or(cfg.max_speed, TRAINER.max_speed)
	local configured_dive_speed = finite_or(cfg.max_dive_speed, TRAINER.max_dive_speed)
	local dive_speed_limit = configured_max_speed + dive_factor * (configured_dive_speed - configured_max_speed)
	self.velocity = limit_vector(safe_vec(self.velocity), dive_speed_limit)
	local current_speed = vlength(self.velocity)

	local new_pos = vadd(pos, vmul(self.velocity, dtime))
	if not finite_vec(new_pos) then
		minetest.log("warning", "[flight_core] Recovered invalid aircraft physics state")
		reset_bad_state(self, pos)
		return
	end

	local was_grounded = self.grounded
	local surface_y = aircraft_surface_y(self, new_pos)
	local block_hit = detect_block_impact(self, pos, new_pos)
	if block_hit then
		local slow_ground_bump = was_grounded
			and current_speed < TRAINER.safe_taxi_speed
			and new_pos.y <= surface_y + 0.75

		if not slow_ground_bump then
			crash_aircraft(
				self,
				block_hit.pos or new_pos,
				current_speed,
				string.format("Aircraft crash! Hit %s at %.1f m/s.", block_hit.node or "terrain", current_speed)
			)
			return
		end
	end

	local impact_descent_speed = math.max(0, -self.velocity.y)
	if new_pos.y <= surface_y then
		local hard_vertical_hit = impact_descent_speed > TRAINER.crash_descent_speed and current_speed > TRAINER.crash_min_speed
		local fast_nose_down_hit = current_speed > TRAINER.crash_fast_speed and impact_descent_speed > 4 and self.forward.y < -0.25
		if not was_grounded and (hard_vertical_hit or fast_nose_down_hit) then
			crash_aircraft(
				self,
				new_pos,
				current_speed,
				string.format("Crash landing! Impact %.1f m/s downward at %.1f m/s.", impact_descent_speed, current_speed)
			)
			return
		end

		new_pos.y = surface_y
		if self.velocity.y < 0 then
			self.velocity.y = 0
		end
		self.grounded = true
	else
		self.grounded = false
	end

	if not finite_vec(self.velocity) or not finite_vec(new_pos) then
		minetest.log("warning", "[flight_core] Recovered invalid aircraft physics state")
		reset_bad_state(self, pos)
		return
	end

	self.object:set_pos(new_pos)
	update_display_angles(self)
	self.object:set_rotation(object_rotation(self))
	self.object:set_velocity({ x = 0, y = 0, z = 0 })

	self.airspeed = vlength(self.velocity)
	self.forward_airspeed = forward_speed
	-- HUD altitude is AGL: height above the highest solid block directly
	-- beneath the aircraft, not height above the world's original flat runway.
	self.altitude = math.max(0, new_pos.y - surface_y)
	self.vertical_speed = self.velocity.y
	update_aircraft_shadow(self, new_pos, surface_y)
end

minetest.register_entity("flight_core:plane_shadow", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "mesh",
		mesh = "flight_core_plane_shadow.obj",
		visual_size = { x = SHADOW_BASE_X, y = 1, z = SHADOW_BASE_Z },
		textures = { "flight_core_plane_shadow.png^[opacity:210" },
		use_texture_alpha = true,
		static_save = false,
		glow = -1,
	},

	on_step = function(self, dtime)
		if not self.owner or not self.owner:get_pos() then
			self.object:remove()
		end
	end,
})

minetest.register_entity("flight_core:missile", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		visual_size = { x = 1.4, y = 2.45, z = 1.4 },
		textures = { missile_texture_frame(0) },
		use_texture_alpha = true,
		static_save = false,
		glow = 8,
	},

	on_activate = function(self, staticdata, dtime_s)
		self.velocity = self.velocity or { x = 0, y = 0, z = MISSILE_SPEED }
		self.life = self.life or MISSILE_LIFETIME
		self.anim_timer = 0
		self.anim_frame = 0
		self.age = 0
		self.target_scan_timer = 0
		self.proximity_scan_timer = 0
	end,

	on_step = function(self, dtime)
		dtime = clamp(dtime or 0, 0, 0.12)
		local pos = self.object:get_pos()
		if not finite_vec(pos) then
			self.object:remove()
			return
		end

		self.age = (self.age or 0) + dtime
		self.life = (self.life or MISSILE_LIFETIME) - dtime
		if self.life <= 0 then
			self.object:remove()
			return
		end

		local dir = vnormalize(safe_vec(self.velocity, { x = 0, y = 0, z = MISSILE_SPEED }))
		if vlength(dir) < 0.001 then
			dir = { x = 0, y = 0, z = 1 }
		end

		self.target_scan_timer = (self.target_scan_timer or 0) - dtime
		if self.target_scan_timer <= 0 then
			self.target_scan_timer = MISSILE_TARGET_SCAN_INTERVAL
			self.cached_target = nearest_missile_target(self, pos, dir)
		end

		local target = self.cached_target
		if target and (target.crashed or not target.object or not target.object:get_pos()) then
			self.cached_target = nil
			target = nil
		end
		if target and target.object and target.object:get_pos() then
			local desired = vnormalize(vsub(target.object:get_pos(), pos))
			local alignment = vdot(dir, desired)
			local turn = MISSILE_HOMING_RATE * dtime * clamp((alignment + 0.35) / 1.35, 0.2, 1.0)
			dir = vnormalize(vadd(vmul(dir, 1 - turn), vmul(desired, turn)))
		end

		self.velocity = vmul(dir, MISSILE_SPEED)
		local new_pos = vadd(pos, vmul(self.velocity, dtime))

		local ray = minetest.raycast(pos, new_pos, true, true)
		for pointed in ray do
			if pointed.type == "node" and pointed.under and node_is_solid(pointed.under) then
				local hit = pointed.intersection_point or new_pos
				local node_name = minetest.get_node(pointed.under).name
				local absorbed = damage_blast_resistant_node(pointed.under, node_name)
				if absorbed then
					self.object:remove()
					return
				end
				missile_explosion(hit, MISSILE_SPEED)
				self.object:remove()
				return
			elseif pointed.type == "object" and pointed.ref ~= self.object and pointed.ref ~= self.owner_object then
				local entity = pointed.ref:get_luaentity()
				if entity and entity.name == "flight_core:biplane" and not entity.crashed then
					local hit = pointed.intersection_point or new_pos
					damage_aircraft_from_missile(entity, hit, 0, self.owner_name)
					missile_explosion(hit, MISSILE_SPEED)
					self.object:remove()
					return
				end
			end
		end

		self.proximity_scan_timer = (self.proximity_scan_timer or 0) - dtime
		if self.proximity_scan_timer <= 0 then
			self.proximity_scan_timer = MISSILE_PROXIMITY_SCAN_INTERVAL
			for _, entity in ipairs(aircraft_entities_near(new_pos, MISSILE_SCRAMBLE_RADIUS)) do
				if entity.object ~= self.owner_object and entity.pilot_name ~= self.owner_name then
					local plane_pos = entity.object:get_pos()
					local distance = plane_pos and vlength(vsub(plane_pos, new_pos)) or 99
					if distance <= MISSILE_SCRAMBLE_RADIUS then
						damage_aircraft_from_missile(entity, new_pos, distance, self.owner_name)
						missile_explosion(new_pos, MISSILE_SPEED)
						self.object:remove()
						return
					end
				end
			end
		end

		self.object:set_pos(new_pos)
		self.object:set_rotation(safe_dir_rotation(dir, { x = 0, y = 1, z = 0 }))

		self.anim_timer = (self.anim_timer or 0) + dtime
		local frame = math.floor(self.anim_timer * MISSILE_ANIM_FPS) % 18
		if frame ~= self.anim_frame then
			self.anim_frame = frame
			self.object:set_properties({ textures = { missile_texture_frame(frame) } })
		end
	end,
})

local function detect_aircraft_touch_crash(self)
	if self.crashed or not self.object then
		return
	end

	local pos = self.object:get_pos()
	if not finite_vec(pos) then
		return
	end

	for _, other in ipairs(aircraft_entities_near(pos, AIRCRAFT_TOUCH_RADIUS)) do
		if other ~= self and other.object ~= self.object and not other.crashed then
			local other_pos = other.object:get_pos()
			if finite_vec(other_pos) and vlength(vsub(other_pos, pos)) <= AIRCRAFT_TOUCH_RADIUS then
				local relative = vlength(vsub(safe_vec(self.velocity), safe_vec(other.velocity)))
				local severity = math.max(relative, self.airspeed or 0, other.airspeed or 0, TRAINER.crash_fatal_speed)
				crash_aircraft(self, pos, severity, "Aircraft collision!")
				crash_aircraft(other, other_pos, severity, "Aircraft collision!")
				return
			end
		end
	end
end

minetest.register_entity("flight_core:biplane", {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = { -1.2, -0.5, -1.8, 1.2, 0.7, 1.8 },
		selectionbox = { -4.8, -2.0, -0.4, 4.8, 2.0, 0.4 },
		visual = "mesh",
		mesh = "flight_core_plane_card.obj",
		visual_size = { x = 11, y = 11, z = 11 },
		textures = { "flight_core_plane_back_main.png" },
		use_texture_alpha = true,
		static_save = true,
	},

	update_texture = function(self)
		self.plane_color = resolve_plane_color(self.config, self.plane_color)
		self.object:set_properties({
			textures = { plane_texture_for_color(self.plane_color) },
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		local saved
		if staticdata and staticdata ~= "" then
			saved = minetest.deserialize(staticdata)
		end
		self.velocity = { x = 0, y = 0, z = 0 }
		self.throttle = 0
		self.pitch = 0
		self.roll = 0
		self.yaw = 0
		self.pitch_rate = 0
		self.roll_rate = 0
		self.yaw_rate = 0
		self.airspeed = 0
		self.altitude = 0
		self.vertical_speed = 0
		self.grounded = true
		self.stall = false
		self.braking = false
		self.config = flight_core.default_config()
		self.plane_color = resolve_plane_color(self.config)
		self.config.plane_color = self.plane_color
		set_attitude_from_yaw(self, 0)
		if type(saved) == "table" then
			self.velocity = safe_vec(saved.velocity)
			self.throttle = clamp(saved.throttle or 0, 0, 1)
			self.pitch_rate = finite_or(saved.pitch_rate, 0)
			self.roll_rate = finite_or(saved.roll_rate, 0)
			self.yaw_rate = finite_or(saved.yaw_rate, 0)
			self.config = copy_trainer_config(saved.config or self.config)
			self.plane_color = resolve_plane_color(self.config, saved.plane_color)
			self.config.plane_color = self.plane_color
			self.forward = safe_vec(saved.forward, self.forward)
			self.right = safe_vec(saved.right, self.right)
			self.up = safe_vec(saved.up, self.up)
			orthonormalize_attitude(self)
			update_display_angles(self)
		end
		self:update_texture()
	end,

	get_staticdata = function(self)
		if self.crashed then
			return ""
		end

		return minetest.serialize({
			velocity = self.velocity,
			throttle = self.throttle,
			pitch_rate = self.pitch_rate,
			roll_rate = self.roll_rate,
			yaw_rate = self.yaw_rate,
			config = self.config,
			plane_color = self.plane_color,
			forward = self.forward,
			right = self.right,
			up = self.up,
		})
	end,

	on_step = function(self, dtime)
		local player = get_player(self.pilot_name)
		if player then
			local pilot = flight_core.pilots[self.pilot_name]
			if not pilot or pilot.object ~= self.object then
				release_stale_pilot(self.pilot_name, "Aircraft link interrupted. Pilot controls restored.")
				self.pilot_name = nil
				player = nil
			end
		end

		if player then
			if apply_controls(self, dtime, player) then
				player = nil
			end
		else
			if self.pilot_name then
				release_stale_pilot(self.pilot_name, "Aircraft pilot left or disconnected. Pilot controls restored.")
				self.pilot_name = nil
			end
			if self.unpiloted then
				self.braking = false
			else
				self.throttle = 0
				self.braking = true
			end
		end

		integrate_physics(self, dtime)
		if self.crashed then
			return
		end
		self.touch_scan_timer = (self.touch_scan_timer or 0) + dtime
		if self.touch_scan_timer >= AIRCRAFT_TOUCH_SCAN_INTERVAL then
			self.touch_scan_timer = 0
			detect_aircraft_touch_crash(self)
		end
		if self.crashed then
			return
		end

		if player then
			sync_pilot_view(player, self)
		end

		if player and flight_hud and flight_hud.update then
			self.hud_update_timer = (self.hud_update_timer or 0) + dtime
		end
		if player and flight_hud and flight_hud.update and self.hud_update_timer >= HUD_UPDATE_INTERVAL then
			self.hud_update_timer = 0
			flight_hud.update(player, {
				airspeed = self.airspeed,
				altitude = self.altitude,
				vertical_speed = self.vertical_speed,
				throttle = self.throttle,
				grounded = self.grounded,
				stall = self.stall,
				pitch = self.pitch,
				roll = self.roll,
				config = self.config,
			})
		end
	end,
})

function flight_core.spawn_plane(player)
	local name = player:get_player_name()
	if flight_core.pilots[name] then
		flight_core.exit_plane(player)
	end
	flight_core.set_parachute(player, false, true)

	local pos = player:get_pos()
	local yaw = player:get_look_horizontal()
	local forward = yaw_to_forward(yaw)
	local spawn_pos = {
		x = pos.x + forward.x * 4,
		y = math.max(pos.y + 0.4, GROUND_Y),
		z = pos.z + forward.z * 4,
	}

	local object = minetest.add_entity(spawn_pos, "flight_core:biplane")
	if not object then
		return false, "Could not spawn aircraft."
	end

	local entity = object:get_luaentity()
	entity.pilot_name = name
	entity.yaw = yaw
	entity.pitch = 0
	entity.roll = 0
	entity.grounded = true
	local player_config = flight_core.get_config(name)
	clear_old_damage_signature(player_config)
	entity.config = copy_trainer_config(player_config)
	entity.plane_color = resolve_plane_color(entity.config)
	entity.config.plane_color = entity.plane_color
	set_attitude_from_yaw(entity, yaw)
	if entity.update_texture then
		entity:update_texture()
	end
	object:set_rotation(object_rotation(entity))

	set_player_pilot_state(player, object)
	return true, "Skywright trainer spawned. Jump/Sneak throttle, W/S pitch, A/D roll, Aux+A/D rudder, Place brake, Punch or /fire missile, Shift+E eject. /fedit config."
end

minetest.register_chatcommand("plane", {
	description = "Spawn and enter the Skywright prototype trainer aircraft.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		return flight_core.spawn_plane(player)
	end,
})

minetest.register_chatcommand("exitplane", {
	description = "Exit the current Skywright trainer aircraft.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		return flight_core.exit_plane(player)
	end,
})

minetest.register_chatcommand("eject", {
	description = "Eject from the current aircraft and leave it flying unpiloted.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		return flight_core.eject_player(player)
	end,
})

minetest.register_chatcommand("chute", {
	description = "Toggle your parachute after leaving or ejecting from a plane.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		return flight_core.toggle_parachute(player)
	end,
})

minetest.register_chatcommand("p", {
	description = "Toggle your parachute after leaving or ejecting from a plane.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		return flight_core.toggle_parachute(player)
	end,
})

minetest.register_chatcommand("parachute", {
	description = "Toggle your parachute after leaving or ejecting from a plane.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		return flight_core.toggle_parachute(player)
	end,
})

minetest.register_chatcommand("fire", {
	description = "Fire a heat-seeking missile from your current aircraft.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		local pilot = flight_core.pilots[name]
		if not pilot or not pilot.object then
			return false, "You are not piloting a plane."
		end
		local entity = pilot.object:get_luaentity()
		return launch_missile_from_aircraft(entity, player)
	end,
})

minetest.register_chatcommand("fcfg", {
	description = "Toggle the in-flight configuration console.",
	params = "[edit]",
	func = function(name, param)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		if param == "edit" then
			if not flight_hud or not flight_hud.show_config_editor then
				return false, "Flight HUD is not loaded."
			end
			return flight_hud.show_config_editor(player)
		end
		if not flight_hud or not flight_hud.toggle_console then
			return false, "Flight HUD is not loaded."
		end

		local visible = flight_hud.toggle_console(player)
		return true, visible and "Flight config console shown." or "Flight config console minimized."
	end,
})

minetest.register_chatcommand("fedit", {
	description = "Open the editable in-flight configuration console.",
	func = function(name)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		if not flight_hud or not flight_hud.show_config_editor then
			return false, "Flight HUD is not loaded."
		end
		return flight_hud.show_config_editor(player)
	end,
})

minetest.register_chatcommand("fpage", {
	description = "Change the flight configuration console page.",
	params = "next|prev|<number>",
	func = function(name, param)
		local player = get_player(name)
		if not player then
			return false, "Player not found."
		end
		if not flight_hud or not flight_hud.set_console_page then
			return false, "Flight HUD is not loaded."
		end

		local page, pages = flight_hud.set_console_page(player, param ~= "" and param or "next")
		return true, string.format("Flight config page %d/%d.", page, pages)
	end,
})

minetest.register_chatcommand("fset", {
	description = "Set a flight configuration value live for your aircraft.",
	params = "<key> <value>",
	func = function(name, param)
		local key, value = param:match("^%s*(%S+)%s+(.+)%s*$")
		if not key or not value then
			return false, "Usage: /fset <key> <value>. Example: /fset pitch 1.4 or /fset color blue"
		end

		return flight_core.set_config_value(name, key, value)
	end,
})

minetest.register_chatcommand("fsave", {
	description = "Save your current flight configuration.",
	func = function(name)
		flight_core.save_config(name, flight_core.get_config(name))
		return true, "Flight configuration saved."
	end,
})

minetest.register_chatcommand("freset", {
	description = "Reset your flight configuration to Skywright defaults.",
	func = function(name)
		flight_core.reset_config(name)
		return true, "Flight configuration reset to defaults."
	end,
})

minetest.register_chatcommand("flist", {
	description = "List flight configuration keys.",
	func = function(name)
		local keys = {}
		for _, field in ipairs(CONFIG_FIELDS) do
			keys[#keys + 1] = field.key
		end
		return true, "Flight config keys: " .. table.concat(keys, ", ")
	end,
})

minetest.register_chatcommand("pilotreset", {
	description = "Restore player controls if an aircraft link gets stuck.",
	func = function(name)
		if release_stale_pilot(name, "Pilot controls restored.") then
			return true, "Pilot state reset."
		end
		return false, "You are not currently locked to an aircraft."
	end,
})

minetest.register_chatcommand("unstuckpilot", {
	description = "Alias for /pilotreset.",
	func = function(name)
		if release_stale_pilot(name, "Pilot controls restored.") then
			return true, "Pilot state reset."
		end
		return false, "You are not currently locked to an aircraft."
	end,
})

function flight_core.show_manual(player)
	if not player or not player:is_player() then
		return false, "Player not found."
	end

	local formspec = table.concat({
		"formspec_version[4]",
		"size[12.6,8.8]",
		"no_prepend[]",
		"bgcolor[#071416E8;true]",
		"style_type[label;textcolor=#AEEBFF]",
		"style_type[textarea;textcolor=#EAF8FF;border=false;bgcolor=#06282CCC]",
		"style_type[button;textcolor=#EAF8FF;bgcolor=#104F59CC]",
		"label[0.45,0.35;Skywright Flight Manual]",
		"textarea[0.45,0.85;11.7,7.05;manual;;" .. minetest.formspec_escape(MANUAL_TEXT) .. "]",
		"button_exit[10.45,8.05;1.7,0.5;close;Close]",
	}, "")

	minetest.show_formspec(player:get_player_name(), MANUAL_FORM, formspec)
	return true, "Opened Skywright manual."
end

local function manual_command(name)
	local player = get_player(name)
	if not player then
		return false, "Player not found."
	end
	return flight_core.show_manual(player)
end

minetest.register_chatcommand("manual", {
	description = "Open the Skywright Flight manual.",
	func = manual_command,
})

minetest.register_chatcommand("flightmanual", {
	description = "Open the Skywright Flight manual.",
	func = manual_command,
})

minetest.register_chatcommand("controls", {
	description = "Open the Skywright Flight controls manual.",
	func = manual_command,
})

minetest.register_on_joinplayer(function(player)
	minetest.after(1.8, function()
		if player and player:is_player() then
			flight_core.show_manual(player)
		end
	end)
end)

minetest.register_globalstep(function(dtime)
	for name, pilot in pairs(flight_core.pilots) do
		local object = pilot and pilot.object
		local entity = object and object:get_luaentity()
		if not object or not object:get_pos() or not entity or entity.name ~= "flight_core:biplane" then
			release_stale_pilot(name, "Aircraft disappeared. Pilot controls restored.")
		elseif entity.pilot_name ~= name then
			release_stale_pilot(name, "Aircraft link changed. Pilot controls restored.")
		end
	end

	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local ctrl = player:get_player_control()
		local airborne = not player_touching_ground(player)
		-- Server-side Luanti does not expose raw keys like "P"; it exposes
		-- controls such as jump/place/sneak. Use airborne Jump as the practical
		-- one-key parachute toggle, plus Shift+Place as a backup chord.
		local chute_shortcut = not flight_core.pilots[name] and ((ctrl.sneak and ctrl.place) or (ctrl.jump and airborne))

		if chute_shortcut and not flight_core.chute_button_down then
			flight_core.chute_button_down = {}
		end
		if chute_shortcut and not flight_core.chute_button_down[name] then
			flight_core.chute_button_down[name] = true
			flight_core.toggle_parachute(player)
		elseif not chute_shortcut and flight_core.chute_button_down then
			flight_core.chute_button_down[name] = false
		end

		if flight_core.parachutes[name] then
			local chute = flight_core.parachutes[name]
			chute.age = (chute.age or 0) + dtime
			if flight_core.pilots[name] then
				flight_core.set_parachute(player, false, true)
			elseif player_touching_ground(player) then
				local velocity = safe_vec(player:get_velocity())
				if velocity.y < 0 then
					velocity.y = 0
					player:set_velocity(velocity)
				end
				if not chute.landed then
					chute.landed = true
					minetest.after(0.35, function()
						local still_player = get_player(name)
						if still_player and flight_core.parachutes[name] and not flight_core.pilots[name] then
							flight_core.set_parachute(still_player, false, true)
						end
					end)
				end
			else
				chute.landed = false
				player:set_physics_override({ gravity = PARACHUTE_GRAVITY })
				cap_parachute_fall_speed(player, chute)
			end
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	flight_core.parachutes[name] = nil
	if flight_core.chute_button_down then
		flight_core.chute_button_down[name] = nil
	end
	local pilot = flight_core.pilots[name]
	if pilot and pilot.object then
		local entity = pilot.object:get_luaentity()
		if entity then
			entity.pilot_name = nil
			entity.throttle = 0
			entity.braking = true
		end
	end
	flight_core.pilots[name] = nil
end)
