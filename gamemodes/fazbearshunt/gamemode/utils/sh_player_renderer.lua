player_renderer = player_renderer or {}

local noDrawies = {}
local onlyDrawies = {}

function player_renderer.NoDraw(ply)

	if !IsValid(ply) then return end
	
	noDrawies[ply] = true

	ply:SetNoDraw(true)
	ply:DrawShadow(false)

	for _, wep in ipairs(ply:GetWeapons()) do
		if IsValid(wep) then
			wep:SetNoDraw(true)
			wep:DrawShadow(false)
			wep:SetRenderMode(RENDERMODE_NONE)
		end
	end
end

function player_renderer.Draw(ply)

	if !IsValid(ply) then return end
	
	noDrawies[ply] = nil

	ply:SetNoDraw(false)
	ply:DrawShadow(true)

	for _, wep in ipairs(ply:GetWeapons()) do
		if IsValid(wep) then
			wep:SetNoDraw(false)
			wep:DrawShadow(true)
			wep:SetRenderMode(RENDERMODE_NORMAL)
		end
	end
end

function player_renderer.OnlyDraw(ply)
	if !IsValid(ply) then return end
	local myself = LocalPlayer()
	noDrawies[ply] = nil
	onlyDrawies[ply] = true
	
	for _, ply in player.Iterator() do
		if !noDrawies[ply] and IsValid(myself) and ply ~= myself then
			player_renderer.NoDraw(ply)
		end
	end
end

function player_renderer.ClearOnlyDraw()
	table.Empty(onlyDrawies)
	
	for _, ply in player.Iterator() do
		if !noDrawies[ply] and IsValid(myself) and ply ~= myself then
			player_renderer.Draw(ply)
		end
	end
end

hook.Add("PrePlayerDraw", "fh_renderer_nodrawies", function(ply)
	if noDrawies[ply] or !table.IsEmpty(onlyDrawies) and !onlyDrawies[ply] then
		ply:DestroyShadow()
		
		for _, wep in ipairs(ply:GetWeapons()) do
			if IsValid(wep) then
				wep:DestroyShadow()
			end
		end
		return true
	end
end)

hook.Add("NotifyShouldTransmit", "fh_renderer_shadows", function(entity, trans)
	if entity:IsPlayer() and trans and ( noDrawies[entity] or !table.IsEmpty(onlyDrawies) and !onlyDrawies[entity]) then
		entity:DrawShadow(false)
		
		for _, wep in ipairs(entity:GetWeapons()) do
			if IsValid(wep) then
				wep:DrawShadow(false)
			end
		end
	end
end)