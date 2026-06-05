flight_hud = {}

local huds = {}
local HORIZON_POINTS = { -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6 }
local CONSOLE_LINES_PER_PAGE = 5
local CONSOLE_TEXTURE = "console.png"
local CONSOLE_TOGGLE_TEXTURE = "console_toggle_button.png"
local CONSOLE_FULL_POSITION = { x = 0.985, y = 0.52 }
local CONSOLE_TEXT_POSITION = { x = 0.93, y = 0.59 }
local CONSOLE_MIN_POSITION = { x = 0.985, y = 0.875 }
local CONSOLE_WARN_POSITION = { x = 0.93, y = 0.805 }
local CONSOLE_FULL_SCALE = { x = 1.35, y = 1.35 }
local CONSOLE_MIN_SCALE = { x = 12, y = 12 }
local CONSOLE_ALIGNMENT = { x = -1, y = 1 }
local EDIT_FORM = "flight_hud:config_editor"
local console_state = {}

local CONSOLE_LABELS = {
	plane_color = "color",
	pitch_rate = "pitch",
	roll_rate = "roll",
	yaw_control = "yaw",
	rudder_rate = "rutter sens",
	rudder_count = "rutters",
	adverse_yaw = "adverse yaw",
	yaw_damper = "yaw damper",
	yaw_roll_coupling = "yaw roll",
	stall_sensitivity = "stall sens",
	plane_gravity_effect = "gravity",
	max_speed = "max speed",
	speed_lower_limit = "min speed",
	thrust_accel = "thrust",
	lift_coeff = "lift",
	drag_coeff = "drag",
	stall_drag_coeff = "stall drag",
	brake_drag_coeff = "brake drag",
	side_slip_drag = "slip drag",
	ground_friction = "friction",
	max_dive_speed = "dive speed",
	dive_gravity_multiplier = "dive grav",
	control_speed = "ctrl speed",
}

local function bank_label(roll)
	local degrees = math.deg(roll or 0)
	local side = "LEVEL"
	if degrees > 2 then
		side = "RIGHT"
	elseif degrees < -2 then
		side = "LEFT"
	end
	return string.format("%s %2.0f deg", side, math.abs(degrees))
end

local function horizon_line(roll)
	local degrees = math.deg(roll or 0)
	if degrees < -45 then
		return "\\\\____"
	elseif degrees < -25 then
		return "\\\\___/"
	elseif degrees < -10 then
		return "\\___/"
	elseif degrees > 45 then
		return "____//"
	elseif degrees > 25 then
		return "\\___//"
	elseif degrees > 10 then
		return "\\___/"
	end
	return "--|--"
end

local function hud_text(state)
	local stall = state.stall and "STALL - nose down, build speed" or "OK"
	local grounded = state.grounded and "GROUND" or "AIR"

	return string.format(
		"Skywright Trainer - Chase View\nAirspeed: %4.1f m/s\nAltitude AGL: %4.1f m\nVertical: %+4.1f m/s\nThrottle: %3d%%\nState: %s / %s\nAttitude: nose %+3.0f deg  bank %s\nReference: %s\nW/S pitch  A/D roll  Aux+A/D rudder\nJump/Sneak throttle  Place brake\nPunch or /fire missile  Shift+E eject  /exitplane",
		state.airspeed or 0,
		state.altitude or 0,
		state.vertical_speed or 0,
		math.floor((state.throttle or 0) * 100 + 0.5),
		grounded,
		stall,
		math.deg(state.pitch or 0),
		bank_label(state.roll),
		horizon_line(state.roll)
	)
end

local function console_page_count()
	if not flight_core or not flight_core.config_fields then
		return 1
	end
	return math.max(1, math.ceil(#flight_core.config_fields / CONSOLE_LINES_PER_PAGE))
end

local function get_console_state(name)
	if not console_state[name] then
		console_state[name] = {
			visible = true,
			page = 1,
		}
	end
	return console_state[name]
end

local function danger_for(field, value)
	if field and field.kind == "text" then
		return false
	end
	if not field or type(value) ~= "number" then
		return true
	end
	return math.abs(value) > math.abs(field.danger or math.huge)
end

local function console_label(field)
	return CONSOLE_LABELS[field.key] or field.label or field.key
end

local function console_text(name, state)
	local ui = get_console_state(name)
	if not ui.visible then
		return "CFG\n/fcfg"
	end
	if not flight_core or not flight_core.config_fields then
		return "FLIGHT CONFIG\nloading..."
	end

	local fields = flight_core.config_fields
	local pages = console_page_count()
	ui.page = math.max(1, math.min(ui.page or 1, pages))
	local first = (ui.page - 1) * CONSOLE_LINES_PER_PAGE + 1
	local last = math.min(#fields, first + CONSOLE_LINES_PER_PAGE - 1)
	local config = state.config or {}
	local lines = {
		string.format("CFG %d/%d  /fedit", ui.page, pages),
		"/fset key value",
		"/fsave  /fpage",
		"----------------",
	}

	for index = first, last do
		local field = fields[index]
		if field.kind == "text" then
			local value = tostring(config[field.key] or "")
			lines[#lines + 1] = string.format("  %-10s %s", console_label(field), value:sub(1, 8))
		else
			local value = tonumber(config[field.key]) or 0
			local marker = danger_for(field, value) and "!" or " "
			lines[#lines + 1] = string.format("%s %-10s % .5g", marker, console_label(field), value)
		end
	end

	return table.concat(lines, "\n")
end

local function console_warning_text(name, state)
	local ui = get_console_state(name)
	if not ui.visible or not flight_core or not flight_core.config_fields then
		return ""
	end

	local fields = flight_core.config_fields
	local first = (ui.page - 1) * CONSOLE_LINES_PER_PAGE + 1
	local last = math.min(#fields, first + CONSOLE_LINES_PER_PAGE - 1)
	local config = state.config or {}
	local warnings = {}

	for index = first, last do
		local field = fields[index]
		local value = field.kind == "text" and config[field.key] or tonumber(config[field.key]) or 0
		if field.kind ~= "text" and danger_for(field, value) then
			warnings[#warnings + 1] = field.label
		end
	end

	if #warnings == 0 then
		return ""
	end
	return "WARN: " .. table.concat(warnings, ", "):sub(1, 28)
end

local function current_console_page(name)
	local ui = get_console_state(name)
	local pages = console_page_count()
	ui.page = math.max(1, math.min(ui.page or 1, pages))
	return ui.page, pages
end

function flight_hud.show(player)
	local name = player:get_player_name()
	flight_hud.hide(player)

	local entry = {
		horizon = {},
	}

	entry.info = player:hud_add({
		type = "text",
		position = { x = 0.02, y = 0.82 },
		offset = { x = 0, y = 0 },
		alignment = { x = 1, y = 1 },
		scale = { x = 100, y = 100 },
		text = "Skywright Trainer",
		number = 0xE8F2FF,
	})

	-- Server-side Luanti HUDs cannot provide editable widgets, so this image is
	-- a cockpit-style panel behind the command-driven configuration console.
	entry.console_panel = player:hud_add({
		type = "image",
		position = CONSOLE_FULL_POSITION,
		offset = { x = 0, y = 0 },
		alignment = CONSOLE_ALIGNMENT,
		scale = CONSOLE_FULL_SCALE,
		text = CONSOLE_TEXTURE,
		z_index = 16,
	})

	entry.console = player:hud_add({
		type = "text",
		position = CONSOLE_TEXT_POSITION,
		offset = { x = 0, y = 0 },
		alignment = CONSOLE_ALIGNMENT,
		scale = { x = 60, y = 60 },
		text = "FLIGHT CONFIG",
		number = 0xAEEBFF,
		z_index = 18,
	})

	entry.console_warn = player:hud_add({
		type = "text",
		position = CONSOLE_WARN_POSITION,
		offset = { x = 0, y = 0 },
		alignment = CONSOLE_ALIGNMENT,
		scale = { x = 54, y = 54 },
		text = "",
		number = 0xFF6060,
		z_index = 19,
	})

	for _, point in ipairs(HORIZON_POINTS) do
		local text = point == 0 and "+" or "-"
		entry.horizon[#entry.horizon + 1] = player:hud_add({
			type = "text",
			position = { x = 0.5, y = 0.5 },
			offset = { x = point * 18, y = 0 },
			alignment = { x = 0, y = 0 },
			scale = { x = 100, y = 100 },
			text = text,
			number = point == 0 and 0xFFFFFF or 0x72D7FF,
			z_index = 10,
		})
	end

	huds[name] = entry
end

local function update_horizon(player, entry, state)
	local roll = state.roll or 0
	local pitch = state.pitch or 0
	local c = math.cos(roll)
	local s = math.sin(roll)
	local pitch_offset = math.max(-70, math.min(70, -math.deg(pitch) * 1.5))

	for index, id in ipairs(entry.horizon) do
		local point = HORIZON_POINTS[index]
		local distance = point * 18
		local offset = {
			x = math.floor(distance * c + 0.5),
			y = math.floor(pitch_offset + distance * s + 0.5),
		}
		local key = "horizon_" .. index
		local value_key = offset.x .. ":" .. offset.y
		entry.cache = entry.cache or {}
		if entry.cache[key] ~= value_key then
			entry.cache[key] = value_key
			player:hud_change(id, "offset", offset)
		end
	end
end

local function hud_change_cached(player, entry, id, stat, value, cache_key)
	if not id then
		return
	end
	entry.cache = entry.cache or {}
	cache_key = cache_key or tostring(id) .. ":" .. stat
	if entry.cache[cache_key] == value then
		return
	end
	entry.cache[cache_key] = value
	player:hud_change(id, stat, value)
end

local function update_console_layout(player, entry, visible)
	if entry.console_visible == visible then
		return
	end
	entry.console_visible = visible

	local position = visible and CONSOLE_FULL_POSITION or CONSOLE_MIN_POSITION
	local scale = visible and CONSOLE_FULL_SCALE or CONSOLE_MIN_SCALE
	local texture = visible and CONSOLE_TEXTURE or CONSOLE_TOGGLE_TEXTURE

	if entry.console_panel then
		player:hud_change(entry.console_panel, "position", position)
		player:hud_change(entry.console_panel, "scale", scale)
		player:hud_change(entry.console_panel, "text", texture)
	end
	if entry.console then
		player:hud_change(entry.console, "position", visible and CONSOLE_TEXT_POSITION or position)
		player:hud_change(entry.console, "scale", visible and { x = 60, y = 60 } or { x = 90, y = 90 })
	end
	if entry.console_warn then
		player:hud_change(entry.console_warn, "position", CONSOLE_WARN_POSITION)
	end
end

function flight_hud.update(player, state)
	local name = player:get_player_name()
	if not huds[name] then
		flight_hud.show(player)
	end
	local entry = huds[name]
	local ui = get_console_state(name)
	hud_change_cached(player, entry, entry.info, "text", hud_text(state), "info_text")
	update_console_layout(player, entry, ui.visible)
	if entry.console then
		hud_change_cached(player, entry, entry.console, "text", console_text(name, state), "console_text")
	end
	if entry.console_warn then
		hud_change_cached(player, entry, entry.console_warn, "text", console_warning_text(name, state), "console_warn_text")
	end
	update_horizon(player, entry, state)
end

function flight_hud.toggle_console(player)
	local name = player:get_player_name()
	local ui = get_console_state(name)
	ui.visible = not ui.visible
	return ui.visible
end

function flight_hud.set_console_page(player, page)
	local name = player:get_player_name()
	local ui = get_console_state(name)
	local pages = console_page_count()

	if page == "next" or page == "+" then
		ui.page = (ui.page or 1) + 1
	elseif page == "prev" or page == "previous" or page == "-" then
		ui.page = (ui.page or 1) - 1
	else
		ui.page = tonumber(page) or ui.page or 1
	end

	if ui.page > pages then
		ui.page = 1
	elseif ui.page < 1 then
		ui.page = pages
	end

	return ui.page, pages
end

function flight_hud.show_config_editor(player)
	local name = player:get_player_name()
	if not flight_core or not flight_core.config_fields then
		return false, "Flight config is not loaded."
	end

	local page, pages = current_console_page(name)
	local fields = flight_core.config_fields
	local config = flight_core.get_config(name)
	local first = (page - 1) * CONSOLE_LINES_PER_PAGE + 1
	local last = math.min(#fields, first + CONSOLE_LINES_PER_PAGE - 1)
	local fs = {
		"formspec_version[4]",
		"size[6.4,7.4]",
		"position[1,1]",
		"anchor[1,1]",
		"no_prepend[]",
		"bgcolor[#071416D8;true]",
		"background9[0,0;6.4,7.4;" .. CONSOLE_TEXTURE .. ";true;12]",
		"style_type[label;textcolor=#AEEBFF]",
		"style_type[field;textcolor=#EAF8FF;border=false;bgcolor=#06282CCC]",
		"style_type[button;textcolor=#EAF8FF;bgcolor=#104F59CC]",
		string.format("label[0.55,0.42;FLIGHT CONFIG %d/%d]", page, pages),
		"label[0.55,0.78;Edit values, then Apply or Save.]",
		"label[0.55,1.08;HUD fallback: /fset key value]",
	}

	local y = 1.55
	for index = first, last do
		local field = fields[index]
		local value = field.kind == "text" and tostring(config[field.key] or "") or tonumber(config[field.key]) or 0
		local color = danger_for(field, value) and "#FF6060" or "#AEEBFF"
		fs[#fs + 1] = string.format("style[label_%s;textcolor=%s]", field.key, color)
		fs[#fs + 1] = string.format(
			"label[0.55,%.2f;%s]",
			y,
			minetest.formspec_escape(console_label(field))
		)
		fs[#fs + 1] = string.format(
			"field[3.45,%.2f;2.25,0.42;cfg_%s;;%s]",
			y - 0.14,
			field.key,
			minetest.formspec_escape(field.kind == "text" and value or string.format("%.6g", value))
		)
		fs[#fs + 1] = string.format("tooltip[cfg_%s;%s]", field.key, minetest.formspec_escape(field.key))
		y = y + 0.58
	end

	fs[#fs + 1] = "button[0.55,6.18;1.15,0.55;prev;Prev]"
	fs[#fs + 1] = "button[1.82,6.18;1.15,0.55;next;Next]"
	fs[#fs + 1] = "button[3.08,6.18;1.25,0.55;apply;Apply]"
	fs[#fs + 1] = "button[4.48,6.18;1.25,0.55;save;Save]"
	fs[#fs + 1] = "button_exit[4.48,6.82;1.25,0.42;close;Close]"
	fs[#fs + 1] = "button[0.55,6.82;1.75,0.42;reset;Reset]"

	minetest.show_formspec(name, EDIT_FORM, table.concat(fs, ""))
	return true, "Flight config editor opened."
end

local function apply_editor_fields(player, fields)
	local name = player:get_player_name()
	local messages = {}
	local ok = true
	for _, field in ipairs(flight_core.config_fields or {}) do
		local raw = fields["cfg_" .. field.key]
		if raw and raw ~= "" then
			local changed, message = flight_core.set_config_value(name, field.key, raw)
			if not changed then
				ok = false
				messages[#messages + 1] = message
			end
		end
	end
	if not ok then
		minetest.chat_send_player(name, table.concat(messages, "\n"))
	end
	return ok
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= EDIT_FORM then
		return false
	end
	local name = player:get_player_name()

	if fields.prev then
		flight_hud.set_console_page(player, "prev")
		flight_hud.show_config_editor(player)
		return true
	end
	if fields.next then
		flight_hud.set_console_page(player, "next")
		flight_hud.show_config_editor(player)
		return true
	end
	if fields.reset then
		flight_core.reset_config(name)
		flight_hud.show_config_editor(player)
		return true
	end
	if fields.apply or fields.save then
		if apply_editor_fields(player, fields) then
			if fields.save then
				flight_core.save_config(name, flight_core.get_config(name))
				minetest.chat_send_player(name, "Flight configuration saved.")
			else
				minetest.chat_send_player(name, "Flight configuration applied.")
			end
		end
		flight_hud.show_config_editor(player)
		return true
	end

	return true
end)

function flight_hud.hide(player)
	local name = player:get_player_name()
	if huds[name] then
		if huds[name].info then
			player:hud_remove(huds[name].info)
		end
		if huds[name].console then
			player:hud_remove(huds[name].console)
		end
		if huds[name].console_panel then
			player:hud_remove(huds[name].console_panel)
		end
		if huds[name].console_warn then
			player:hud_remove(huds[name].console_warn)
		end
		for _, id in ipairs(huds[name].horizon or {}) do
			player:hud_remove(id)
		end
		huds[name] = nil
	end
end

minetest.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)
