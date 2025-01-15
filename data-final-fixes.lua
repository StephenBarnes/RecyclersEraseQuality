local Util = require("util")

-- Collect all possible items output by recycling recipes.
local maxNumOutputs = 0
local recycleOutputItems = {}
for _, recipe in pairs(data.raw.recipe) do
	if recipe.category == "recycling" then
		for _, product in pairs(recipe.results) do
			if product.type == "item" then
				recycleOutputItems[product.name] = true
			end
		end
		maxNumOutputs = math.max(maxNumOutputs, #recipe.results)
	end
end
--log(serpent.block(recycleOutputItems))
--log(serpent.block(maxNumOutputs))

-- For each recycle output, create a placeholder fluid.
local newFluids = {}
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
for itemName, _ in pairs(recycleOutputItems) do
	local fluidName = "recycled-" .. itemName
	local item = getItem(itemName)
	if item == nil then error("Item " .. itemName .. " not found") end
	---@type data.FluidPrototype
	local fluid = {
		type = "fluid",
		name = fluidName,
		localised_name = item.localised_name or {"item-name." .. itemName},
		order = item.order,
		subgroup = "fluid",
		base_color = {r = 0.5, g = 0.5, b = 0.5},
		flow_color = {r = 0.5, g = 0.5, b = 0.5},
		default_temperature = 25,
		hidden = true,

		icon = item.icon,
		icon_size = item.icon_size,
		icons = item.icons,
	}
	table.insert(newFluids, fluid)
end
data:extend(newFluids)

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
	crafting_speed = 100,
	energy_source = {type = "void"},
	subgroup = data.raw.item["recycler"].subgroup,
	order = data.raw.item["recycler"].order .. "-1",
	fluid_boxes = {data.raw["assembling-machine"]["assembling-machine-2"].fluid_boxes[1]}, -- Keep only the input.
	icons = data.raw.recipe["assembling-machine-2-recycling"].icons,
})
data:extend{solidifierEnt}

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

-- Create crafting category for solidifying recycled items.
---@type data.RecipeCategory
local solidifyRecycledItems = {
	type = "recipe-category",
	name = "solidify-recycled-items",
}
data:extend{solidifyRecycledItems}