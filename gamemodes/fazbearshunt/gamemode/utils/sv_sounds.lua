
local ENTITY = FindMetaTable("Entity")
local ENTITY_EmitSound = FindMetaTable("Entity").EmitSound

function ENTITY:EmitSound(soundName, soundLevel, pitchPercent, volume, channel, soundFlags, dsp, filter)
	soundLevel = soundLevel or 75
	pitchPercent = pitchPercent or 100
	volume = volume or 1
	channel = channel or (self:IsWeapon() and CHAN_WEAPON or CHAN_AUTO)
	soundFlags = soundFlags or 0
	dsp = dsp or 1
	filter = filter or nil
	
	if not table.IsEmpty(wgfreddy_targets) then
		if not filter then filter = RecipientFilter() end
		
		if wgfreddy_targets[self] then
			filter:RemoveAllPlayers()
			filter:AddPlayer(wgfreddy_targets[self])
			filter:AddPlayer(self)
		elseif outworld_victims[self] then
			filter:RemoveAllPlayers()
			filter:AddPlayer(outworld_victims[self])
			filter:AddPlayer(self)
		else
			filter:AddPAS(self:GetPos())
			
			for freddy, victim in pairs(wgfreddy_targets) do
				if self == freddy or self == victim then continue end
				if IsValid(freddy) then filter:RemovePlayer(freddy) end
				if IsValid(victim) then filter:RemovePlayer(victim) end
			end
		end
	end
	
	ENTITY_EmitSound(self, soundName, soundLevel, pitchPercent, volume, channel, soundFlags, dsp, filter)
end