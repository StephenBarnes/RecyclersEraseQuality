local VERBOSE = false

------------------------------------------------------------------------
--- Death rattle utils
-- Using storage to track "death rattles" for all recyclers, so we get a callback when any recycler gets destroyed, to clean up the solidifier.

local getDeathRattles = function()
	if storage.deathRattles == nil then
		storage.deathRattles = {}
	end
	return storage.deathRattles
end

---@param recycler LuaEntity
local setDeathRattle = function(recycler)
	local deathRattles = getDeathRattles()
	deathRattles[script.register_on_object_destroyed(recycler)] = {
		"recycle-solidifier",
		recycler.surface,
		recycler.position,
	}
end

------------------------------------------------------------------------
--- Functions to create and remove solidifiers when recyclers are built and destroyed.

---@param recycler LuaEntity
local function createSolidifier(recycler)
	if VERBOSE then game.print("Creating solidifier...") end
	local created = recycler.surface.create_entity{
		name = "recycle-solidifier",
		position = recycler.position,
		force = recycler.force,
		orientation = recycler.orientation,
		direction = recycler.direction,
	}
	-- Seems mirroring can't go in create_entity, has to be separate.
	if created ~= nil then
		created.mirroring = recycler.mirroring
		created.destructible = false
	end
end

---@param surface LuaSurface
---@param position MapPosition
local function deleteSolidifier(surface, position)
	if VERBOSE then game.print("Deleting solidifiers for a recycler...") end
	local solidifiers = surface.find_entities_filtered{
		name = "recycle-solidifier",
		position = position,
	}
	for _, solidifier in pairs(solidifiers) do
		solidifier.destroy()
		if VERBOSE then game.print("Deleted a solidifier") end
	end
end

------------------------------------------------------------------------
--- Event handlers

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_built | EventData.script_raised_revive | EventData.on_entity_cloned
local function onCreatedRecycler(event)
	local ent = event.entity
	if ent == nil or not ent.valid then return end
	createSolidifier(ent)
	setDeathRattle(ent)
end

---@param e EventData.on_object_destroyed
local function onObjectDestroyed(e)
	local deathrattles = getDeathRattles()
	local deathrattle = deathrattles[e.registration_number]
	if deathrattle == nil then return end
	local surface = deathrattle[2] ---@type LuaSurface
	local position = deathrattle[3]
	deleteSolidifier(surface, position)
	-- Un-store the deathrattle.
	deathrattles[e.registration_number] = nil
end

-- Update the solidifier's direction and mirroring to match the recycler.
---@param recycler LuaEntity
---@param solidifier LuaEntity
---@param updatePos boolean
local function updateRecycler(recycler, solidifier, updatePos)
	solidifier.direction = recycler.direction
	solidifier.mirroring = recycler.mirroring
	solidifier.orientation = recycler.orientation
	if updatePos then
		--solidifier.position = recycler.position -- Can't, it's read-only.
		local success = solidifier.teleport(recycler.position)
		if not success then
			log("Failed to teleport solidifier to " .. serpent.block(recycler.position) .. ", this should not happen")
		end
	end
end

-- Find the solidifier at the given position and update it to match the recycler.
---@param recycler LuaEntity
---@param searchPos table
---@param updatePos boolean
local function findAndUpdateSolidifier(recycler, searchPos, updatePos)
	local surface = recycler.surface
	if not surface.valid then return end
	local solidifiers = surface.find_entities_filtered{
		name = "recycle-solidifier",
		position = searchPos,
	}
	if #solidifiers ~= 1 then
		log("Expected 1 recycle-solidifier at " .. serpent.block(searchPos) .. ", found " .. #solidifiers .. ", this should not happen")
		if #solidifiers == 0 then return end
	end
	local solidifier = solidifiers[1]
	if not solidifier.valid then
		log("Recycle-solidifier at " .. serpent.block(searchPos) .. " is invalid, this should not happen")
		return
	end
	updateRecycler(recycler, solidifier, updatePos)
end

---@param e EventData.on_player_rotated_entity|EventData.on_player_flipped_entity
local function onRotatedOrFlipped(e)
	local ent = e.entity
	if ent == nil or not ent.valid then return end
	-- Note event doesn't support filtering, so we need to check.
	if ent.type ~= "furnace" then return end
	if ent.name ~= "recycler" then return end
	findAndUpdateSolidifier(ent, ent.position, false)
end

---@param e {player_index:number, moved_entity:LuaEntity, start_pos:table}
local function onPickerDollyMoved(e)
	if e.moved_entity == nil or not e.moved_entity.valid then return end
	if e.moved_entity.type ~= "furnace" then return end
	if e.moved_entity.name ~= "recycler" then return end
	findAndUpdateSolidifier(e.moved_entity, e.start_pos, true)
end

------------------------------------------------------------------------
--- Register handlers

for _, event in pairs{
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.on_space_platform_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
	defines.events.on_entity_cloned,
} do
	script.on_event(event, onCreatedRecycler, {{filter = "name", name = "recycler"}})
end

script.on_event(defines.events.on_object_destroyed, onObjectDestroyed)

for _, event in pairs{
	defines.events.on_player_rotated_entity,
	defines.events.on_player_flipped_entity,
} do
	script.on_event(event, onRotatedOrFlipped) -- Doesn't support filtering.
end

local function registerPickerDollyEvents()
	-- Register for picker dollies events. (Even Pickier Dollies uses same interface.)
	if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
		script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), onPickerDollyMoved)
	end
end

------------------------------------------------------------------------
--- Handle the case where it's added to an existing game.

-- Function called when a game is loaded, for each existing recycler. This is necessary if game is added to an existing save.
---@param recycler LuaEntity
local function handleInitialScanRecycler(recycler)
	-- Creates a solidifier if one doesn't already exist.
	-- Also registers a death rattle for the recycler, if one doesn't already exist.
	if recycler.valid then
		local numExisting = recycler.surface.count_entities_filtered{
			name = "recycle-solidifier",
			position = recycler.position,
		}
		if numExisting == 0 then
			createSolidifier(recycler)
			setDeathRattle(recycler)
		end
	end
end

local function initialScan()
	for _, surface in pairs(game.surfaces) do
		for _, ent in pairs(surface.find_entities_filtered{type = "furnace", name = "recycler"}) do
			handleInitialScanRecycler(ent)
		end
	end
end

script.on_init(function()
	registerPickerDollyEvents()
	initialScan()
end)

script.on_load(registerPickerDollyEvents)