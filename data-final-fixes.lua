local Constants = require("constants")

-- Create a crafting category for handcrafting only, for the manual-scrap-recycling recipe.
data:extend{
	{
		type = "recipe-category",
		name = "handcrafting-only",
	},
}
table.insert(data.raw["god-controller"]["default"].crafting_categories, "handcrafting-only")
table.insert(data.raw["character"]["character"].crafting_categories, "handcrafting-only")

-- Create a manual scrap-recycling recipe.
local manualScrapRecyclingRecipe = table.deepcopy(data.raw.recipe["scrap-recycling"])
manualScrapRecyclingRecipe.name = "manual-scrap-recycling"
manualScrapRecyclingRecipe.category = "handcrafting-only"
manualScrapRecyclingRecipe.localised_name = manualScrapRecyclingRecipe.localised_name or {"recipe-name.scrap-recycling"}
data:extend{manualScrapRecyclingRecipe}

-- Replace scrap recycling recipe unlocked by Recycling technology with the new manual scrap recycling recipe.
for _, effect in pairs(data.raw.technology["recycling"].effects) do
	if effect.type == "unlock-recipe" and effect.recipe == "scrap-recycling" then
		effect.recipe = "manual-scrap-recycling"
		break
	end
end

-- Non-handcrafted scrap recycling should be hidden and enabled from the start.
data.raw.recipe["scrap-recycling"].hidden = true
data.raw.recipe["scrap-recycling"].enabled = true

-- Utility function to get items.
local itemSubtypes = {
	"item",
	"capsule",
	"ammo",
	"capsule",
	"gun",
	"item-with-entity-data",
	--"item-with-label",
	--"item-with-inventory",
	"blueprint-book",
	--"item-with-tags",
	"selection-tool",
	"blueprint",
	"copy-paste-tool",
	"deconstruction-item",
	"spidertron-remote",
	"upgrade-item",
	"module",
	"rail-planner",
	"space-platform-starter-pack",
	"tool",
	"armor",
	"repair-tool",
}
local function getItem(name)
	for _, subtype in ipairs(itemSubtypes) do
		log(subtype)
		local item = data.raw[subtype][name]
		if item then return item end
	end
end

-- For each recycle recipe, create a placeholder fluid for the input, and a recipe to solidify the fluid to the recycle recipe's outputs.
for _, recipe in pairs(data.raw.recipe) do
	if (recipe.category == "recycling" or recipe.category == "recycling-or-hand-crafting") and #recipe.ingredients == 1 then
		local ingredientName = recipe.ingredients[1].name
		local fluidName = "RECYCLING-" .. ingredientName
		local item = getItem(ingredientName)
		if item == nil then error("Item " .. ingredientName .. " not found") end

		-- Create the new fluid.
		---@type data.FluidPrototype
		local fluid = {
			type = "fluid",
			name = fluidName,
			localised_name = item.localised_name or {"item-name." .. ingredientName},
			order = item.order,
			subgroup = "fluid",
			base_color = {r = 0.5, g = 0.5, b = 0.5},
			flow_color = {r = 0.5, g = 0.5, b = 0.5},
			default_temperature = 25,
			hidden = not Constants.TESTING,

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
			localised_name = {"recipe-name.solidify-recycling", item.localised_name or {"item-name." .. ingredientName}},
			enabled = true,

			--hidden = not Constants.TESTING,
			hidden = true,
			hidden_in_factoriopedia = false,
			hide_from_player_crafting = true,

			energy_required = 1,
			ingredients = {{type = "fluid", name = fluidName, amount = 1}},
			results = originalResults,

			icon = recipe.icon,
			icon_size = recipe.icon_size,
			icons = recipe.icons,
		}
		data:extend{solidifyRecipe}

		-- Redirect original recipe to the solidifier recipe.
		recipe.factoriopedia_alternative = "SOLIDIFY-" .. fluidName
	end
end

-- Create solidifier furnace entity that turns these fluids into items.
---@type data.FurnacePrototype
local solidifierEnt = table.deepcopy(data.raw.furnace.recycler)
solidifierEnt.name = "recycle-solidifier"
solidifierEnt.flags = {"not-on-map", "not-in-kill-statistics", "not-deconstructable", "not-flammable"}
--solidifierEnt.selectable_in_game = Constants.TESTING
solidifierEnt.selectable_in_game = false
solidifierEnt.minable = nil
solidifierEnt.allowed_effects = {}
solidifierEnt.module_slots = 0
solidifierEnt.next_upgrade = nil
solidifierEnt.crafting_categories = {"solidify-recycled-items"}
solidifierEnt.result_inventory_size = 10
solidifierEnt.source_inventory_size = 0
solidifierEnt.energy_usage = "1W"
solidifierEnt.source_inventory_size = 0
solidifierEnt.crafting_speed = 1000
solidifierEnt.energy_source = {type = "void"}
solidifierEnt.order = data.raw.item["recycler"].order .. "-1"
solidifierEnt.show_recipe_icon = false
solidifierEnt.show_recipe_icon_on_map = false
solidifierEnt.fluid_boxes = {
	{
		production_type = "input",
		pipe_picture = nil,
		pipe_covers = nil,
		base_area = 10,
		base_level = -1,
		pipe_connections = {{flow_direction = "input", position = {0, -1}, direction = defines.direction.south}},
		secondary_draw_orders = {north = -1},
		volume = 100,
		hide_connection_info = not Constants.TESTING,
	},
}
solidifierEnt.icons = data.raw.recipe["recycler-recycling"].icons
solidifierEnt.working_sound = nil
solidifierEnt.graphics_set = nil
solidifierEnt.graphics_set_flipped = nil
solidifierEnt.ambient_sounds = nil
solidifierEnt.ambient_sounds_group = nil
solidifierEnt.working_sound = nil
data:extend{solidifierEnt}

-- Recycler no longer outputs solid result.
data.raw.furnace.recycler.vector_to_place_result = nil

-- Recycler shouldn't allow quality.
local newRecyclerAllowed = {}
for _, effect in pairs(data.raw.furnace.recycler.allowed_effects) do
	if effect ~= "quality" then
		table.insert(newRecyclerAllowed, effect)
	end
end
data.raw.furnace.recycler.allowed_effects = newRecyclerAllowed

if Constants.TESTING then
	-- Create item for solidifier.
	local solidifierItem = table.deepcopy(data.raw.item["assembling-machine-2"])
	solidifierItem.name = "recycle-solidifier"
	solidifierItem.place_result = "recycle-solidifier"
	solidifierItem.subgroup = data.raw.item["recycler"].subgroup
	solidifierItem.order = data.raw.item["recycler"].order .. "-1"
	data:extend{solidifierItem}

	-- Create recipe for solidifier.
	local solidifierRecipe = table.deepcopy(data.raw.recipe["assembling-machine-2"])
	solidifierRecipe.name = "recycle-solidifier"
	solidifierRecipe.results = {{type = "item", name = "recycle-solidifier", amount = 1}}
	data:extend{solidifierRecipe}
	table.insert(data.raw.technology["recycling"].effects, 2, {type = "unlock-recipe", recipe = "recycle-solidifier"})
end

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
		base_area = 10,
		base_level = -1,
		pipe_connections = {{flow_direction = "output", position = {0, 0}, direction = defines.direction.north}},
		volume = 1,
		hide_connection_info = not Constants.TESTING,
	},
}
data.raw.furnace.recycler.result_inventory_size = 0