local Constants = require("constants")

------------------------------------------------------------------------
--- Functions to create and remove solidifiers when recyclers are built and destroyed.

---@param recycler LuaEntity
local function createSolidifier(recycler)
	if Constants.TESTING then game.print("Creating solidifier...") end
	local created = recycler.surface.create_entity{
		name = "recycle-solidifier",
		position = recycler.position,
		force = recycler.force,
		orientation = recycler.orientation,
		direction = recycler.direction,
	}
	-- Seems mirroring can't go in create_entity, has to be separate?
	if created ~= nil then
		created.mirroring = recycler.mirroring
	end
end

local function deleteSolidifier(recycler)
	if Constants.TESTING then game.print("Deleting solidifiers for a recycler...") end
	local ents = recycler.surface.find_entities_filtered{
		name = "recycle-solidifier",
		position = recycler.position,
	}
	for _, ent in pairs(ents) do
		ent.destroy()
		if Constants.TESTING then game.print("Deleted a solidifier") end
	end
end

local function maybeCreateSolidifier(recycler)
	-- Creates a solidifier if one doesn't already exist.
	if recycler.valid then
		local existing = recycler.surface.find_entities_filtered{
			name = "recycle-solidifier",
			position = recycler.position,
		}
		if #existing == 0 then
			createSolidifier(recycler)
		end
	end
end

------------------------------------------------------------------------
--- Event handlers

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_built | EventData.script_raised_revive | EventData.on_entity_cloned
local function onCreatedRecycler(event)
	createSolidifier(event.entity)
end

local function onDestroyedRecycler(event)
	deleteSolidifier(event.entity)
end

---@param event EventData.on_player_rotated_entity | EventData.on_player_flipped_entity
local function onMovedRecycler(event)
	-- Called when player rotates or flips recycler
	if event.entity == nil or event.entity.type ~= "furnace" or event.entity.name ~= "recycler" then return end
	deleteSolidifier(event.entity)
	createSolidifier(event.entity)
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

for _, event in pairs{
	defines.events.on_player_mined_entity,
	defines.events.on_robot_mined_entity,
	defines.events.on_entity_died,
	defines.events.script_raised_destroy,
} do
	script.on_event(event, onDestroyedRecycler, {{filter = "name", name = "recycler"}})
end

for _, event in pairs{
	defines.events.on_player_rotated_entity,
	defines.events.on_player_flipped_entity,
} do
	script.on_event(event, onMovedRecycler, nil) -- Doesn't support filtering.
end

------------------------------------------------------------------------
--- Handle the case where it's added to an existing game.

local function initialScan()
	for _, surface in pairs(game.surfaces) do
		for _, ent in pairs(surface.find_entities_filtered{type = "furnace", name = "recycler"}) do
			maybeCreateSolidifier(ent)
		end
	end
end
script.on_init(initialScan)
