local nightVisionEnabled = false
local normalFlashlightEnabled = false

local function UpdateFlashlightPosition(light)
    if not IsValid(light) then return end
    local ang = RenderAngles()
    local pos = EyePos() + ang:Forward() * 1
    light:SetPos(pos)
    light:SetAngles(ang)
    light:Update()
end

function ToggleNightVision()
    surface.PlaySound('items/flashlight1.wav')
    nightVisionEnabled = not nightVisionEnabled
	
	if normalFlashlightEnabled then ToggleNormalFlashlight() end

    if nightVisionEnabled then
        hook.Add("RenderScreenspaceEffects", "NightVisionEffect", function()
            local colorCorrection = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0.05,
                ["$pp_colour_addb"] = 0.05,
                ["$pp_colour_brightness"] = 0,
                ["$pp_colour_contrast"] = 0.8,
                ["$pp_colour_colour"] = 0.65,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(colorCorrection)
        end)

        if not LocalPlayer().HiddenFlashlight then
            local light = ProjectedTexture()
            light:SetTexture("effects/flashlight001_infected")
            light:SetFarZ(912)
            light:SetNearZ(1)
            light:SetFOV(75)
            light:SetBrightness(3)
            light:SetEnableShadows(false)
            light:SetColor(Color(255, 255, 255))
            light:Update()
            LocalPlayer().HiddenFlashlight = light
        end
        
        hook.Add("Think", "UpdateNightVisionFlashlight", function()
            UpdateFlashlightPosition(LocalPlayer().HiddenFlashlight)
        end)
    else
        hook.Remove("RenderScreenspaceEffects", "NightVisionEffect")
        hook.Remove("Think", "UpdateNightVisionFlashlight")
        if LocalPlayer().HiddenFlashlight then
            LocalPlayer().HiddenFlashlight:Remove()
            LocalPlayer().HiddenFlashlight = nil
        end
    end
end

-- Новый: обычный фонарик для остальных игроков
function ToggleNormalFlashlight()
    surface.PlaySound('items/flashlight1.wav')
    normalFlashlightEnabled = not normalFlashlightEnabled
	
	if nightVisionEnabled then ToggleNightVision() end

    if normalFlashlightEnabled then
        if not LocalPlayer().NormalFlashlight then
            local light = ProjectedTexture()
            light:SetTexture("effects/flashlight001")
            light:SetFarZ(750)
            light:SetNearZ(4)
            light:SetFOV(60)
            light:SetBrightness(1)
            light:SetEnableShadows(true)
            light:SetColor(Color(255, 255, 255))
            light:Update()
            LocalPlayer().NormalFlashlight = light
        end

        hook.Add("Think", "UpdateNormalFlashlight", function()
            UpdateFlashlightPosition(LocalPlayer().NormalFlashlight)
        end)
    else
        hook.Remove("Think", "UpdateNormalFlashlight")
        if LocalPlayer().NormalFlashlight then
            LocalPlayer().NormalFlashlight:Remove()
            LocalPlayer().NormalFlashlight = nil
        end
    end
end

hook.Add("PlayerBindPress", "fh_flash_nv_normal", function(ply, bind, pressed)
    if string.find(bind, "impulse 100") and pressed then
        if ply:IsAnimatronic() or ply:Team() == TEAM_SPECTATOR then
            ToggleNightVision()
        else
            ToggleNormalFlashlight()
        end
        return true
    end
end)

net.Receive("nv_off", function()
    if nightVisionEnabled then
        ToggleNightVision()
    end
end)

concommand.Add("toggle_nightvision", function()
    if LocalPlayer():IsAdmin() then
        ToggleNightVision()
    end
end)