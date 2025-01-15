local Util = require("util")
local TESTING = true

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
	if recipe.category == "recycling" and #recipe.ingredients == 1 then
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
			hidden = not TESTING,

			icon = recipe.icon,
			icon_size = recipe.icon_size,
			icons = recipe.icons,
		}
		data:extend{fluid}

		-- Make the recycler's recipe output the fluid.
		local originalResults = recipe.results
		recipe.results = {{type = "fluid", name = fluidName, amount = 1}}

		-- Make a new recipe to solidify the fluid.
		local solidifyRecipe = {
			type = "recipe",
			name = "SOLIDIFY-" .. fluidName,
			category = "solidify-recycled-items",
			localised_name = {"recipe-name.solidify-recycling", item.localised_name or {"item-name." .. ingredientName}},
			enabled = true,
			hidden = not TESTING,
			energy_required = 1,
			ingredients = {{type = "fluid", name = fluidName, amount = 1}},
			results = originalResults,

			icon = recipe.icon,
			icon_size = recipe.icon_size,
			icons = recipe.icons,
		}
		data:extend{solidifyRecipe}
	end
end

-- Create solidifier furnace entity that turns these fluids into items.
---@type data.FurnacePrototype
local solidifierEnt = Util.copyAndEdit(data.raw["assembling-machine"]["assembling-machine-2"], {
	type = "furnace",
	name = "recycle-solidifier",
	flags = {"placeable-neutral", "placeable-player", "player-creation"},
	minable = {mining_time = 0.1, result = "recycle-solidifier"},
	allowed_effects = {},
	module_slots = 0,
	crafting_categories = {"solidify-recycled-items"},
	result_inventory_size = 10,
	source_inventory_size = 0,
	energy_usage = "1W",
	ingredient_count = 1,
	crafting_speed = 1000,
	energy_source = {type = "void"},
	subgroup = data.raw.item["recycler"].subgroup,
	order = data.raw.item["recycler"].order .. "-1",
	fluid_boxes = {data.raw["assembling-machine"]["assembling-machine-2"].fluid_boxes[1]}, -- Keep only the input.
	icons = data.raw.recipe["assembling-machine-2-recycling"].icons,
})
data:extend{solidifierEnt}

if TESTING then
	-- Create item for solidifier.
	local solidifierItem = Util.copyAndEdit(data.raw.item["assembling-machine-2"], {
		name = "recycle-solidifier",
		place_result = "recycle-solidifier",
		subgroup = data.raw.item["recycler"].subgroup,
		order = data.raw.item["recycler"].order .. "-1",
	})
	data:extend{solidifierItem}

	-- Create recipe for solidifier.
	local solidifierRecipe = Util.copyAndEdit(data.raw.recipe["assembling-machine-2"], {
		name = "recycle-solidifier",
		results = {{type = "item", name = "recycle-solidifier", amount = 1}},
	})
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
		pipe_connections = {{flow_direction = "output", position = {0.5, -1.6}, direction = defines.direction.north}},
		volume = 1,
	},
}
data.raw.furnace.recycler.result_inventory_size = 0

-- TODO still need a manual recycling recipe