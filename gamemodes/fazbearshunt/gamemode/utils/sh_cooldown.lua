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

if SERVER then
	function cooldown.Set(ply, name, duration)
		if not IsValid(ply) then return end

		our_cooldowns[ply] = our_cooldowns[ply] or {}
		our_cooldowns[ply][name] = CurTime() + duration
	end

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