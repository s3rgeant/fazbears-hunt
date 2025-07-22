local nightVisionEnabled = false

function UpdateFlashlightPosition()
    if !nightVisionEnabled or !IsValid(LocalPlayer().HiddenFlashlight) then return end
    
    local light = LocalPlayer().HiddenFlashlight
    local ang = RenderAngles()
    local pos = EyePos() + ang:Forward() * 1
    light:SetPos(pos)
    light:SetAngles(ang)
    light:Update()
end

function ToggleNightVision()
    surface.PlaySound('items/flashlight1.wav')
    nightVisionEnabled = not nightVisionEnabled

    if nightVisionEnabled then
        hook.Add("RenderScreenspaceEffects", "NightVisionEffect", function()
            local colorCorrection = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0.05,
                ["$pp_colour_addb"] = 0.05,
                ["$pp_colour_brightness"] = 0.025,
                ["$pp_colour_contrast"] = 1.2,
                ["$pp_colour_colour"] = 0.45,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(colorCorrection)
        end)

        if not LocalPlayer().HiddenFlashlight then
            local light = ProjectedTexture()
            light:SetTexture("effects/flashlight001_infected")
            light:SetFarZ(1024)
            light:SetNearZ(1)
            light:SetFOV(75)
            light:SetBrightness(2)
            light:SetEnableShadows(false)
            light:SetColor(Color(255, 255, 255))
            light:Update()
            LocalPlayer().HiddenFlashlight = light
        end
        
        hook.Add("Think", "UpdateNightVisionFlashlight", UpdateFlashlightPosition)
    else
        hook.Remove("RenderScreenspaceEffects", "NightVisionEffect")
        hook.Remove("Think", "UpdateNightVisionFlashlight")
        if LocalPlayer().HiddenFlashlight then
            LocalPlayer().HiddenFlashlight:Remove()
            LocalPlayer().HiddenFlashlight = nil
        end
    end
end

net.Receive("nv_off", function()
    if nightVisionEnabled then
        ToggleNightVision()
    end
end)

net.Receive("nv_on", function()
    if not nightVisionEnabled then
        ToggleNightVision()
    end
end)

concommand.Add("toggle_nightvision", function()
    if LocalPlayer():IsAdmin() then
        ToggleNightVision()
    end
end)
