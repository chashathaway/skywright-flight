local WORLD = {}

local WORLD_STORAGE = minetest.get_mod_storage()

local RUNWAY_COUNT = 12
local RUNWAY_CENTER_RADIUS = 150
local RUNWAY_HALF_WIDTH = 8
local RUNWAY_BACK = -80
local RUNWAY_FRONT = 90
local AIRFIELD_HALF_WIDTH = 42
local AIRFIELD_BACK = -105
local AIRFIELD_FRONT = 105
local RUNWAY_SPAWN_FORWARD = -45
local AIRFIELD_RING_OUTER_RADIUS = RUNWAY_CENTER_RADIUS + math.max(math.abs(AIRFIELD_BACK), math.abs(AIRFIELD_FRONT)) + AIRFIELD_HALF_WIDTH + 8

local CLOUD_SHADOW_INTENSITY = 0.04
local CLOUD_DENSITY = 0.4

local TEX_GRASS_TOP = "mcl_core_grass_block_top.png"
local TEX_GRASS_SIDE = "mcl_core_grass_path_side.png^mcl_core_grass_block_side_overlay.png"
local TEX_PATH_TOP = "mcl_core_grass_path_top.png"
local TEX_PATH_SIDE = "mcl_core_grass_path_side.png"
local TEX_COLD_GRASS_TOP = "cold_ridge_grass.png"
local TEX_COLD_GRASS_SIDE = "cold_ridge_grass_side.png"
local TEX_DIRT = "dirt.png"
local TEX_STONE = "default_stone.png"
local TEX_COBBLE = "default_cobble.png"
local TEX_SAND = "default_sand.png"
local TEX_RUNWAY = "runway.png"
local TEX_STRIPE = "stripe.png"
local TEX_MARKER = "spawn_marker.png"
local TEX_TRUNK = "default_tree.png"
local TEX_TRUNK_TOP = "default_tree_top.png"
local TEX_PLANKS = "wood_plank.png"
local TEX_LEAVES = "default_leaves.png"
local TEX_TORCH = "default_torch_on_floor.png"
local TEX_TORCH_ANIM = "default_torch_on_floor_animated.png"
local TEX_LEAVES_AUTUMN = "leaves_autumn.png"
local TEX_LEAVES_SERVICEBERRY = "leaves_serviceberry.png"
local TEX_FLOWER_TALLGRASS = "flowers_tallgrass.png"
local TEX_FLOWER_FERN = "flowers_fern.png"
local TEX_FLOWER_CLOVER = "flowers_fourleaf_clover.png"
local TEX_FLOWER_POPPY = "flowers_poppy.png"
local TEX_FLOWER_TULIP_RED = "flowers_tulip_red.png"
local TEX_FLOWER_TULIP_PINK = "flowers_tulip_pink.png"
local TEX_FLOWER_OXEYE = "flowers_oxeye_daisy.png"
local TEX_FLOWER_LILY = "flowers_lily_of_the_valley.png"
local TEX_STICK = "stick.png"
local TEX_IRON_INGOT = "iron_ingot.png"
local TEX_STEEL_INGOT = "steel_ingot.png"
local TEX_TITANIUM_ORE = "titanium_ore.png"
local TEX_TITANIUM_LUMP = "titanium_lump.png"
local TEX_TITANIUM_INGOT = "titanium_ingot.png"
local TEX_TITANIUM_BLOCK = "titanium_block.png"
local TEX_TITANIUM_SHEET = "titanium_sheet.png"
local TEX_COAL_ORE = "mineral_coal.png"
local TEX_COAL_LUMP = "coal_lump.png"
local TEX_GLASS = "glass.png"
local TEX_PICK_WOOD = "pickaxe_wood.png"
local TEX_PICK_STONE = "pickaxe_stone.png"
local TEX_PICK_IRON = "pickaxe_iron.png"
local TEX_PICK_STEEL = "pickaxe_iron.png"
local TEX_PICK_TITANIUM = "pickaxe_titanium.png"
local TEX_AXE_WOOD = "axe_wood.png"
local TEX_AXE_STONE = "axe_stone.png"
local TEX_AXE_IRON = "axe_iron.png"
local TEX_AXE_STEEL = "axe_steel.png"
local TEX_AXE_TITANIUM = "axe_steel.png^[colorize:#cfd6dd:90"
local TEX_SHOVEL_WOOD = "shovel_wood.png"
local TEX_SHOVEL_STONE = "shovel_stone.png"
local TEX_SHOVEL_IRON = "shovel_iron.png"
local TEX_SHOVEL_STEEL = "shovel_steel.png"
local TEX_SHOVEL_TITANIUM = "shovel_steel.png^[colorize:#cfd6dd:90"
local TEX_STOVE_TOP = "Stove_top.png"
local TEX_STOVE_SIDE = "Stove_side.png"
local TEX_STOVE_FRONT = "stove.png"
local PLAYER_MODEL = "character.b3d"
local PLAYER_SKIN = "Pilot.png"
local PLAYER_HAND = "hand.png"

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

local function round_node(v)
	if v >= 0 then
		return math.floor(v + 0.5)
	end
	return math.ceil(v - 0.5)
end

local function hash_noise(ix, iz, seed)
	local n = math.sin(ix * 127.1 + iz * 311.7 + seed * 19.19) * 43758.5453
	return (n - math.floor(n)) * 2 - 1
end

local function value_noise(x, z, scale, seed)
	local sx = x / scale
	local sz = z / scale
	local ix = math.floor(sx)
	local iz = math.floor(sz)
	local fx = smoothstep(sx - ix)
	local fz = smoothstep(sz - iz)

	local a = hash_noise(ix, iz, seed)
	local b = hash_noise(ix + 1, iz, seed)
	local c = hash_noise(ix, iz + 1, seed)
	local d = hash_noise(ix + 1, iz + 1, seed)
	return lerp(lerp(a, b, fx), lerp(c, d, fx), fz)
end

local function fractal_noise(x, z, scale, seed, octaves)
	local total = 0
	local amp = 1
	local amp_total = 0

	for octave = 1, octaves do
		total = total + value_noise(x, z, scale, seed + octave * 47) * amp
		amp_total = amp_total + amp
		scale = scale * 0.52
		amp = amp * 0.5
	end

	return total / amp_total
end

local function simple_node(name, description, tiles, groups, extra)
	local def = {
		description = description,
		tiles = tiles,
		groups = groups or { oddly_breakable_by_hand = 1 },
	}
	if extra then
		for key, value in pairs(extra) do
			def[key] = value
		end
	end
	minetest.register_node(name, def)
end

local SOFT_SHADOW_NODE = {
	paramtype = "light",
	sunlight_propagates = true,
}

local GROUP_GRASS = { crumbly = 3, soil = 1, oddly_breakable_by_hand = 1 }
local GROUP_DIRT = { crumbly = 3, soil = 1, oddly_breakable_by_hand = 1 }
local GROUP_SAND = { crumbly = 3, falling_node = 1, oddly_breakable_by_hand = 1 }
local GROUP_STONE = { cracky = 3, stone = 1, oddly_breakable_by_hand = 1 }
local GROUP_RUNWAY = { cracky = 2, oddly_breakable_by_hand = 1 }
local GROUP_WOOD = { choppy = 2, tree = 1, oddly_breakable_by_hand = 1 }
local GROUP_PLANKS = { choppy = 3, wood = 1, oddly_breakable_by_hand = 1 }
local GROUP_LEAVES = { snappy = 2, leafdecay = 3, oddly_breakable_by_hand = 1 }
local GROUP_PLANT = { snappy = 3, flora = 1, attached_node = 1, oddly_breakable_by_hand = 1 }

simple_node("flight_world:ground", "Short Field Grass", { TEX_GRASS_TOP, TEX_DIRT, TEX_GRASS_SIDE }, GROUP_GRASS, SOFT_SHADOW_NODE)
simple_node("flight_world:dry_ground", "Dry Prairie Grass", { TEX_PATH_TOP, TEX_DIRT, TEX_PATH_SIDE }, GROUP_GRASS, SOFT_SHADOW_NODE)
simple_node("flight_world:snow_ground", "Cold Ridge Grass", { TEX_COLD_GRASS_TOP, TEX_DIRT, TEX_COLD_GRASS_SIDE }, GROUP_GRASS, SOFT_SHADOW_NODE)
simple_node("flight_world:sand", "Pale Sand", { TEX_SAND }, GROUP_SAND, SOFT_SHADOW_NODE)
simple_node("flight_world:dirt", "Packed Dirt", { TEX_DIRT }, GROUP_DIRT, SOFT_SHADOW_NODE)
simple_node("flight_world:stone", "Hill Stone", { TEX_STONE }, GROUP_STONE, SOFT_SHADOW_NODE)
simple_node("flight_world:cobble", "Ridge Cobble", { TEX_COBBLE }, GROUP_STONE, SOFT_SHADOW_NODE)
simple_node("flight_world:runway", "Simple Asphalt Runway", { TEX_RUNWAY }, GROUP_RUNWAY)
simple_node("flight_world:stripe", "Runway Stripe", { TEX_STRIPE }, GROUP_RUNWAY)
simple_node("flight_world:spawn_marker", "Flight Spawn Marker", { TEX_MARKER }, GROUP_RUNWAY)
simple_node("flight_world:tree", "Small Tree Trunk", { TEX_TRUNK_TOP, TEX_TRUNK_TOP, TEX_TRUNK }, GROUP_WOOD)
simple_node("flight_world:wood_planks", "Wood Planks", { TEX_PLANKS }, GROUP_PLANKS)
simple_node("flight_world:leaves", "Small Tree Leaves", { TEX_LEAVES }, GROUP_LEAVES, {
	paramtype = "light",
	sunlight_propagates = true,
})
simple_node("flight_world:autumn_leaves", "Thin Autumn Leaves", { TEX_LEAVES_AUTUMN }, GROUP_LEAVES, {
	paramtype = "light",
	sunlight_propagates = true,
})
simple_node("flight_world:serviceberry_leaves", "Thin Serviceberry Leaves", { TEX_LEAVES_SERVICEBERRY }, GROUP_LEAVES, {
	paramtype = "light",
	sunlight_propagates = true,
})

local function plant_node(name, description, texture, scale)
	minetest.register_node(name, {
		description = description,
		drawtype = "plantlike",
		visual_scale = scale or 1.0,
		tiles = { texture },
		inventory_image = texture,
		wield_image = texture,
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		groups = GROUP_PLANT,
		selection_box = {
			type = "fixed",
			fixed = { -0.25, -0.5, -0.25, 0.25, 0.25, 0.25 },
		},
	})
end

plant_node("flight_world:tallgrass", "Tall Grass", TEX_FLOWER_TALLGRASS, 1.05)
plant_node("flight_world:fern", "Small Fern", TEX_FLOWER_FERN, 1.05)
plant_node("flight_world:clover", "Fourleaf Clover", TEX_FLOWER_CLOVER, 0.9)
plant_node("flight_world:poppy", "Poppy", TEX_FLOWER_POPPY, 0.95)
plant_node("flight_world:red_tulip", "Red Tulip", TEX_FLOWER_TULIP_RED, 0.95)
plant_node("flight_world:pink_tulip", "Pink Tulip", TEX_FLOWER_TULIP_PINK, 0.95)
plant_node("flight_world:oxeye_daisy", "Oxeye Daisy", TEX_FLOWER_OXEYE, 0.95)
plant_node("flight_world:lily_of_the_valley", "Lily of the Valley", TEX_FLOWER_LILY, 0.95)

minetest.register_craftitem("flight_world:stick", {
	description = "Stick",
	inventory_image = TEX_STICK,
})

minetest.register_craftitem("flight_world:iron_ingot", {
	description = "Iron Ingot",
	inventory_image = TEX_IRON_INGOT,
})

minetest.register_craftitem("flight_world:steel_ingot", {
	description = "Steel Ingot",
	inventory_image = TEX_STEEL_INGOT,
})

minetest.register_craftitem("flight_world:titanium_lump", {
	description = "Titanium Lump",
	inventory_image = TEX_TITANIUM_LUMP,
})

minetest.register_craftitem("flight_world:titanium_ingot", {
	description = "Titanium Ingot",
	inventory_image = TEX_TITANIUM_INGOT,
})

minetest.register_craftitem("flight_world:coal_lump", {
	description = "Coal Lump",
	inventory_image = TEX_COAL_LUMP,
})

minetest.register_node("flight_world:titanium_ore", {
	description = "Titanium Ore",
	tiles = { TEX_TITANIUM_ORE },
	groups = { skywright_ore = 1 },
	drop = "flight_world:titanium_lump",
})

minetest.register_node("flight_world:coal_ore", {
	description = "Coal Ore",
	tiles = { TEX_STONE .. "^" .. TEX_COAL_ORE },
	groups = { skywright_ore = 1 },
	drop = "flight_world:coal_lump",
})

minetest.register_node("flight_world:titanium_block", {
	description = "Titanium Block",
	tiles = { TEX_TITANIUM_BLOCK },
	groups = { titanium_block = 1, skywright_blast_resistant = 5 },
	drop = "flight_world:titanium_block",
})

minetest.register_node("flight_world:titanium_sheet", {
	description = "Titanium Sheet",
	drawtype = "nodebox",
	tiles = { TEX_TITANIUM_SHEET },
	inventory_image = TEX_TITANIUM_SHEET,
	wield_image = TEX_TITANIUM_SHEET,
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	groups = { titanium_sheet = 1, skywright_blast_resistant = 3 },
	drop = "flight_world:titanium_sheet",
	node_box = {
		type = "wallmounted",
		wall_bottom = { -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 },
		wall_top = { -0.5, 0.25, -0.5, 0.5, 0.5, 0.5 },
		wall_side = { -0.5, -0.5, -0.5, -0.25, 0.5, 0.5 },
	},
	selection_box = {
		type = "wallmounted",
		wall_bottom = { -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 },
		wall_top = { -0.5, 0.25, -0.5, 0.5, 0.5, 0.5 },
		wall_side = { -0.5, -0.5, -0.5, -0.25, 0.5, 0.5 },
	},
	collision_box = {
		type = "wallmounted",
		wall_bottom = { -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 },
		wall_top = { -0.5, 0.25, -0.5, 0.5, 0.5, 0.5 },
		wall_side = { -0.5, -0.5, -0.5, -0.25, 0.5, 0.5 },
	},
})

minetest.register_node("flight_world:glass", {
	description = "Glass",
	tiles = { TEX_GLASS },
	drawtype = "glasslike",
	paramtype = "light",
	sunlight_propagates = true,
	use_texture_alpha = "blend",
	groups = { cracky = 3, oddly_breakable_by_hand = 1 },
})

local function add_groupcap(groupcaps, group, times, uses, maxlevel)
	groupcaps[group] = {
		times = times,
		uses = uses or 20,
		maxlevel = maxlevel or 1,
	}
end

local function register_pickaxe(name, description, image, cracky_times, damage, extra_groupcaps)
	local groupcaps = {
		cracky = {
			times = cracky_times,
			uses = 20,
			maxlevel = 2,
		},
		crumbly = {
			times = { [1] = 2.2, [2] = 1.1, [3] = 0.55 },
			uses = 20,
			maxlevel = 1,
		},
	}
	add_groupcap(groupcaps, "skywright_ore", { [1] = cracky_times[3] or cracky_times[2] or cracky_times[1] or 1.0 }, 20, 1)
	if extra_groupcaps then
		for group, cap in pairs(extra_groupcaps) do
			groupcaps[group] = cap
		end
	end

	minetest.register_tool(name, {
		description = description,
		inventory_image = image,
		tool_capabilities = {
			full_punch_interval = 1.0,
			max_drop_level = 1,
			groupcaps = groupcaps,
			damage_groups = { fleshy = damage or 2 },
		},
	})
end

local function register_axe(name, description, image, choppy_times, damage)
	minetest.register_tool(name, {
		description = description,
		inventory_image = image,
		tool_capabilities = {
			full_punch_interval = 1.0,
			max_drop_level = 1,
			groupcaps = {
				choppy = {
					times = choppy_times,
					uses = 20,
					maxlevel = 2,
				},
				snappy = {
					times = { [1] = 1.4, [2] = 0.7, [3] = 0.35 },
					uses = 20,
					maxlevel = 1,
				},
			},
			damage_groups = { fleshy = damage or 3 },
		},
	})
end

local function register_shovel(name, description, image, crumbly_times, damage, can_dig_ore)
	local groupcaps = {
		crumbly = {
			times = crumbly_times,
			uses = 20,
			maxlevel = 2,
		},
	}
	if can_dig_ore then
		add_groupcap(groupcaps, "skywright_ore", { [1] = crumbly_times[1] or 1.0 }, 20, 1)
	end

	minetest.register_tool(name, {
		description = description,
		inventory_image = image,
		tool_capabilities = {
			full_punch_interval = 1.1,
			max_drop_level = 1,
			groupcaps = groupcaps,
			damage_groups = { fleshy = damage or 2 },
		},
	})
end

register_pickaxe("flight_world:pick_wood", "Wooden Pickaxe", TEX_PICK_WOOD, { [1] = 4.8, [2] = 2.6, [3] = 1.3 }, 2)
register_pickaxe("flight_world:pick_stone", "Stone Pickaxe", TEX_PICK_STONE, { [1] = 3.4, [2] = 1.7, [3] = 0.8 }, 3)
register_pickaxe("flight_world:pick_iron", "Iron Pickaxe", TEX_PICK_IRON, { [1] = 2.0, [2] = 1.0, [3] = 0.45 }, 4)
register_pickaxe("flight_world:pick_steel", "Steel Pickaxe", TEX_PICK_STEEL, { [1] = 1.7, [2] = 0.85, [3] = 0.38 }, 4)
register_pickaxe("flight_world:pick_titanium", "Titanium Pickaxe", TEX_PICK_TITANIUM, { [1] = 1.05, [2] = 0.48, [3] = 0.2 }, 6, {
	titanium_block = { times = { [1] = 75.0 }, uses = 120, maxlevel = 1 },
	titanium_sheet = { times = { [1] = 7.5 }, uses = 120, maxlevel = 1 },
})
register_axe("flight_world:axe_wood", "Wooden Axe", TEX_AXE_WOOD, { [1] = 3.8, [2] = 2.0, [3] = 1.0 }, 3)
register_axe("flight_world:axe_stone", "Stone Axe", TEX_AXE_STONE, { [1] = 2.8, [2] = 1.4, [3] = 0.65 }, 4)
register_axe("flight_world:axe_iron", "Iron Axe", TEX_AXE_IRON, { [1] = 1.8, [2] = 0.9, [3] = 0.4 }, 5)
register_axe("flight_world:axe_steel", "Steel Axe", TEX_AXE_STEEL, { [1] = 1.55, [2] = 0.76, [3] = 0.34 }, 5)
register_axe("flight_world:axe_titanium", "Titanium Axe", TEX_AXE_TITANIUM, { [1] = 1.15, [2] = 0.55, [3] = 0.24 }, 7)
register_shovel("flight_world:shovel_wood", "Wooden Shovel", TEX_SHOVEL_WOOD, { [1] = 1.5, [2] = 0.8, [3] = 0.35 }, 2)
register_shovel("flight_world:shovel_stone", "Stone Shovel", TEX_SHOVEL_STONE, { [1] = 1.05, [2] = 0.52, [3] = 0.25 }, 3)
register_shovel("flight_world:shovel_iron", "Iron Shovel", TEX_SHOVEL_IRON, { [1] = 0.72, [2] = 0.36, [3] = 0.16 }, 4, true)
register_shovel("flight_world:shovel_steel", "Steel Shovel", TEX_SHOVEL_STEEL, { [1] = 0.62, [2] = 0.31, [3] = 0.14 }, 4, true)
register_shovel("flight_world:shovel_titanium", "Titanium Shovel", TEX_SHOVEL_TITANIUM, { [1] = 0.45, [2] = 0.2, [3] = 0.09 }, 5, true)

local function stove_formspec()
	return table.concat({
		"formspec_version[4]",
		"size[8.4,8.6]",
		"label[0.45,0.35;Stove]",
		"label[1.05,1.0;Cook]",
		"list[context;src;1.1,1.35;1,1;]",
		"label[1.05,2.55;Fuel]",
		"list[context;fuel;1.1,2.9;1,1;]",
		"label[4.6,1.0;Output]",
		"list[context;dst;4.6,1.35;2,2;]",
		"list[current_player;main;0.35,4.4;8,4;]",
		"listring[context;dst]",
		"listring[current_player;main]",
		"listring[context;src]",
		"listring[current_player;main]",
		"listring[context;fuel]",
		"listring[current_player;main]",
	})
end

local function stove_cookable(inv)
	local src_stack = inv:get_stack("src", 1)
	local cooked = minetest.get_craft_result({ method = "cooking", width = 1, items = { src_stack } })
	return cooked and cooked.time > 0 and not cooked.item:is_empty(), cooked
end

local function stove_has_fuel(inv)
	local fuel_stack = inv:get_stack("fuel", 1)
	local fuel, after_fuel = minetest.get_craft_result({ method = "fuel", width = 1, items = { fuel_stack } })
	return fuel and fuel.time > 0, fuel, after_fuel
end

local function stove_tick(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local can_cook, cooked = stove_cookable(inv)
	local has_fuel, fuel, after_fuel = stove_has_fuel(inv)
	if not can_cook or not has_fuel or not inv:room_for_item("dst", cooked.item) then
		meta:set_float("cook_remaining", 0)
		meta:set_string("infotext", "Stove")
		return false
	end

	local remaining = meta:get_float("cook_remaining")
	if remaining <= 0 then
		remaining = math.max(1, cooked.time or 3)
	end
	remaining = remaining - 1
	meta:set_float("cook_remaining", remaining)
	meta:set_string("infotext", string.format("Stove cooking: %ds", math.max(1, math.ceil(remaining))))

	if remaining > 0 then
		return true
	end

	local src_stack = inv:get_stack("src", 1)
	src_stack:take_item(1)
	inv:set_stack("src", 1, src_stack)
	inv:set_stack("fuel", 1, after_fuel.items[1])
	inv:add_item("dst", cooked.item)
	meta:set_string("infotext", "Stove")
	return true
end

local function start_stove(pos)
	minetest.get_node_timer(pos):start(1.0)
end

minetest.register_node("flight_world:stove", {
	description = "Stone Stove",
	tiles = { TEX_STOVE_TOP, TEX_STOVE_TOP, TEX_STOVE_SIDE, TEX_STOVE_SIDE, TEX_STOVE_SIDE, TEX_STOVE_FRONT },
	groups = { cracky = 2, stone = 1, oddly_breakable_by_hand = 1 },
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("src", 1)
		inv:set_size("fuel", 1)
		inv:set_size("dst", 4)
		meta:set_string("formspec", stove_formspec())
		meta:set_string("infotext", "Stove")
	end,
	can_dig = function(pos, player)
		local inv = minetest.get_meta(pos):get_inventory()
		return inv:is_empty("src") and inv:is_empty("fuel") and inv:is_empty("dst")
	end,
	on_timer = stove_tick,
	on_metadata_inventory_put = start_stove,
	on_metadata_inventory_move = start_stove,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "dst" then
			return 0
		end
		if listname == "fuel" then
			local fuel = minetest.get_craft_result({ method = "fuel", width = 1, items = { stack } })
			return fuel and fuel.time > 0 and stack:get_count() or 0
		end
		if listname == "src" then
			local cooked = minetest.get_craft_result({ method = "cooking", width = 1, items = { stack } })
			return cooked and cooked.time > 0 and stack:get_count() or 0
		end
		return stack:get_count()
	end,
})

minetest.register_craft({
	output = "flight_world:wood_planks 4",
	recipe = {
		{ "flight_world:tree" },
	},
})

minetest.register_craft({
	output = "flight_world:stick 4",
	recipe = {
		{ "flight_world:wood_planks" },
		{ "flight_world:wood_planks" },
	},
})

minetest.register_craft({
	output = "flight_world:pick_wood",
	recipe = {
		{ "flight_world:wood_planks", "flight_world:wood_planks", "flight_world:wood_planks" },
		{ "", "flight_world:stick", "" },
		{ "", "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:pick_stone",
	recipe = {
		{ "group:stone", "group:stone", "group:stone" },
		{ "", "flight_world:stick", "" },
		{ "", "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:pick_iron",
	recipe = {
		{ "flight_world:iron_ingot", "flight_world:iron_ingot", "flight_world:iron_ingot" },
		{ "", "flight_world:stick", "" },
		{ "", "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:pick_steel",
	recipe = {
		{ "flight_world:steel_ingot", "flight_world:steel_ingot", "flight_world:steel_ingot" },
		{ "", "flight_world:stick", "" },
		{ "", "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:pick_titanium",
	recipe = {
		{ "flight_world:titanium_ingot", "flight_world:titanium_ingot", "flight_world:titanium_ingot" },
		{ "", "flight_world:stick", "" },
		{ "", "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:axe_wood",
	recipe = {
		{ "flight_world:wood_planks", "flight_world:wood_planks" },
		{ "flight_world:wood_planks", "flight_world:stick" },
		{ "", "flight_world:stick" },
	},
})
minetest.register_craft({
	output = "flight_world:axe_wood",
	recipe = {
		{ "flight_world:wood_planks", "flight_world:wood_planks" },
		{ "flight_world:stick", "flight_world:wood_planks" },
		{ "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:axe_stone",
	recipe = {
		{ "group:stone", "group:stone" },
		{ "group:stone", "flight_world:stick" },
		{ "", "flight_world:stick" },
	},
})
minetest.register_craft({
	output = "flight_world:axe_stone",
	recipe = {
		{ "group:stone", "group:stone" },
		{ "flight_world:stick", "group:stone" },
		{ "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:axe_iron",
	recipe = {
		{ "flight_world:iron_ingot", "flight_world:iron_ingot" },
		{ "flight_world:iron_ingot", "flight_world:stick" },
		{ "", "flight_world:stick" },
	},
})
minetest.register_craft({
	output = "flight_world:axe_iron",
	recipe = {
		{ "flight_world:iron_ingot", "flight_world:iron_ingot" },
		{ "flight_world:stick", "flight_world:iron_ingot" },
		{ "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:axe_steel",
	recipe = {
		{ "flight_world:steel_ingot", "flight_world:steel_ingot" },
		{ "flight_world:steel_ingot", "flight_world:stick" },
		{ "", "flight_world:stick" },
	},
})
minetest.register_craft({
	output = "flight_world:axe_steel",
	recipe = {
		{ "flight_world:steel_ingot", "flight_world:steel_ingot" },
		{ "flight_world:stick", "flight_world:steel_ingot" },
		{ "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:axe_titanium",
	recipe = {
		{ "flight_world:titanium_ingot", "flight_world:titanium_ingot" },
		{ "flight_world:titanium_ingot", "flight_world:stick" },
		{ "", "flight_world:stick" },
	},
})
minetest.register_craft({
	output = "flight_world:axe_titanium",
	recipe = {
		{ "flight_world:titanium_ingot", "flight_world:titanium_ingot" },
		{ "flight_world:stick", "flight_world:titanium_ingot" },
		{ "flight_world:stick", "" },
	},
})

minetest.register_craft({
	output = "flight_world:shovel_wood",
	recipe = {
		{ "flight_world:wood_planks" },
		{ "flight_world:stick" },
		{ "flight_world:stick" },
	},
})

minetest.register_craft({
	output = "flight_world:shovel_stone",
	recipe = {
		{ "group:stone" },
		{ "flight_world:stick" },
		{ "flight_world:stick" },
	},
})

minetest.register_craft({
	output = "flight_world:shovel_iron",
	recipe = {
		{ "flight_world:iron_ingot" },
		{ "flight_world:stick" },
		{ "flight_world:stick" },
	},
})

minetest.register_craft({
	output = "flight_world:shovel_steel",
	recipe = {
		{ "flight_world:steel_ingot" },
		{ "flight_world:stick" },
		{ "flight_world:stick" },
	},
})

minetest.register_craft({
	output = "flight_world:shovel_titanium",
	recipe = {
		{ "flight_world:titanium_ingot" },
		{ "flight_world:stick" },
		{ "flight_world:stick" },
	},
})

minetest.register_craft({
	output = "flight_world:stove",
	recipe = {
		{ "group:stone", "group:stone", "group:stone" },
		{ "group:stone", "", "group:stone" },
		{ "group:stone", "group:stone", "group:stone" },
	},
})

minetest.register_craft({
	output = "flight_world:titanium_sheet 30",
	recipe = {
		{ "flight_world:titanium_block" },
	},
})

minetest.register_craft({
	output = "flight_world:titanium_ingot",
	recipe = {
		{ "flight_world:titanium_sheet", "flight_world:titanium_sheet" },
		{ "flight_world:titanium_sheet", "flight_world:titanium_sheet" },
	},
})

minetest.register_craft({
	output = "flight_world:titanium_block",
	recipe = {
		{ "flight_world:titanium_ingot", "flight_world:titanium_ingot", "flight_world:titanium_ingot" },
		{ "flight_world:titanium_ingot", "flight_world:titanium_ingot", "flight_world:titanium_ingot" },
		{ "flight_world:titanium_ingot", "flight_world:titanium_ingot", "flight_world:titanium_ingot" },
	},
})

minetest.register_craft({
	output = "flight_world:runway_torch 4",
	recipe = {
		{ "flight_world:coal_lump" },
		{ "flight_world:stick" },
	},
})

minetest.register_craft({
	type = "cooking",
	output = "flight_world:glass",
	recipe = "flight_world:sand",
	cooktime = 4,
})

minetest.register_craft({
	type = "cooking",
	output = "flight_world:stone",
	recipe = "flight_world:cobble",
	cooktime = 4,
})

minetest.register_craft({
	type = "cooking",
	output = "flight_world:steel_ingot",
	recipe = "flight_world:iron_ingot",
	cooktime = 7,
})

minetest.register_craft({
	type = "cooking",
	output = "flight_world:titanium_ingot",
	recipe = "flight_world:titanium_lump",
	cooktime = 10,
})

minetest.register_craft({ type = "fuel", recipe = "flight_world:tree", burntime = 30 })
minetest.register_craft({ type = "fuel", recipe = "flight_world:wood_planks", burntime = 7 })
minetest.register_craft({ type = "fuel", recipe = "flight_world:stick", burntime = 3 })
minetest.register_craft({ type = "fuel", recipe = "flight_world:leaves", burntime = 2 })
minetest.register_craft({ type = "fuel", recipe = "flight_world:autumn_leaves", burntime = 2 })
minetest.register_craft({ type = "fuel", recipe = "flight_world:serviceberry_leaves", burntime = 2 })
minetest.register_craft({ type = "fuel", recipe = "flight_world:coal_lump", burntime = 40 })

minetest.register_node("flight_world:runway_torch", {
	description = "Runway Edge Torch",
	drawtype = "plantlike",
	visual_scale = 1.15,
	tiles = {
		{
			name = TEX_TORCH_ANIM,
			animation = {
				type = "vertical_frames",
				aspect_w = 10,
				aspect_h = 23,
				length = 0.9,
			},
		},
	},
	inventory_image = TEX_TORCH,
	wield_image = TEX_TORCH,
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 12,
	walkable = false,
	buildable_to = true,
	groups = { oddly_breakable_by_hand = 1 },
	selection_box = {
		type = "fixed",
		fixed = { -0.15, -0.5, -0.15, 0.15, 0.35, 0.15 },
	},
})

minetest.register_alias("mapgen_stone", "flight_world:stone")
minetest.register_alias("mapgen_dirt", "flight_world:dirt")
minetest.register_alias("mapgen_dirt_with_grass", "flight_world:ground")
minetest.register_alias("mapgen_sand", "flight_world:sand")
minetest.register_alias("mapgen_water_source", "air")
minetest.register_alias("mapgen_river_water_source", "air")
minetest.register_alias("mapgen_lava_source", "air")

minetest.override_item("", {
	wield_image = PLAYER_HAND,
	inventory_image = PLAYER_HAND,
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {
			crumbly = {
				times = { [1] = 1.4, [2] = 0.8, [3] = 0.35 },
				uses = 0,
				maxlevel = 1,
			},
			snappy = {
				times = { [1] = 1.1, [2] = 0.55, [3] = 0.18 },
				uses = 0,
				maxlevel = 1,
			},
			choppy = {
				times = { [1] = 5.5, [2] = 3.2, [3] = 1.8 },
				uses = 0,
				maxlevel = 1,
			},
			cracky = {
				times = { [1] = 8.0, [2] = 5.0, [3] = 3.5 },
				uses = 0,
				maxlevel = 1,
			},
		},
		damage_groups = { fleshy = 1 },
	},
})

local function runway_for_slot(slot)
	local angle = (slot - 1) * math.pi * 2 / RUNWAY_COUNT
	local outward = { x = math.cos(angle), z = math.sin(angle) }
	local forward = { x = -outward.x, z = -outward.z }
	local right = { x = -forward.z, z = forward.x }

	return {
		slot = slot,
		center = {
			x = outward.x * RUNWAY_CENTER_RADIUS,
			z = outward.z * RUNWAY_CENTER_RADIUS,
		},
		forward = forward,
		right = right,
	}
end

local function runway_local_coords(runway, x, z)
	local dx = x - runway.center.x
	local dz = z - runway.center.z
	return {
		lateral = dx * runway.right.x + dz * runway.right.z,
		forward = dx * runway.forward.x + dz * runway.forward.z,
	}
end

local function runway_world_pos(runway, lateral, forward)
	return {
		x = round_node(runway.center.x + runway.right.x * lateral + runway.forward.x * forward),
		z = round_node(runway.center.z + runway.right.z * lateral + runway.forward.z * forward),
	}
end

local function near_airfield_ring(x, z)
	return x * x + z * z <= AIRFIELD_RING_OUTER_RADIUS * AIRFIELD_RING_OUTER_RADIUS
end

local function airfield_at(x, z)
	if not near_airfield_ring(x, z) then
		return nil
	end

	local best
	for slot = 1, RUNWAY_COUNT do
		local runway = runway_for_slot(slot)
		local local_pos = runway_local_coords(runway, x, z)
		local inside = math.abs(local_pos.lateral) <= AIRFIELD_HALF_WIDTH
			and local_pos.forward >= AIRFIELD_BACK
			and local_pos.forward <= AIRFIELD_FRONT
		if inside and (not best or math.abs(local_pos.lateral) < math.abs(best.local_pos.lateral)) then
			best = { runway = runway, local_pos = local_pos }
		end
	end
	return best
end

local function in_airfield_clearance(x, z)
	return airfield_at(x, z) ~= nil
end

local function airfield_edge_distance(x, z)
	if not near_airfield_ring(x, z) then
		return AIRFIELD_RING_OUTER_RADIUS
	end

	local best = math.huge
	for slot = 1, RUNWAY_COUNT do
		local runway = runway_for_slot(slot)
		local local_pos = runway_local_coords(runway, x, z)
		local dx = math.max(math.abs(local_pos.lateral) - AIRFIELD_HALF_WIDTH, 0)
		local dz = 0
		if local_pos.forward < AIRFIELD_BACK then
			dz = AIRFIELD_BACK - local_pos.forward
		elseif local_pos.forward > AIRFIELD_FRONT then
			dz = local_pos.forward - AIRFIELD_FRONT
		end
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end

	return best
end

local function airfield_node_name(x, z)
	local airfield = airfield_at(x, z)
	if not airfield then
		return "flight_world:ground"
	end

	local local_pos = airfield.local_pos
	local lateral = local_pos.lateral
	local forward = local_pos.forward
	local on_runway = math.abs(lateral) <= RUNWAY_HALF_WIDTH and forward >= RUNWAY_BACK and forward <= RUNWAY_FRONT
	local on_marker = math.abs(lateral) <= 2 and forward >= RUNWAY_SPAWN_FORWARD - 2 and forward <= RUNWAY_SPAWN_FORWARD + 2

	if on_marker then
		return "flight_world:spawn_marker"
	end

	if not on_runway then
		return "flight_world:ground"
	end

	local stripe_segment = ((math.floor(forward - RUNWAY_BACK)) % 24) < 8
	if math.abs(lateral) <= 1 and stripe_segment and forward > RUNWAY_BACK + 15 and forward < RUNWAY_FRONT - 15 then
		return "flight_world:stripe"
	end

	if math.abs(math.abs(lateral) - RUNWAY_HALF_WIDTH) <= 0.8 and (math.floor(forward) % 12) == 0 then
		return "flight_world:stripe"
	end

	return "flight_world:runway"
end

local function biome_at(x, z, height)
	local b = fractal_noise(x, z, 260, 12293, 3)
	if height > 24 then
		return "ridge"
	end
	if b < -0.42 then
		return "dry"
	end
	if b > 0.45 then
		return "forest"
	end
	return "field"
end

local function terrain_height(x, z)
	if in_airfield_clearance(x, z) then
		return 0
	end

	local broad = fractal_noise(x, z, 180, 73157, 4)
	local ridge = math.abs(fractal_noise(x, z, 72, 91822, 3))
	local raw = math.floor(4 + broad * 17 + ridge * ridge * 26)
	local height = clamp(raw, 0, 42)

	-- Blend hills up gradually outside the runway box so takeoff is readable.
	local blend = math.min(1, airfield_edge_distance(x, z) / 48)
	return math.floor(height * blend)
end

local function top_node_for_biome(biome)
	if biome == "dry" then
		return "dry_ground"
	end
	if biome == "ridge" then
		return "snow_ground"
	end
	return "ground"
end

local function ore_noise(x, y, z, scale, seed, octaves)
	return fractal_noise(x + y * 4.37, z - y * 3.91, scale, seed, octaves or 3)
end

local function near_sea_level_sand_titanium(x, y, z, height, biome)
	if biome ~= "dry" or height > 2 or y >= height or y < height - 10 then
		return false
	end

	local broad = fractal_noise(x, z, 32, 77113, 3)
	local pocket = ore_noise(x, y, z, 11, 77129, 2)
	return broad + pocket * 0.45 > 0.18
end

local function has_titanium_ore(x, y, z, height, biome)
	if near_sea_level_sand_titanium(x, y, z, height, biome) then
		return true
	end

	if y <= math.min(height - 3, 0) then
		local patch = ore_noise(x, y, z, 18, 88117, 3)
		local gate = hash_noise(math.floor(x / 5), math.floor(z / 5) + math.floor(y / 5), 88151)
		if patch > 0.57 and gate > 0.25 then
			return true
		end
	end

	if y <= -100 then
		local deep = ore_noise(x, y, z, 42, 99173, 4)
		local seam = ore_noise(x, y, z, 16, 99191, 2)
		return deep + seam * 0.35 > 0.12
	end

	return false
end

local function has_coal_ore(x, y, z, height)
	if y > height - 5 or y > 24 then
		return false
	end

	local coal = ore_noise(x, y, z, 24, 33791, 3)
	local gate = hash_noise(math.floor(x / 4), math.floor(z / 4) + math.floor(y / 6), 33811)
	return coal > 0.52 and gate > -0.1
end

local function content_for_terrain(x, y, z, height, biome, c)
	if y < height - 5 then
		if has_titanium_ore(x, y, z, height, biome) then
			return c.titanium_ore
		end
		if has_coal_ore(x, y, z, height) then
			return c.coal_ore
		end
		return c.stone
	end
	if y < height then
		if has_titanium_ore(x, y, z, height, biome) then
			return c.titanium_ore
		end
		return c.dirt
	end
	if biome == "dry" and height <= 2 then
		return c.sand
	end
	if biome == "ridge" and height > 30 then
		return c.cobble
	end
	return c[top_node_for_biome(biome)]
end

local function maybe_place_tree(data, area, minp, maxp, x, z, height, biome, c)
	if height < 1 or height > 28 or in_airfield_clearance(x, z) then
		return
	end

	local full_tree = biome == "forest" and fractal_noise(x, z, 34, 66071, 4) >= 0.52
	local thin_tree = biome ~= "ridge" and fractal_noise(x + 113, z - 71, 54, 44771, 3) >= 0.72
	if not full_tree and not thin_tree then
		return
	end

	local trunk_height = thin_tree and 5 or (4 + math.floor(math.abs(fractal_noise(x + 19, z - 11, 34, 66071, 4)) * 3))
	local base_y = height + 1
	local leaf_id = c.leaves
	if thin_tree then
		leaf_id = fractal_noise(x + 9, z + 31, 80, 5503, 2) > 0 and c.serviceberry_leaves or c.autumn_leaves
	end

	for y = base_y, base_y + trunk_height - 1 do
		if y >= minp.y and y <= maxp.y then
			data[area:index(x, y, z)] = c.tree
		end
	end

	local crown_y = base_y + trunk_height
	local crown_radius = thin_tree and 1 or 2
	for dz = -crown_radius, crown_radius do
		for dx = -crown_radius, crown_radius do
			for dy = -1, 2 do
				local lx = x + dx
				local ly = crown_y + dy
				local lz = z + dz
				local roundish = math.abs(dx) + math.abs(dz) + math.max(math.abs(dy) - 1, 0) <= (thin_tree and 2 or 4)
				if roundish
					and lx >= minp.x and lx <= maxp.x
					and ly >= minp.y and ly <= maxp.y
					and lz >= minp.z and lz <= maxp.z then
					data[area:index(lx, ly, lz)] = leaf_id
				end
			end
		end
	end
end

local function maybe_place_plant(data, area, minp, maxp, x, z, height, biome, c)
	if height < 1 or height > 30 or biome == "ridge" or in_airfield_clearance(x, z) then
		return
	end

	local y = height + 1
	if y < minp.y or y > maxp.y then
		return
	end

	local vi = area:index(x, y, z)
	if data[vi] ~= c.air then
		return
	end

	local density_noise = fractal_noise(x, z, 18, 99281, 3)
	local threshold = biome == "forest" and 0.50 or 0.62
	if biome == "dry" then
		threshold = 0.76
	end
	if density_noise < threshold then
		return
	end

	local picker = hash_noise(x, z, 5021)
	if biome == "dry" then
		data[vi] = picker > 0.25 and c.tallgrass or c.fern
	elseif picker < -0.55 then
		data[vi] = c.clover
	elseif picker < -0.25 then
		data[vi] = c.poppy
	elseif picker < 0.0 then
		data[vi] = c.red_tulip
	elseif picker < 0.25 then
		data[vi] = c.pink_tulip
	elseif picker < 0.5 then
		data[vi] = c.oxeye_daisy
	elseif picker < 0.72 then
		data[vi] = c.lily_of_the_valley
	else
		data[vi] = c.tallgrass
	end
end

local function plant_name_for(x, z, biome)
	local picker = hash_noise(x, z, 5021)
	if biome == "dry" then
		return picker > 0.25 and "flight_world:tallgrass" or "flight_world:fern"
	end
	if picker < -0.55 then
		return "flight_world:clover"
	elseif picker < -0.25 then
		return "flight_world:poppy"
	elseif picker < 0.0 then
		return "flight_world:red_tulip"
	elseif picker < 0.25 then
		return "flight_world:pink_tulip"
	elseif picker < 0.5 then
		return "flight_world:oxeye_daisy"
	elseif picker < 0.72 then
		return "flight_world:lily_of_the_valley"
	end
	return "flight_world:tallgrass"
end

local function can_host_greenery(node_name)
	return node_name == "flight_world:ground"
		or node_name == "flight_world:dry_ground"
		or node_name == "flight_world:snow_ground"
		or node_name == "flight_world:sand"
		or node_name == "flight_world:dirt"
end

local function find_greenery_surface(x, z, center_y)
	for y = center_y + 32, center_y - 80, -1 do
		local node = minetest.get_node_or_nil({ x = x, y = y, z = z })
		local above = minetest.get_node_or_nil({ x = x, y = y + 1, z = z })
		if node and above and can_host_greenery(node.name) and above.name == "air" then
			return y, node.name
		end
	end
	return nil
end

local function place_thin_tree(pos)
	local leaf_name = hash_noise(pos.x, pos.z, 5503) > 0
		and "flight_world:serviceberry_leaves"
		or "flight_world:autumn_leaves"
	local trunk_height = 4 + math.floor(math.abs(hash_noise(pos.x, pos.z, 4411)) * 2)

	for y = pos.y, pos.y + trunk_height - 1 do
		minetest.set_node({ x = pos.x, y = y, z = pos.z }, { name = "flight_world:tree" })
	end

	local crown_y = pos.y + trunk_height
	for dz = -1, 1 do
		for dx = -1, 1 do
			for dy = -1, 1 do
				if math.abs(dx) + math.abs(dz) + math.max(math.abs(dy) - 1, 0) <= 2 then
					local leaf_pos = { x = pos.x + dx, y = crown_y + dy, z = pos.z + dz }
					local node = minetest.get_node_or_nil(leaf_pos)
					if node and node.name == "air" then
						minetest.set_node(leaf_pos, { name = leaf_name })
					end
				end
			end
		end
	end
end

function WORLD.place_airfield(slot_filter)
	local first_slot = slot_filter or 1
	local last_slot = slot_filter or RUNWAY_COUNT

	for slot = first_slot, last_slot do
		local runway = runway_for_slot(slot)

		for lateral = -AIRFIELD_HALF_WIDTH, AIRFIELD_HALF_WIDTH do
			for forward = AIRFIELD_BACK, AIRFIELD_FRONT do
				local world_pos = runway_world_pos(runway, lateral, forward)
				minetest.set_node({ x = world_pos.x, y = 0, z = world_pos.z }, {
					name = airfield_node_name(world_pos.x, world_pos.z),
				})
				for y = 1, 18 do
					minetest.set_node({ x = world_pos.x, y = y, z = world_pos.z }, { name = "air" })
				end
			end
		end

		for forward = RUNWAY_BACK + 4, RUNWAY_FRONT - 4, 12 do
			local left = runway_world_pos(runway, -12, forward)
			local right = runway_world_pos(runway, 12, forward)
			minetest.set_node({ x = left.x, y = 1, z = left.z }, { name = "flight_world:runway_torch" })
			minetest.set_node({ x = right.x, y = 1, z = right.z }, { name = "flight_world:runway_torch" })
		end
	end
end

function WORLD.seed_greenery(center, radius)
	radius = clamp(math.floor(radius or 32), 8, 72)
	center = vector.round(center)
	local plants = 0
	local trees = 0

	for z = center.z - radius, center.z + radius do
		for x = center.x - radius, center.x + radius do
			local dx = x - center.x
			local dz = z - center.z
			if dx * dx + dz * dz <= radius * radius and not in_airfield_clearance(x, z) then
				local surface_y = find_greenery_surface(x, z, center.y)
				if surface_y then
					local biome = biome_at(x, z, surface_y)
					local plant_noise = fractal_noise(x, z, 18, 99281, 3)
					local tree_noise = fractal_noise(x + 113, z - 71, 54, 44771, 3)
					if tree_noise > 0.91 and trees < math.max(2, radius / 5) then
						place_thin_tree({ x = x, y = surface_y + 1, z = z })
						trees = trees + 1
					elseif plant_noise > 0.66 then
						minetest.set_node({ x = x, y = surface_y + 1, z = z }, { name = plant_name_for(x, z, biome) })
						plants = plants + 1
					end
				end
			end
		end
	end

	return plants, trees, radius
end

function WORLD.apply_flight_environment(player)
	if not player or not player:is_player() then
		return
	end

	-- Keep daylight readable from the chase camera. Luanti cloud shadows and
	-- ambient shadows can get heavy over large open terrain, so Skywright uses
	-- lighter ambient shadow intensity plus thinner cloud cover.
	if player.set_lighting then
		player:set_lighting({
			shadows = { intensity = CLOUD_SHADOW_INTENSITY },
			bloom = { intensity = 0.035 },
		})
	end

	if player.set_clouds then
		player:set_clouds({
			density = CLOUD_DENSITY,
			color = "#ffffffd8",
			ambient = "#ffffff",
			height = 140,
			thickness = 12,
			speed = { x = 0, z = -2 },
			shadow = "#f4f4f4",
		})
	end
end

function WORLD.apply_player_skin(player)
	if not player or not player:is_player() then
		return
	end

	-- Skywright ships its own copy of Minetest Game's Sam-compatible
	-- character.b3d so the prototype can use a normal player body without
	-- depending on player_api or another game.
	player:set_properties({
		visual = "mesh",
		mesh = PLAYER_MODEL,
		textures = { PLAYER_SKIN },
		visual_size = { x = 1, y = 1 },
		collisionbox = { -0.3, 0.0, -0.3, 0.3, 1.7, 0.3 },
		stepheight = 0.6,
		eye_height = 1.47,
	})

	if player.set_local_animation then
		player:set_local_animation(
			{ x = 0, y = 79 },
			{ x = 168, y = 187 },
			{ x = 189, y = 198 },
			{ x = 200, y = 219 },
			30
		)
	end
end

function WORLD.player_runway_slot(player_name)
	local key = "runway_slot:" .. player_name
	local stored = tonumber(WORLD_STORAGE:get_string(key))
	if stored and stored >= 1 and stored <= RUNWAY_COUNT then
		return stored
	end

	local next_slot = tonumber(WORLD_STORAGE:get_string("next_runway_slot")) or 1
	next_slot = clamp(math.floor(next_slot), 1, RUNWAY_COUNT)
	WORLD_STORAGE:set_string(key, tostring(next_slot))
	WORLD_STORAGE:set_string("next_runway_slot", tostring((next_slot % RUNWAY_COUNT) + 1))
	return next_slot
end

function WORLD.spawn_pos_for_slot(slot)
	local runway = runway_for_slot(slot)
	local pos = runway_world_pos(runway, 0, RUNWAY_SPAWN_FORWARD)
	return { x = pos.x, y = 3, z = pos.z }
end

function WORLD.spawn_player(player)
	if not player or not player:is_player() then
		return nil
	end

	local name = player:get_player_name()
	local slot = WORLD.player_runway_slot(name)
	local runway = runway_for_slot(slot)
	local pos = WORLD.spawn_pos_for_slot(slot)

	player:set_pos(pos)
	WORLD.apply_player_skin(player)
	if player.set_look_horizontal and minetest.dir_to_yaw then
		player:set_look_horizontal(minetest.dir_to_yaw({ x = runway.forward.x, y = 0, z = runway.forward.z }))
	end
	WORLD.apply_flight_environment(player)
	return slot
end

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y > 80 then
		return
	end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()

	local c = {
		air = minetest.get_content_id("air"),
		ground = minetest.get_content_id("flight_world:ground"),
		dry_ground = minetest.get_content_id("flight_world:dry_ground"),
		snow_ground = minetest.get_content_id("flight_world:snow_ground"),
		sand = minetest.get_content_id("flight_world:sand"),
		dirt = minetest.get_content_id("flight_world:dirt"),
		stone = minetest.get_content_id("flight_world:stone"),
		cobble = minetest.get_content_id("flight_world:cobble"),
		titanium_ore = minetest.get_content_id("flight_world:titanium_ore"),
		coal_ore = minetest.get_content_id("flight_world:coal_ore"),
		runway = minetest.get_content_id("flight_world:runway"),
		stripe = minetest.get_content_id("flight_world:stripe"),
		marker = minetest.get_content_id("flight_world:spawn_marker"),
		tree = minetest.get_content_id("flight_world:tree"),
		leaves = minetest.get_content_id("flight_world:leaves"),
		autumn_leaves = minetest.get_content_id("flight_world:autumn_leaves"),
		serviceberry_leaves = minetest.get_content_id("flight_world:serviceberry_leaves"),
		tallgrass = minetest.get_content_id("flight_world:tallgrass"),
		fern = minetest.get_content_id("flight_world:fern"),
		clover = minetest.get_content_id("flight_world:clover"),
		poppy = minetest.get_content_id("flight_world:poppy"),
		red_tulip = minetest.get_content_id("flight_world:red_tulip"),
		pink_tulip = minetest.get_content_id("flight_world:pink_tulip"),
		oxeye_daisy = minetest.get_content_id("flight_world:oxeye_daisy"),
		lily_of_the_valley = minetest.get_content_id("flight_world:lily_of_the_valley"),
	}

	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local height = terrain_height(x, z)
			local biome = biome_at(x, z, height)

			for y = minp.y, maxp.y do
				local vi = area:index(x, y, z)

				if in_airfield_clearance(x, z) then
					if y > 0 then
						data[vi] = c.air
					elseif y == 0 then
						local airfield_node = airfield_node_name(x, z)
						if airfield_node == "flight_world:spawn_marker" then
							data[vi] = c.marker
						elseif airfield_node == "flight_world:runway" then
							data[vi] = c.runway
						elseif airfield_node == "flight_world:stripe" then
							data[vi] = c.stripe
						else
							data[vi] = c.ground
						end
					else
						data[vi] = c.dirt
					end
				elseif y > height then
					data[vi] = c.air
				else
					data[vi] = content_for_terrain(x, y, z, height, biome, c)
				end
			end

			maybe_place_tree(data, area, minp, maxp, x, z, height, biome, c)
			maybe_place_plant(data, area, minp, maxp, x, z, height, biome, c)
		end
	end

	vm:set_data(data)
	-- Do not let generated high chunks project full-strength darkness into
	-- lower chunks. Nearby objects can still shade locally, but overhead clouds
	-- or floating islands should only feel like soft atmospheric shade in a
	-- flight game, not black holes on the ground.
	vm:calc_lighting(nil, nil, false)
	vm:write_to_map()
end)

minetest.register_on_newplayer(function(player)
	minetest.after(0.2, function()
		if player and player:is_player() then
			WORLD.spawn_player(player)
		end
	end)
end)

minetest.register_on_respawnplayer(function(player)
	WORLD.spawn_player(player)
	return true
end)

minetest.register_on_joinplayer(function(player)
	minetest.after(0.5, function()
		if player and player:is_player() then
			WORLD.player_runway_slot(player:get_player_name())
			WORLD.apply_player_skin(player)
			WORLD.apply_flight_environment(player)
		end
	end)
end)

minetest.register_chatcommand("airfield", {
	description = "Repair your runway, a numbered runway, or the full Skywright runway ring.",
	params = "[mine|all|1-12]",
	func = function(name, param)
		param = (param or ""):lower():match("^%s*(.-)%s*$")
		if param == "all" then
			WORLD.place_airfield()
			return true, "Skywright runway ring refreshed. This is a heavy repair operation."
		end

		local slot = tonumber(param)
		if not slot then
			slot = WORLD.player_runway_slot(name)
		end
		slot = clamp(math.floor(slot), 1, RUNWAY_COUNT)
		WORLD.place_airfield(slot)
		return true, string.format("Skywright runway %d refreshed.", slot)
	end,
})

minetest.register_chatcommand("runway", {
	description = "Show your assigned Skywright home runway.",
	func = function(name)
		local slot = WORLD.player_runway_slot(name)
		local pos = WORLD.spawn_pos_for_slot(slot)
		return true, string.format("Your home runway is %d/12 near (%d, %d, %d).", slot, pos.x, pos.y, pos.z)
	end,
})

minetest.register_chatcommand("greenery", {
	description = "Lightly seed flowers, grass, and a few thin trees into already-generated terrain.",
	params = "[radius]",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		local plants, trees, radius = WORLD.seed_greenery(player:get_pos(), tonumber(param) or 32)
		return true, string.format("Seeded %d small plants and %d thin trees within %d nodes.", plants, trees, radius)
	end,
})

minetest.register_chatcommand("softlight", {
	description = "Relight the nearby Skywright terrain after shadow/lighting changes.",
	params = "[radius]",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		local radius = tonumber(param) or 160
		radius = clamp(math.floor(radius), 32, 320)
		local pos = vector.round(player:get_pos())
		local minp = { x = pos.x - radius, y = -64, z = pos.z - radius }
		local maxp = { x = pos.x + radius, y = 220, z = pos.z + radius }

		if minetest.fix_light(minp, maxp) then
			return true, string.format("Relit nearby terrain within %d nodes.", radius)
		end
		return false, "That area is not fully generated yet. Fly or walk around it once, then try /softlight again."
	end,
})

flight_world = WORLD
