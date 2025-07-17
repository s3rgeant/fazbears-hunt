local playerSounds = playerSounds or {}

net.Receive("fh_adv_sound_play", function()
	local ply = LocalPlayer()
	local snd = net.ReadString()
	
	if !IsValid(ply) then return end
	
    if playerSounds[snd] then
        playerSounds[snd]:Stop()
        playerSounds[snd] = nil
    end
	
    local sound = CreateSound(ply, snd)
    sound:SetSoundLevel(0)
	sound:SetDSP(0)
    sound:Play()
	
    playerSounds[snd] = sound
end)

net.Receive("fh_ent_sound_play", function()
	local ent = net.ReadPlayer()
	local snd = net.ReadString()
	
	if !IsValid(ent) then return end
	
    if playerSounds[snd] then
        playerSounds[snd]:Stop()
        playerSounds[snd] = nil
    end
	
    local sound = CreateSound(ent, snd)
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