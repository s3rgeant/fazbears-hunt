local playerSounds = playerSounds or {}
	
hook.Add("PostCleanupMap", "fh_sounds_cleanup", function()
    for name, snd in pairs(playerSounds) do
        if snd and snd.Stop then
            snd:Stop()
        end
    end
    table.Empty(playerSounds)
end)

net.Receive("fh_adv_sound_play", function()
	local ply = LocalPlayer()
	local snd = net.ReadString()
	local name = net.ReadString()
	
	if string.len(name) <= 3 then name = snd end
	
	if !IsValid(ply) then return end
	
    if playerSounds[name] then
        playerSounds[name]:Stop()
        playerSounds[name] = nil
    end
	
    local sound = CreateSound(ply, snd)
    sound:SetSoundLevel(0)
	sound:SetDSP(0)
    sound:Play()
	
    playerSounds[name] = sound
end)

net.Receive("fh_ent_sound_play", function()
	local ent = net.ReadPlayer()
	local snd = net.ReadString()
	
	if !IsValid(ent) then return end
	
    if playerSounds[snd] then
        playerSounds[snd]:Stop()
        playerSounds[snd] = nil
    end
	
    local sound = CreateSound(ent, ")" .. snd)
    sound:Play()

    playerSounds[snd] = sound
end)

net.Receive("fh_sound_stop", function()
	local snd = net.ReadString()
    if playerSounds[snd] then
        playerSounds[snd]:Stop()
        playerSounds[snd] = nil
    end
end)

net.Receive("fh_play_sound", function()
	local sound = net.ReadString()
	surface.PlaySound(sound)
end)

net.Receive("fh_pos_sound_play", function()
	local str = net.ReadString()
	local pos = net.ReadVector()
	sound.PlayFile("sound/"..str, "noplay 3d", function(chan, errID, errStr)
		if IsValid(chan) then
			chan:SetPos(pos)
			chan:Play()
		end
	end)
end)

net.Receive("fh_ui_sound_play", function()
	local str = net.ReadString()
	sound.PlayFile("sound/"..str, "noplay", function(chan, errID, errStr)
		if IsValid(chan) then
			chan:SetPos(LocalPlayer():GetPos())
			chan:Play()
		end
	end)
end)

net.Receive("fh_3d_sound_play", function()
	local ply = net.ReadPlayer()
	local str = net.ReadString()
	sound.PlayFile("sound/"..str, "noplay noblock", function(chan, errID, errStr)
		if IsValid(chan) then
			if IsValid(ply) then
				chan:SetPos(ply:GetPos())
			end
			chan:EnableLooping(true)
			chan:Set3DEnabled(true)
			chan:Play()
		end
	end)
end)

-- ДОДЕЛАТЬ РАСПИЗДЯЙ!!
hook.Add("EntityEmitSound", "fh_silent_anims", function(data)
	if conVars.fh_less_steps:GetBool() then
		local ply = LocalPlayer()
		if !IsValid(ply) then return end
		
		if IsValid(data.Entity) and data.Entity:GetClass() == "pill_costume" then
			local tr = util.QuickTrace( ply:EyePos(), data.Entity:WorldSpaceCenter() - ply:EyePos(), {data.Entity, ply} )
		
			if tr.Hit then
				data.Volume = conVars.fh_less_steps_volume:GetFloat()
				return true
			end
		end
	end
end)