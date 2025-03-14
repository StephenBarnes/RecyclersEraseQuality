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
-- Note we need optional dependency on space-age so this runs after space-age makes the scrap-recycling recipe.
local oldScrapRecyclingRecipe = data.raw.recipe["scrap-recycling"]
if oldScrapRecyclingRecipe ~= nil then
	local newScrapRecyclingRecipe = table.deepcopy(oldScrapRecyclingRecipe)
	newScrapRecyclingRecipe.name = "manual-scrap-recycling"
	newScrapRecyclingRecipe.category = "handcrafting-only"
	newScrapRecyclingRecipe.localised_name = {"recipe-name.manual-scrap-recycling"}
	data:extend{newScrapRecyclingRecipe}

	-- Replace scrap recycling recipe unlocked by Recycling technology with the new manual scrap recycling recipe.
	for _, effect in pairs(data.raw.technology["recycling"].effects) do
		if effect.type == "unlock-recipe" and effect.recipe == "scrap-recycling" then
			effect.recipe = "manual-scrap-recycling"
			break
		end
	end

	-- Non-handcrafted scrap recycling should be hidden and enabled from the start.
	oldScrapRecyclingRecipe.hidden = true
	oldScrapRecyclingRecipe.hide_from_player_crafting = true
	oldScrapRecyclingRecipe.enabled = true
end