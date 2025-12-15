local playerSpecName

local function DrawDeadHUD()
	if not GetConVar("cl_drawhud"):GetBool() then return end
	
	local lp = LocalPlayer()
	
	local obs_target = lp:GetObserverTarget()
	
	if !IsValid(obs_target) then return end
	
	if lp:GetObserverMode() == OBS_MODE_ROAMING then return end
	
	local displayName
	local healthText

	if obs_target:IsPlayer() then
		if obs_target:Nick() == "" then return end
		displayName = utf8.sub(obs_target:Nick(), 0, 23)
		healthText = obs_target:Health() .. " HP"
	elseif IsValid(obs_target:GetOwner()) then
		local owner = obs_target:GetOwner()
		
		if owner:IsPlayer() then
			displayName = utf8.sub(owner:Nick(), 0, 23)
			healthText = owner:Health() .. " HP"
			
		end
	else
		displayName = obs_target:GetClass() -- Имя класса энтити
		healthText = obs_target:Health() and (obs_target:Health() .. " HP") or "???"
	end

    local x = (ScrW() / 2) - (330 / 2)
    local y = ScrH() - (100 / 2) - 78
	
	surface.SetDrawColor(255, 255, 255, 250)
	surface.SetMaterial(Material("vgui/spectator/window.png"))
	surface.DrawTexturedRect(ScrW() / 2 - 200, ScrH() - (100 * 1.2), 400, 100)
	
    draw.SimpleText(language.SafeGetPhrase("fazhunt.spectating") .. ":", "timerFontUpper", ScrW() / 2, y + 29, Color(202, 125, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(displayName, "timerFontUpper", ScrW() / 2, y + 61, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(healthText, "timerFontSmall", ScrW() / 2, y + 91, Color(202, 125, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

surface.CreateFont("requestFont", { 
	font = "Share Tech Mono Regular", 
	size = 30, 
	extended = true, 
	weight = 400, 
	antialias = true, 
	bold = true 
})

local requestActive = false
local requestFunc

local popup_mat = Material("vgui/optionmenu/popup.png")
function fh_draw_request(func, title)
	if !GetConVar("cl_drawhud"):GetBool() then return end
	
	requestActive = true
	requestFunc = func
	
	local wind_width = 1000

    local x = (ScrW() / 2) - (wind_width / 2)
    local y = 125

	--draw.RoundedBox(24, x, y, wind_width, 80, Color(0, 0, 0, 200))
	
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(popup_mat)
	surface.DrawTexturedRect(x, y, wind_width, 100)
	
	draw.SimpleText(language.GetPhrase(title), "requestFont", ScrW() / 2, y + 25, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(language.GetPhrase("fazhunt.spectating.yes") .. " (F1)", "requestFont", (ScrW() / 2) - 160, y + 65, Color(0, 255, 33), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(language.GetPhrase("fazhunt.spectating.no") .. " (F2)", "requestFont", (ScrW() / 2) + 160, y + 65, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

net.Receive("DeadHUDEnable", function()
	hook.Add("HUDPaint", "DrawDead", DrawDeadHUD)
	hook.Remove("HUDPaint", "fh_pt_draw_affected")
end)

local function plushtrap_request()
	net.Start("pt_request")
	net.SendToServer()
end

local function fox_request()
	net.Start("fox_request")
	net.SendToServer()
end

net.Receive("dead_pt_request_start", function()
	hook.Add("HUDPaint", "hud_fh_request", function() fh_draw_request(plushtrap_request, "fazhunt.spectating.plushtrap_request") end)
end)

net.Receive("fox_request_start", function()
	hook.Add("HUDPaint", "hud_fh_request", function() fh_draw_request(fox_request, "fazhunt.request.fox") end)
end)

net.Receive("client_requset_stop", function()
	hook.Remove("HUDPaint", "hud_fh_request")
	requestActive = false
end)

net.Receive("DeadHUDDisable", function()
	hook.Remove("HUDPaint", "DrawDead")
	hook.Remove("HUDPaint", "hud_fh_request")
	playerSpecName = nil
	
	requestActive = false
end)

hook.Add( "PlayerButtonDown", "fh_pt_request_buttondown", function( ply, but )
	if !requestActive then return end
	
	if ( but == KEY_F1 ) then
		if requestFunc then requestFunc() end
	
		hook.Remove("HUDPaint", "hud_fh_request")
		requestActive = false
	elseif ( but == KEY_F2 ) then
		hook.Remove("HUDPaint", "hud_fh_request")
		requestActive = false
	end
end )

// базу сделал Zhapka

local real_zoom = 1
local zoom = 1
local add_fov = 0

hook.Add( "InputMouseApply", "fh_zooming_mwheel", function( cmd )
	real_zoom = real_zoom + cmd:GetMouseWheel()
	
	if real_zoom < 0 then
		real_zoom = math.Clamp(real_zoom, -15, 70)
		add_fov = math.Clamp(-real_zoom, 0, 25)
	end
	
	if real_zoom > 70 then
		real_zoom = 70
	end
	
	zoom = math.Clamp(real_zoom, 0, 70)
end )

hook.Add("CalcView", "fh_spec_calcview", function(ply, pos, angles, fov)
    if ply:GetObserverTarget():IsValid() then 
		local observermode = ply:GetObserverMode()
		local target = ply:GetObserverTarget()
		if IsValid(target) and observermode == OBS_MODE_CHASE then
			
			local view = {}

			view.angles = angles
			view.origin = pos - view.angles:Forward() * -zoom
			view.fov = fov + add_fov
			return view
		end
	end
end)