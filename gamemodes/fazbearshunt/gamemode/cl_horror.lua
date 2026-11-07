local myself

local lastSoundTime = 0
local soundCooldown = 10

local function fh_default_check_scarysound()
    myself = myself or LocalPlayer()
	
    if !myself:IsValid() or myself:GetPillCostume():IsValid() then return end
	
	if !myself:Alive() or myself:Team() == TEAM_SPECTATOR then return end

    local eyePos = myself:EyePos()
    local eyeAngles = myself:EyeAngles()
    local forward = eyeAngles:Forward()

    local viewRadius = 250

    for _, ply in player.Iterator() do
        if ply ~= myself and ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
            if IsValid(ply:GetPillCostume()) then
				local ent = ply:GetPillCostume()
				
				if IsValid(ent) then
					if !ent.IsDrawn or ent:GetMaterial() == "models/null" then return end
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
							filter = {ply, myself},
                            mask = MASK_BLOCKLOS_AND_NPCS,
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

local goldunfreda = false
local mat_videoglitch = Material( "effects/shaders/merc_videoglitch" )

function render.DrawMercVideoGlitch(strength)
    render.UpdateScreenEffectTexture()
    mat_videoglitch:SetFloat("$c0_y", strength)
    render.SetMaterial(mat_videoglitch)
    render.DrawScreenQuad()
end

local magnetStrength = 0.1

local function scaredNear()
    _G.fh_is_scared_lock = true
	
	myself = myself or LocalPlayer()
	local targetPlayer = myself:GetNWEntity("_WGoldenFreddy")

	local eyePos = myself:EyePos()
	local plyPos = targetPlayer:EyePos()
	
	sound.PlayFile("sound/fnaf2/gfreddy/target_scared_near.wav", "noplay", function(chan, errID, errStr)
		if IsValid(chan) then
			chan:SetPos(myself:GetPos())
			chan:Play()
		end
	end)
	hook.Add("RenderScreenspaceEffects", "merc_videoglitch_hook", function()
		render.DrawMercVideoGlitch(0.5)
	end)
	local newAng = (plyPos - eyePos):Angle()
	myself:SetEyeAngles(newAng)
	
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
		magnetStrength = 0.1
		
		net.Start("cl_target_wgfreddy_scared")
		net.SendToServer()
	end)
end

local progressSoundChannel = nil
local progressStartTime = 0
local progressDuration = 2.0
local scareImmunityUntil = 0

local function stopScareProgress()
	if not IsValid(progressSoundChannel) then return end
	
	progressSoundChannel:Stop()
	progressSoundChannel = nil
	progressStartTime = 0
	
	magnetStrength = magnetStrength + 0.025
	
	hook.Remove("CreateMove", "fh_gfreddy_magnet_view")
end

local function fh_gfreddy_check_scarysound()
	myself = myself or LocalPlayer()
	
	local targetPlayer = myself:GetNWEntity("_WGoldenFreddy")
	
	if !IsValid(targetPlayer) or targetPlayer == myself then return end
	
	local ent = targetPlayer:GetPill()
	
	if !IsValid(ent) then return end
	
	if !myself:GetNWBool("can_be_gf_scared", true) then return end
	if not IsValid(myself) or not targetPlayer:Alive() or not myself:Alive() then return end

	if ent:GetMaterial() == "models/null" then 
		stopScareProgress()
		return 
	end

	local eyePos = myself:EyePos()
	local eyeAngles = myself:EyeAngles()
	if vrmod and vrmod.IsPlayerInVR(myself) then 
		eyePos = vrmod.GetHMDPos( myself ) 
		eyeAngles = vrmod.GetHMDAng( myself ) 
	end
	local forward = eyeAngles:Forward()

	local targetPos = targetPlayer:GetPos()
	local mins, maxs = targetPlayer:OBBMins(), targetPlayer:OBBMaxs()

	local bottomPos = targetPlayer:LocalToWorld(Vector(0, 0, mins.z + 5))
	local midPos = targetPlayer:LocalToWorld(Vector(0, 0, (mins.z + maxs.z) * 0.5))
	local eyeTargetPos = targetPlayer:EyePos()

	local function CanSeeTargetPoint(pos)
		local toPly = pos - eyePos
		local distance = toPly:Length()
		local toPlyNormalized = toPly:GetNormalized()
		local dotProduct = forward:Dot(toPlyNormalized)
		dotProduct = math.Clamp(dotProduct, -1, 1)
		local angle = math.deg(math.acos(dotProduct))
		local fov = 45

		local trace = util.TraceLine({
			start = eyePos,
			endpos = pos,
			filter = {myself, targetPlayer, ent},
			mask = MASK_BLOCKLOS_AND_NPCS
		})

		return (not trace.Hit) and (angle <= fov), distance
	end

	local canSee, distance

	canSee, distance = CanSeeTargetPoint(bottomPos)
	if not canSee then
		canSee, distance = CanSeeTargetPoint(midPos)
	end
	if not canSee then
		canSee, distance = CanSeeTargetPoint(eyeTargetPos)
	end

	if CurTime() < scareImmunityUntil then return end

	if canSee and distance <= 200 then
		scaredNear()
		scareImmunityUntil = CurTime() + 4
		stopScareProgress()
		return
	end

	if distance > 200 and distance < 1100 and canSee then
		if not IsValid(progressSoundChannel) then
			sound.PlayFile("sound/fnaf2/gfreddy/scare_progress.wav", "noplay", function(chan)
				if IsValid(chan) then
					chan:SetPos(myself:GetPos())
					chan:SetVolume(1)
					chan:Play()
					progressSoundChannel = chan
					progressStartTime = CurTime()
				end
			end)
			
			sound.PlayFile("sound/fnaf2/gfreddy/scare_start.wav", "noplay", function(chan, errID, errStr)
				if IsValid(chan) then
					chan:SetPos(myself:GetPos())
					chan:Play()
				end
			end)

			hook.Add("CreateMove", "fh_gfreddy_magnet_view", function(cmd)
				if not IsValid( myself:GetNWEntity("_WGoldenFreddy") ) then
					hook.Remove("CreateMove", "fh_gfreddy_magnet_view")
					return
				end
				local desiredAngle = (targetPlayer:EyePos() - myself:EyePos()):Angle()
				local currentAngle = cmd:GetViewAngles()
				local diff = desiredAngle - currentAngle
				diff:Normalize()

				local newAng = currentAngle + Angle(diff.p * magnetStrength, diff.y * magnetStrength, 0)
				cmd:SetViewAngles(newAng)
			end)
					
			scareImmunityUntil = CurTime() + 1
		end

		if IsValid(progressSoundChannel) and CurTime() - progressStartTime >= progressDuration then
			stopScareProgress()
			
			sound.PlayFile("sound/fnaf2/gfreddy/target_scared_distant.wav", "noplay", function(chan, errID, errStr)
				if IsValid(chan) then
					chan:SetPos(myself:GetPos())
					chan:Play()
				end
			end)
			
			net.Start("cl_target_wgfreddy_scared")
			net.SendToServer()
			
			magnetStrength = 0.1
			
			scareImmunityUntil = CurTime() + 8
		end
	else
		stopScareProgress()
	
		scareImmunityUntil = CurTime() + 0.15
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
	if can then
		goldunfreda = true
		hook.Add("Think", "fh_scarysound", fh_gfreddy_check_scarysound)
		return
	end
	goldunfreda = false
	hook.Remove("Think", "fh_scarysound")
end)

function toggleScarySound(can)
	if can then
		stopScareProgress()
		hook.Add("Think", "fh_scarysound", fh_default_check_scarysound)
		return
	end
	hook.Remove("Think", "fh_scarysound")
end

hook.Add('fh_poststartgame', 'enable_scary_sound_fh', function()
	if !goldunfreda then
		toggleScarySound(true)
	end
end)