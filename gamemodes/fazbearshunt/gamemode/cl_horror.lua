local lastSoundTime = 0
local soundCooldown = 10

local function CheckPlayersAndPlaySound()
    local localPlayer = LocalPlayer()
	if !pk_pills then return end
	
    if !IsValid(localPlayer) or pk_pills.getMappedEnt(localPlayer) != nil then return end

    local eyePos = localPlayer:EyePos()
    local eyeAngles = localPlayer:EyeAngles()
    local forward = eyeAngles:Forward()

    local viewRadius = 1200

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= localPlayer and IsValid(ply) and ply:Alive() and localPlayer:Alive() and ply:GetMoveType() != MOVETYPE_NOCLIP then
            if pk_pills and pk_pills.getMappedEnt and pk_pills.getMappedEnt(ply) ~= nil then
                local plyPos = ply:EyePos()

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

net.Receive("fh_net_scarysound", function()
	local can = net.ReadBool()
	if can then
		hook.Add("Think", "fh_scarysound", CheckPlayersAndPlaySound)
		return
	end
	hook.Remove("Think", "fh_scarysound")
end)

function toggleScarySound(can)
	if can then
		hook.Add("Think", "fh_scarysound", CheckPlayersAndPlaySound)
		return
	end
	hook.Remove("Think", "fh_scarysound")
end