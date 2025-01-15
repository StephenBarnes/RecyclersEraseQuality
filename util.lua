local Export = {}

Export.copyAndEdit = function(t, edits)
	-- Returns a copy of t, with edits applied.
	-- Uses string "nil" to represent nil values, else those don't work properly.
	local new = table.deepcopy(t)
	for k, v in pairs(edits) do
		if v == "nil" then v = nil end
		new[k] = v
	end
	return new
end

return Export