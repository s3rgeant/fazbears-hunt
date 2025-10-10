local nightVision = nightVision or false
local normalFlash = normalFlash or false

local function ValidPlayer()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:Alive()
end

local function UpdateFlashPos(light)
    if not IsValid(light) or not ValidPlayer() then return end
    local ang = RenderAngles()
    local pos = LocalPlayer():EyePos() + ang:Forward() * 1
    light:SetPos(pos)
    light:SetAngles(ang)
    light:Update()
end

local function CreateProjTexture(mat, fov, nearz, farz, bright, shadows)
    local lt = ProjectedTexture()
    lt:SetTexture(mat or "effects/flashlight001")
    lt:SetFOV(fov or 60)
    lt:SetNearZ(nearz or 4)
    lt:SetFarZ(farz or 1000)
    lt:SetBrightness(bright or 1)
    lt:SetEnableShadows(not not shadows)
    lt:SetColor(Color(255,255,255))
    lt:Update()
    return lt
end

local function ToggleNightVision()
    if not ValidPlayer() then return end
    surface.PlaySound("items/flashlight1.wav")
    nightVision = not nightVision

    -- выключаем нормальный если включаем NV, и наоборот
    if nightVision and normalFlash then
        normalFlash = false
        if IsValid(LocalPlayer().NormalFlash) then
            LocalPlayer().NormalFlash:Remove()
            LocalPlayer().NormalFlash = nil
        end
        hook.Remove("Think", "UpdateNormalFlash")
    end

    if nightVision then
        hook.Add("RenderScreenspaceEffects", "FH_NightVisionCC", function()
            DrawColorModify({
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0.05,
                ["$pp_colour_addb"] = 0.05,
                ["$pp_colour_brightness"] = 0,
                ["$pp_colour_contrast"] = 1,
                ["$pp_colour_colour"] = 0.65,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            })
        end)

        if not IsValid(LocalPlayer().HiddenFlash) then
            LocalPlayer().HiddenFlash = CreateProjTexture("effects/flashlight001_infected", 75, 1, 1200, 3, false)
        end

        hook.Add("Think", "UpdateNVFlash", function()
            UpdateFlashPos(LocalPlayer().HiddenFlash)
        end)
    else
        hook.Remove("RenderScreenspaceEffects", "FH_NightVisionCC")
        hook.Remove("Think", "UpdateNVFlash")
        if IsValid(LocalPlayer().HiddenFlash) then
            LocalPlayer().HiddenFlash:Remove()
            LocalPlayer().HiddenFlash = nil
        end
    end
end

local function ToggleNormalFlashlight()
    if not ValidPlayer() then return end
    surface.PlaySound("items/flashlight1.wav")
    normalFlash = not normalFlash

    if normalFlash and nightVision then
        nightVision = false
        hook.Remove("RenderScreenspaceEffects", "FH_NightVisionCC")
        if IsValid(LocalPlayer().HiddenFlash) then
            LocalPlayer().HiddenFlash:Remove()
            LocalPlayer().HiddenFlash = nil
        end
        hook.Remove("Think", "UpdateNVFlash")
    end

    if normalFlash then
        if not IsValid(LocalPlayer().NormalFlash) then
            LocalPlayer().NormalFlash = CreateProjTexture("effects/flashlight001", 60, 4, 1000, 1, false)
        end

        hook.Add("Think", "UpdateNormalFlash", function()
            UpdateFlashPos(LocalPlayer().NormalFlash)
        end)
    else
        hook.Remove("Think", "UpdateNormalFlash")
        if IsValid(LocalPlayer().NormalFlash) then
            LocalPlayer().NormalFlash:Remove()
            LocalPlayer().NormalFlash = nil
        end
    end
end

gameevent.Listen( "player_spawn" )
hook.Add( "player_spawn", "fh_player_spawn_flashlight", function( data )
	local ply = Player(data.userid)
	local myself = LocalPlayer()
	
	if IsValid(ply) and IsValid(myself) and ply == myself then
		if nightVision then ToggleNightVision() end
		if normalFlash then ToggleNormalFlashlight() end
	end
end )

hook.Add("PillApply", "fh_flashlight_pillapply", function(ply)
	local myself = LocalPlayer()
	if IsValid(myself) and ply == myself then
		if nightVision then ToggleNightVision() end
		if normalFlash then ToggleNormalFlashlight() end
	end
end)

hook.Add("PlayerBindPress", "fh_flash_nv_normal", function(ply, bind, pressed)
    if not pressed then return end
    if string.find(bind, "impulse 100") then
        if ply:IsAnimatronic() or ply:Team() == TEAM_SPECTATOR then
            ToggleNightVision()
        else
            ToggleNormalFlashlight()
        end
        return true
    end
end)