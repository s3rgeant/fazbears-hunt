local playerSpecName

local function DrawDeadHUD()
	if !IsValid(playerSpecName) or playerSpecName:Nick() == '' or !GetConVar("cl_drawhud"):GetBool() then return end

    local x = (ScrW() / 2) - (330 / 2)
    local y = ScrH() - (100 / 2) - 140

    draw.RoundedBox(10, x, y, 330, 140, Color(0, 0, 0, 200))

    draw.SimpleText("НАБЛЮДЕНИЕ:", "timerFontBelow", ScrW() / 2, y + 28, Color(255, 220, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
	draw.SimpleText(playerSpecName:Nick(), "timerFontBelow", ScrW() / 2, y + 70, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
	draw.SimpleText(playerSpecName:Health()..' HP', "timerFontBelow", ScrW() / 2, y + 112, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

net.Receive("DeadHUDEnable", function()
	hook.Add("HUDPaint", "DrawDead", DrawDeadHUD)
end)

net.Receive("DeadHUDChange", function()
	playerSpecName = net.ReadEntity()
end)

net.Receive("DeadHUDChangeString", function()
	playerSpecName = net.ReadString()
end)

net.Receive("DeadHUDDisable", function()
	hook.Remove( "HUDPaint" , "DrawDead" )
	playerSpecName = nil
end)

// сделал Zhapka