local HIDE_CONNECTIONS = true -- Whether to hide fluid connections. True for release, false when testing.
local SOLIDIFIER_SELECTABLE = false -- Whether to allow the solidifier to be selected in the game. False for release.
local SOLIDIFIER_SELECTION_PRIORITY = 1 -- Set to 51 to select over recycler, 1 to select recycler instead.

---@return data.ItemPrototype?
local function getItem(name)
	for subtype, _ in pairs(defines.prototypes.item) do
		if data.raw[subtype] ~= nil then -- Necessary because eg when running without Space Age there's no "space-platform-starter-pack" type.
			---@diagnostic disable-next-line: assign-type-mismatch
			local item = data.raw[subtype][name]
			---@diagnostic disable-next-line: return-type-mismatch
			if item then return item end
		end
	end
end

-- Create subgroups.
data:extend{
	{
		type = "item-subgroup",
		name = "solidify-recycling-fluid",
		order = "z1",
		group = "other",
	},
	{
		type = "item-subgroup",
		name = "recycling",
		order = "z2",
		group = "other",
	},
	{
		type = "item-subgroup",
		name = "recycling-fluid",
		order = "z3",
		group = "other",
	},
}

local ignoreItemRecycling = {
	["item-unknown"] = true,
	["copy-paste-tool"] = true,
	["cut-paste-tool"] = true,
	["empty-module-slot"] = true,
}

-- For each recycle recipe, create a placeholder fluid for the input, and a recipe to solidify the fluid to the recycle recipe's outputs.
local function handleRecyclingRecipe(recipe)
	if (recipe.category ~= "recycling" and recipe.category ~= "recycling-or-hand-crafting") then return end
	if #recipe.ingredients ~= 1 then return end

	local ingredientName = recipe.ingredients[1].name
	local fluidName = "RECYCLING-" .. ingredientName
	local item = getItem(ingredientName)
	if item == nil then
		log("ERROR: Item " .. ingredientName .. " not found")
		return
	end
	if item.parameter or item.hidden or ignoreItemRecycling[ingredientName] then return end

	local itemLocalisedName -- Try to guess what localised names are defined.
	if item.localised_name ~= nil then
		itemLocalisedName = item.localised_name
	elseif item.place_result ~= nil then
		itemLocalisedName = {"entity-name." .. item.place_result}
	elseif item.place_as_equipment_result ~= nil then
		itemLocalisedName = {"equipment-name." .. item.place_as_equipment_result}
	else
		itemLocalisedName = {"item-name." .. ingredientName}
	end

	-- Create the new fluid.
	---@type data.FluidPrototype
	local fluid = {
		type = "fluid",
		name = fluidName,
		localised_name = {"fluid-name.recycling-fluid", itemLocalisedName},
		localised_description = {"recipe-description.redirect-to-solidify-recipe", "SOLIDIFY-" .. fluidName},
		order = item.order,
		subgroup = "recycling-fluid",
		base_color = {r = 0.5, g = 0.5, b = 0.5},
		flow_color = {r = 0.5, g = 0.5, b = 0.5},
		default_temperature = 25,
		hidden = false,
		hidden_in_factoriopedia = false,

		icon = recipe.icon,
		icon_size = recipe.icon_size,
		icons = recipe.icons,
	}
	data:extend{fluid}

	-- Make the recycler's recipe output the fluid.
	local originalResults = recipe.results
	recipe.results = {{type = "fluid", name = fluidName, amount = 1}}

	-- Make a new recipe to solidify the fluid.
	---@type data.RecipePrototype
	local solidifyRecipe = {
		type = "recipe",
		name = "SOLIDIFY-" .. fluidName,
		category = "solidify-recycled-items",
		localised_name = {"recipe-name.solidify-recycling", itemLocalisedName},
		enabled = true,

		hidden = false, -- Must be false, or else you can't click through from the fluid.
		hidden_in_factoriopedia = false,
		hide_from_player_crafting = true,
		subgroup = "solidify-recycling-fluid",

		energy_required = recipe.energy_required,
		ingredients = {{type = "fluid", name = fluidName, amount = 1}},
		results = originalResults,

		icon = recipe.icon,
		icon_size = recipe.icon_size,
		icons = recipe.icons,
	}
	data:extend{solidifyRecipe}

	-- Redirect original recipe to the solidifier recipe. This doesn't work, so rather just add description.
	--[[recipe.factoriopedia_alternative = solidifyRecipe.name
	recipe.hidden_in_factoriopedia = false
	recipe.hidden = false
	recipe.subgroup = "recycling"
	if recipe.category ~= "recycling-or-hand-crafting" then
		recipe.hide_from_player_crafting = true
	end
	]]
	recipe.localised_description = {"recipe-description.redirect-to-solidify-recipe", solidifyRecipe.name}
end
for _, recipe in pairs(data.raw.recipe) do
	handleRecyclingRecipe(recipe)
end

-- Create solidifier furnace entity that turns these fluids into items.
---@type data.FurnacePrototype
local solidifierEnt = table.deepcopy(data.raw.furnace.recycler)
solidifierEnt.name = "recycle-solidifier"
solidifierEnt.flags = {
	"not-on-map",
	"not-in-kill-statistics",
	"not-deconstructable",
	"not-flammable",
	"placeable-off-grid", -- So it can go in the center of the recycler.
	"no-automated-item-removal",
	"no-automated-item-insertion", -- So inserters won't target it instead of the recycler.
}
solidifierEnt.selectable_in_game = SOLIDIFIER_SELECTABLE
solidifierEnt.selection_priority = SOLIDIFIER_SELECTION_PRIORITY
solidifierEnt.minable = nil
solidifierEnt.allowed_effects = {}
solidifierEnt.module_slots = 0
solidifierEnt.next_upgrade = nil
solidifierEnt.crafting_categories = {"solidify-recycled-items"}
solidifierEnt.result_inventory_size = 10
solidifierEnt.source_inventory_size = 0
solidifierEnt.fast_replaceable_group = nil
solidifierEnt.crafting_speed = 1000
solidifierEnt.energy_source = {type = "void"}
solidifierEnt.energy_usage = "1W"
solidifierEnt.order = data.raw.item["recycler"].order .. "-1"
solidifierEnt.show_recipe_icon = false
solidifierEnt.show_recipe_icon_on_map = false
solidifierEnt.fluid_boxes = {
	{
		production_type = "input",
		pipe_picture = nil,
		pipe_covers = nil,
		pipe_connections = {{flow_direction = "input", position = {0, 0}, direction = defines.direction.south}},
		secondary_draw_orders = {north = -1},
		volume = 1,
		hide_connection_info = HIDE_CONNECTIONS,
	},
}
solidifierEnt.icons = data.raw.recipe["recycler-recycling"].icons
solidifierEnt.working_sound = nil
solidifierEnt.graphics_set = nil
solidifierEnt.graphics_set_flipped = nil
solidifierEnt.ambient_sounds = nil
solidifierEnt.ambient_sounds_group = nil
solidifierEnt.working_sound = nil
solidifierEnt.hidden = true
solidifierEnt.hidden_in_factoriopedia = true
solidifierEnt.collision_mask = {layers={}}
-- Solidifier needs to have a smaller collision box, so inserters etc. prefer to place things into the recycler, not the solidifier.
solidifierEnt.collision_box = {{-.1, -.1}, {.1, .1}}
solidifierEnt.selection_box = solidifierEnt.collision_box
solidifierEnt.tile_width = 1
solidifierEnt.tile_height = 1
data:extend{solidifierEnt}

-- Recycler no longer outputs solid result.
-- But, still want to show the arrow when placing it.
--data.raw.furnace.recycler.vector_to_place_result = nil

-- Recycler shouldn't allow quality.
local newRecyclerAllowed = {}
for _, effect in pairs(data.raw.furnace.recycler.allowed_effects) do
	if effect ~= "quality" then
		table.insert(newRecyclerAllowed, effect)
	end
end
data.raw.furnace.recycler.allowed_effects = newRecyclerAllowed

-- Create crafting category for solidifying recycled items.
---@type data.RecipeCategory
local solidifyRecycledItems = {
	type = "recipe-category",
	name = "solidify-recycled-items",
}
data:extend{solidifyRecycledItems}

-- Give the recycling machine a fluid output.
data.raw.furnace.recycler.fluid_boxes = {
	{
		production_type = "output",
		pipe_picture = nil,
		pipe_covers = nil,
		pipe_connections = {{flow_direction = "output", position = {0, 1}, direction = defines.direction.north}},
		volume = 1,
		hide_connection_info = HIDE_CONNECTIONS,
	},
}
data.raw.furnace.recycler.result_inventory_size = 0