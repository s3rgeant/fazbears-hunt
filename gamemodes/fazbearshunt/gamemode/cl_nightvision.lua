local nightVisionEnabled = false

function ToggleNightVision()
	surface.PlaySound('items/flashlight1.wav')
    nightVisionEnabled = not nightVisionEnabled

    if nightVisionEnabled then
        hook.Add("RenderScreenspaceEffects", "NightVisionEffect", function()
            local colorCorrection = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = 0.1,
                ["$pp_colour_contrast"] = 1.0,
                ["$pp_colour_colour"] = 0.4,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(colorCorrection)
        end)

        hook.Add("Think", "NightVisionDynamicLight", function()
			local lighttarget = LocalPlayer()
            if not lighttarget:Alive() then 
				if !IsValid(lighttarget:GetObserverTarget()) then
					return
				end
				lighttarget = lighttarget:GetObserverTarget()
			end

            local dlight = DynamicLight(lighttarget:EntIndex())
            if dlight then
                dlight.pos = lighttarget:GetPos() + Vector(0, 0, 50)
                dlight.r = 200
                dlight.g = 255
                dlight.b = 200
                dlight.brightness = 1
                dlight.Decay = 1000
                dlight.Size = 750
                dlight.DieTime = CurTime() + FrameTime() * 3
            end
        end)
    else
        hook.Remove("RenderScreenspaceEffects", "NightVisionEffect")
        hook.Remove("Think", "NightVisionDynamicLight")
    end
end

net.Receive("nv_off", function()
	if nightVisionEnabled then
		ToggleNightVision()
	end
end)

net.Receive("nv_on", function()
	if !nightVisionEnabled then
		ToggleNightVision()
	end
end)

concommand.Add("toggle_nightvision", function()
	if LocalPlayer():IsAdmin() then
		ToggleNightVision()
	end
end)