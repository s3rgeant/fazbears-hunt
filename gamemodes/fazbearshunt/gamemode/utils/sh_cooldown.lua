cooldown = cooldown or {}

if SERVER then
	util.AddNetworkString("fh_cooldown_receive")
end

local our_cooldowns = {}

function cooldown.Get(ply, name)
	if !ply and CLIENT then ply = LocalPlayer() end
	if not IsValid(ply) then return 0 end

	local ply_cooldowns = our_cooldowns[ply]
	if not ply_cooldowns then return 0 end

	local cd = ply_cooldowns[name]
	if not cd or cd < CurTime() then return 0 end

	return cd - CurTime()
end

function cooldown.Exists(ply, name)
	if !ply and CLIENT then ply = LocalPlayer() end
	if not IsValid(ply) then return false end

	local ply_cooldowns = our_cooldowns[ply]
	if not ply_cooldowns then return false end

	local cd = ply_cooldowns[name]
	if not cd or cd < CurTime() then return false end

	return true
end

function cooldown.Set(ply, name, duration)
	if not IsValid(ply) then return end

	our_cooldowns[ply] = our_cooldowns[ply] or {}
	our_cooldowns[ply][name] = CurTime() + duration
		
	hook.Run("FH_CooldownReceive", name, duration)
end

if SERVER then

	function cooldown.Send(ply, name)
		if !IsValid(ply) then return end
		local cd = cooldown.Get(ply, name)
		
		if cd > 0 then
			net.Start("fh_cooldown_receive")
			net.WriteString(name)
			net.WriteFloat(cd)
			net.Send(ply)
		end
	end
	function cooldown.SetSend(ply, name, duration)
		if not IsValid(ply) then return end

		our_cooldowns[ply] = our_cooldowns[ply] or {}
		our_cooldowns[ply][name] = CurTime() + duration
		
		local cd = cooldown.Get(ply, name)
		
		if cd > 0 then
			net.Start("fh_cooldown_receive")
			net.WriteString(name)
			net.WriteFloat(cd)
			net.Send(ply)
		end
	end
	
	hook.Add( "PlayerDisconnected", "fh_clear_cds", function(ply)
		our_cooldowns[ply] = nil
	end)
	
	hook.Add( "PostCleanupMap", "fh_clear_cds", function() -- если кому то от этого плохо то скажите мне
		our_cooldowns = {}
	end)
end

if CLIENT then
	net.Receive("fh_cooldown_receive", function()
		local name = net.ReadString()
		local duration = net.ReadFloat()
		local ply = LocalPlayer()
		
		if not IsValid(ply) then return end
		
		our_cooldowns[ply] = our_cooldowns[ply] or {}
		our_cooldowns[ply][name] = CurTime() + duration
		
		hook.Run("FH_CooldownReceive", name, duration)
	end)
end