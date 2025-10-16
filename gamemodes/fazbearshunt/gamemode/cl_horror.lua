local lastSoundTime = 0
local soundCooldown = 10

local function fh_default_check_scarysound()
    local localPlayer = LocalPlayer()
	if !pills then return end
	
    if !IsValid(localPlayer) or pills.getMappedEnt(localPlayer) != nil then return end

    local eyePos = localPlayer:EyePos()
    local eyeAngles = localPlayer:EyeAngles()
    local forward = eyeAngles:Forward()

    local viewRadius = 125
	
	if !localPlayer:Alive() or localPlayer:Team() == TEAM_SPECTATOR then return end

    for _, ply in player.Iterator() do
        if ply ~= localPlayer and IsValid(ply) and ply:Alive() and ply:GetMoveType() != MOVETYPE_NOCLIP then
            if pills and pills.getMappedEnt and pills.getMappedEnt(ply) ~= nil then
				local ent = pills.getMappedEnt(ply)
				
				if IsValid(ent) then
					if ent.dontdraw or ent:GetMaterial() == "models/null" then return end
				end
				
                local plyPos = ply:EyePos()
				
				if ply:IsSprinting() and ply:GetVelocity():LengthSqr() >= ply:GetRunSpeed() then
					viewRadius = 1200
				end

                local toPly = (plyPos - eyePos)
                local distance = toPly:Length()

                if distance <= viewRadius then
                    local toPlyNormalized = toPly:GetNormalized()

                    local dotProduct = forward:Dot(toPlyNormalized)
                    local angle = math.acos(dotProduct) * (180 / math.pi)

                    local fov = 60

                    if angle <= fov then
                        local trace = util.TraceLine({
                            start = eyePos,
                            endpos = plyPos,
                            filter = {localPlayer,ply},
                            mask = MASK_VISIBLE
                        })

                        local canSee = false

                        if !trace.Hit then
                            canSee = true
                        end

                        if canSee then
                            local currentTime = CurTime()
							if lastSoundTime != 0 and currentTime - lastSoundTime < soundCooldown then
                                lastSoundTime = currentTime
							end
                            if currentTime - lastSoundTime >= soundCooldown then
                                surface.PlaySound("animatron_seen.wav")

                                lastSoundTime = currentTime
                            end

                            break
                        end
                    end
                end
            end
        end
    end
end

local mat_videoglitch = Material( "effects/shaders/merc_videoglitch" )

function render.DrawMercVideoGlitch(strength)
    render.UpdateScreenEffectTexture()
    mat_videoglitch:SetFloat("$c0_y", strength)
    render.SetMaterial(mat_videoglitch)
    render.DrawScreenQuad()
end

local function scaredNear()
    _G.fh_is_scared_lock = true

	local localPlayer = LocalPlayer()
	local eyePos = localPlayer:EyePos()
	local plyPos = targetPlayer:EyePos()
	
	sound.PlayFile("sound/fnaf2/gfreddy/target_scared_near.wav", "noplay", function(chan, errID, errStr)
		if IsValid(chan) then
			chan:SetPos(localPlayer:GetPos())
			chan:Play()
		end
	end)
	hook.Add("RenderScreenspaceEffects", "merc_videoglitch_hook", function()
		render.DrawMercVideoGlitch(0.5)
	end)
	local newAng = (plyPos - eyePos):Angle()
	localPlayer:SetEyeAngles(newAng)
	
	hook.Add("StartCommand", "fh_lock_view", function(ply, cmd)
		cmd:SetViewAngles(((targetPlayer:EyePos()) - ply:EyePos()):Angle())
	end)
	
	hook.Add("InputMouseApply", "fh_scared_no_mouse", function(cmd, x, y, ang)
		return true
	end)
	timer.Simple(0.5, function()
		hook.Remove("InputMouseApply", "fh_scared_no_mouse")
		hook.Remove("StartCommand", "fh_lock_view")
        _G.fh_is_scared_lock = false
		
		net.Start("cl_target_wgfreddy_scared")
		net.SendToServer()
	end)
end

local progressSoundChannel = nil
local progressStartTime = 0
local progressDuration = 2.0
local scareImmunityUntil = 0

local function stopScareProgress()
	if IsValid(progressSoundChannel) then
		progressSoundChannel:Stop()
	end
	progressSoundChannel = nil
	progressStartTime = 0
	
	scareImmunityUntil = CurTime() + 0.2
	
	hook.Remove("CreateMove", "fh_gfreddy_magnet_view")
end

local soundCooldown = 10
local function fh_gfreddy_check_scarysound()
	local localPlayer = LocalPlayer()
	
	if !localPlayer:GetNWBool("can_be_gf_scared", false) then return end
	if not pills or not IsValid(localPlayer) or pills.getMappedEnt(localPlayer) ~= nil then return end
	if not IsValid(targetPlayer) or targetPlayer == localPlayer then return end
	if not targetPlayer:Alive() or targetPlayer:GetMoveType() == MOVETYPE_NOCLIP then return end
	if localPlayer:Team() == TEAM_SPECTATOR or not localPlayer:Alive() then return end

	local eyePos = localPlayer:EyePos()
	local eyeAngles = localPlayer:EyeAngles()
	local forward = eyeAngles:Forward()

	if pills and pills.getMappedEnt and pills.getMappedEnt(targetPlayer) ~= nil then
		local ent = pills.getMappedEnt(targetPlayer)
		if ent.dontdraw or ent:GetMaterial() == "models/null" then 
			stopScareProgress()
			return 
		end

		local plyPos = (targetPlayer:EyePos() + targetPlayer:GetPos()) / 2
		local toPly = plyPos - eyePos
		local distance = toPly:Length()
		local toPlyNormalized = toPly:GetNormalized()
		local dotProduct = forward:Dot(toPlyNormalized)
		dotProduct = math.Clamp(dotProduct, -1, 1)
		local angle = math.deg(math.acos(dotProduct))
		local fov = 45

		local trace = util.TraceLine({
			start = eyePos,
			endpos = plyPos,
			filter = {localPlayer, targetPlayer, ent},
			mask = MASK_VISIBLE
		})

		local canSee = not trace.Hit and angle <= fov
		
		if CurTime() < scareImmunityUntil then return end

		if distance <= 200 and canSee then
			local currentTime = CurTime()
			if lastSoundTime ~= 0 and currentTime - lastSoundTime < soundCooldown then
				lastSoundTime = currentTime
			end
			if currentTime - lastSoundTime >= soundCooldown then
				scaredNear()
				lastSoundTime = currentTime
				
				scareImmunityUntil = CurTime() + 4
			end
			stopScareProgress()
			return
		end

		if distance > 200 and distance < 1000 and canSee then
			if not IsValid(progressSoundChannel) then
				sound.PlayFile("sound/fnaf2/gfreddy/scare_progress.wav", "noplay", function(chan)
					if IsValid(chan) then
						chan:SetPos(localPlayer:GetPos())
						chan:SetVolume(1)
						chan:Play()
						progressSoundChannel = chan
						progressStartTime = CurTime()
						
						scareImmunityUntil = CurTime() + 1
					end
				end)
				
				sound.PlayFile("sound/fnaf2/gfreddy/scare_start.wav", "noplay", function(chan, errID, errStr)
					if IsValid(chan) then
						chan:SetPos(localPlayer:GetPos())
						chan:Play()
					end
				end)

				hook.Add("CreateMove", "fh_gfreddy_magnet_view", function(cmd)
					if !IsValid(targetPlayer) then
						hook.Remove("CreateMove", "fh_gfreddy_magnet_view")
						return
					end
					local desiredAngle = (targetPlayer:EyePos() - localPlayer:EyePos()):Angle()
					local currentAngle = cmd:GetViewAngles()
					local diff = desiredAngle - currentAngle
					diff:Normalize()

					local magnetStrength = 0.05
					local newAng = currentAngle + Angle(diff.p * magnetStrength, diff.y * magnetStrength, 0)
					cmd:SetViewAngles(newAng)
				end)
	
				scareImmunityUntil = CurTime() + 0.1
			end

			if IsValid(progressSoundChannel) and CurTime() - progressStartTime >= progressDuration then
				stopScareProgress()
				
				sound.PlayFile("sound/fnaf2/gfreddy/target_scared_distant.wav", "noplay", function(chan, errID, errStr)
					if IsValid(chan) then
						chan:SetPos(localPlayer:GetPos())
						chan:Play()
					end
				end)
				
				net.Start("cl_target_wgfreddy_scared")
				net.SendToServer()
				
				scareImmunityUntil = CurTime() + 1
			end
		else
			stopScareProgress()
		end
	end
end

hook.Add("PostCleanupMap", "fh_cleanup_horror", function()
	hook.Remove("InputMouseApply", "fh_scared_no_mouse")
	hook.Remove("StartCommand", "fh_lock_view")
	hook.Remove("CreateMove", "fh_gfreddy_magnet_view")
end)

net.Receive("fh_net_scarysound", function()
	local can = net.ReadBool()
	toggleScarySound(can)
end)

net.Receive("fh_net_wgfreddy_scarysound", function()
	local can = net.ReadBool()
	local ply = net.ReadPlayer()
	if can then
		targetPlayer = ply
		hook.Add("Think", "fh_scarysound", fh_gfreddy_check_scarysound)
		return
	end
	hook.Remove("Think", "fh_scarysound")
	targetPlayer = nil
end)

function toggleScarySound(can)
	if can then
		stopScareProgress()
		hook.Add("Think", "fh_scarysound", fh_default_check_scarysound)
		return
	end
	hook.Remove("Think", "fh_scarysound")
	targetPlayer = nil
end