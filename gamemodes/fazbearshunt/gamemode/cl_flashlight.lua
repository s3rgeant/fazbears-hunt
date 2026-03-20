local flashMode = "off"
local Flash = nil

hook.Add( "PreDrawTranslucentRenderables", "FixEyePos", function()
	EyePos()
end )

local function CreateFlashlight(params)
    local lt = ProjectedTexture()
    lt:SetTexture(params.mat)
    lt:SetFOV(params.fov)
    lt:SetNearZ(params.nearz)
    lt:SetFarZ(params.farz)
    lt:SetBrightness(params.brightness)
    lt:SetEnableShadows(params.shadows)
    lt:SetColor(params.color)
    lt:Update()
    return lt
end

local function UpdateFlashPos()
    if not IsValid(Flash) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local pos = EyePos()
    local ang = RenderAngles()

    pos = pos + ang:Forward() * 2

    Flash:SetPos(pos)
    Flash:SetAngles(ang)
    Flash:Update()
end

local function ApplyFlashMode()
    if IsValid(Flash) then
        Flash:Remove()
        Flash = nil
    end

    if flashMode == "off" then
        hook.Remove("Think", "FH_UpdateFlash")
        hook.Remove("RenderScreenspaceEffects", "FH_NightVisionCC")
        return
    end

    local cfg = {}
    if flashMode == "normal" then
        cfg = {
            mat = "effects/flashlight001",
            fov = 60,
            nearz = 4,
            farz = 1000,
            brightness = 1,
            shadows = false,
            color = Color(255,255,255)
        }
    elseif flashMode == "nv" then
        cfg = {
            mat = "effects/flashlight001_infected",
            fov = 75,
            nearz = 1,
            farz = 1200,
            brightness = 3,
            shadows = false,
            color = Color(200,255,200)
        }
    end

    Flash = CreateFlashlight(cfg)

    hook.Add("Think", "FH_UpdateFlash", UpdateFlashPos)

    if flashMode == "nv" then
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
    else
        hook.Remove("RenderScreenspaceEffects", "FH_NightVisionCC")
    end
end

local function ToggleFlashMode()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    surface.PlaySound("items/flashlight1.wav")

    if flashMode == "off" then
        if ply:IsAnimatronic() or ply:Team() == TEAM_SPECTATOR then
            flashMode = "nv"
        else
			return
        end
    elseif flashMode == "normal" then
        flashMode = "off"
    elseif flashMode == "nv" then
        flashMode = "off"
    end

    ApplyFlashMode()
end

hook.Add("PlayerBindPress", "fh_flash_nv_normal", function(ply, bind, pressed)
    local ply = LocalPlayer()
    if pressed and string.find(bind, "impulse 100") and (ply:IsAnimatronic() or ply:Team() == TEAM_SPECTATOR) then
        ToggleFlashMode()
		return true
    end
end)

gameevent.Listen("player_spawn")
hook.Add("player_spawn", "fh_player_spawn_flashlight", function(data)
    local ply = Player(data.userid)
    if IsValid(ply) and ply == LocalPlayer() then
        if flashMode ~= "off" then
            ToggleFlashMode()
        end
    end
end)

hook.Add("PostCleanupMap", "fh_cleanup_flashlight", function()
    if flashMode ~= "off" then
        ToggleFlashMode()
    end
end)

hook.Add("PillApply", "fh_flashlight_pillapply", function(ply)
	local myself = LocalPlayer()
	if IsValid(myself) and ply == myself then
		if flashMode ~= "off" then ToggleFlashMode() end
	end
end)

hook.Add("PillRestore", "fh_flashlight_pillrestore", function(ply)
	local myself = LocalPlayer()
	if IsValid(myself) and ply == myself then
		if flashMode ~= "off" then ToggleFlashMode() end
	end
end)

net.Receive("nv_off", function()
    if flashMode ~= "off" then
        ToggleFlashMode()
    end
end)