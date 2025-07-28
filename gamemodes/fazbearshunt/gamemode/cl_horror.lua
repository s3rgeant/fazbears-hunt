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

    for _, ply in player.Iterator() do
        if ply ~= localPlayer and IsValid(ply) and ply:Alive() and localPlayer:Alive() and localPlayer:Team() != TEAM_SPECTATOR 
		and ply:GetMoveType() != MOVETYPE_NOCLIP then
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
                            mask = MASK_VISIBLE_AND_NPCS
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

local targetPlayer
local function fh_gfreddy_check_scarysound()
    local localPlayer = LocalPlayer()
	if not pills then return end
	
    if not IsValid(localPlayer) or pills.getMappedEnt(localPlayer) ~= nil then return end
	if not IsValid(targetPlayer) or targetPlayer == localPlayer then return end
	if not targetPlayer:Alive() or targetPlayer:GetMoveType() == MOVETYPE_NOCLIP then return end
	if localPlayer:Team() == TEAM_SPECTATOR or not localPlayer:Alive() then return end

    local eyePos = localPlayer:EyePos()
    local eyeAngles = localPlayer:EyeAngles()
    local forward = eyeAngles:Forward()
    local viewRadius = 200

	if pills and pills.getMappedEnt and pills.getMappedEnt(targetPlayer) ~= nil then
		local ent = pills.getMappedEnt(targetPlayer)
		
		if ent.dontdraw or ent:GetMaterial() == "models/null" then return end

		local plyPos = targetPlayer:EyePos()

		local toPly = (plyPos - eyePos)
		local distance = toPly:Length()

		if distance <= viewRadius then
			local toPlyNormalized = toPly:GetNormalized()
			local dotProduct = forward:Dot(toPlyNormalized)
			local angle = math.acos(dotProduct) * (180 / math.pi)
			local fov = 45

			if angle <= fov then
				local trace = util.TraceLine({
					start = eyePos,
					endpos = plyPos,
					filter = {localPlayer, targetPlayer},
					mask = MASK_VISIBLE_AND_NPCS
				})

				if not trace.Hit then
					local currentTime = CurTime()
					
					if lastSoundTime ~= 0 and currentTime - lastSoundTime < soundCooldown then
						lastSoundTime = currentTime
					end

					if currentTime - lastSoundTime >= soundCooldown then
						sound.PlayFile("sound/fnaf2/gfreddy/target_scared_near.wav", "noplay", function(chan, errID, errStr)
							if IsValid(chan) then
								chan:SetPos(LocalPlayer():GetPos())
								chan:Play()
							end
						end)
						hook.Add("RenderScreenspaceEffects", "merc_videoglitch_hook", function()
							render.DrawMercVideoGlitch(0.5)
						end)
						local newAng = (plyPos - eyePos):Angle()
						localPlayer:SetEyeAngles(newAng)
						
                        hook.Add("StartCommand", "fh_lock_view", function(ply, cmd)
                            if ply == localPlayer then
                                cmd:SetViewAngles((targetPlayer:EyePos() - localPlayer:EyePos() ):Angle() )
                            end
                        end)
						
						hook.Add("InputMouseApply", "fh_scared_no_mouse", function(cmd, x, y, ang)
							return true
						end)
						timer.Simple(0.5, function()
							hook.Remove("InputMouseApply", "fh_scared_no_mouse")
                            hook.Remove("StartCommand", "fh_lock_view")
							
							net.Start("cl_target_wgfreddy_scared")
							net.SendToServer()
						end)
						
						timer.Simple(5, function()
							hook.Add("RenderScreenspaceEffects", "merc_videoglitch_hook", function()
								render.DrawMercVideoGlitch(0.2)
							end)
						end)
						lastSoundTime = currentTime
					end
				end
			end
		end
	end
end

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
		hook.Add("Think", "fh_scarysound", fh_default_check_scarysound)
		return
	end
	hook.Remove("Think", "fh_scarysound")
end