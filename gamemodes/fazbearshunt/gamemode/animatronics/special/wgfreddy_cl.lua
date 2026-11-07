AddCSLuaFile()

if SERVER then return end

local yellow_clr = Color(255,255,0)

local isin_outworld = false
function IsInOutworld()
	return isin_outworld
end

local function stopDrawingEveryone(exceptPly)
	for _, ply in player.Iterator() do
		if ply == exceptPly then continue end
	
		ply:SetNoDraw(true)
		if !IsValid(pills.getMappedEnt(ply)) then
			ply:DrawShadow(false)
		end
		
		for _, wep in ipairs(ply:GetWeapons()) do
			if IsValid(wep) then
				wep:SetNoDraw(true)
				wep:DrawShadow(false)
				wep:SetRenderMode(RENDERMODE_NONE)
			end
		end
	end
end

local function startDrawingEveryone()
	for _, ply in player.Iterator() do
		ply:SetNoDraw(false)
		if !IsValid(pills.getMappedEnt(ply)) then
			ply:DrawShadow(true)
		end
		
		for _, wep in ipairs(ply:GetWeapons()) do
			if IsValid(wep) then
				wep:SetNoDraw(false)
				wep:DrawShadow(true)
				wep:SetRenderMode(RENDERMODE_NORMAL)
			end
		end
	end
end

hook.Add("PrePlayerDraw", "fh_dontdraw_outworlded" , function(ply)
	local myself = LocalPlayer()
	
	if ply == myself then return end
	
	if !IsValid(myself) or !myself:Alive() then return end
	
	if ply:GetNW2Bool("_OUTWORLD_target") and !myself:GetNW2Bool("_OUTWORLD_gfreddy") 
	or (myself:GetNW2Bool("_OUTWORLD_target") and ply ~= myself) 
	or (myself:GetNW2Bool("_OUTWORLD_gfreddy") and !ply:GetNW2Bool("_OUTWORLD_target")) then
		ply:DestroyShadow()
	
		for _, wep in ipairs(ply:GetWeapons()) do
			if IsValid(wep) then
				wep:DestroyShadow()
			end
		end
		return true
	end
end)

hook.Add( "ForceDrawPill", "fh_pill_wgfreddy_nodraw", function( ply, ent )
	local myself = LocalPlayer()
	if IsValid(myself) and myself:Alive() then
		if ply == myself then return end
	
		if !myself:GetNW2Bool("_OUTWORLD_target") and ply:GetNW2Bool("_OUTWORLD_gfreddy") then
			return false
		elseif myself:GetNW2Bool("_OUTWORLD_target") and !ply:GetNW2Bool("_OUTWORLD_gfreddy") then
			return false
		end
		
		if myself:GetNW2Bool("_OUTWORLD_gfreddy") and !ply:GetNW2Bool("_OUTWORLD_target") then
			return false
		end
	end
end)

hook.Add( "PillCostumeEmitSound", "fh_wgfreddy_sound_handler", function( t )
	myself = myself or LocalPlayer()
	if IsValid(myself) and myself:Alive() then
		if myself:GetNW2Bool("_OUTWORLD_target") or myself:GetNW2Bool("_OUTWORLD_gfreddy") then
			if IsValid(t.Entity) and t.Entity:GetClass() == "pill_costume" then
				if t.Entity.formTable and t.Entity.formTable.name ~= "pill_wgfreddy2" then
					return false
				end
			end
		end
	end
end)

hook.Add( "FH_HandleMineTerrorRadius", "fh_wgf_target_tr_handler", function( myself, ply, theme )
	if myself:GetNW2Bool("_OUTWORLD_target") and !ply:GetNW2Bool("_OUTWORLD_gfreddy") then
		return false
	end
end)

hook.Add( "FH_HandleKillerTerrorRadius", "fh_wgf_tr_handler", function( myself, killer, theme )
	if myself:GetNW2Bool("_OUTWORLD_target") then
		return false
	end

	if IsValid(myself:GetPill()) and myself:GetPill():GetPillName() == "pill_wgfreddy2" and !myself:GetNW2Bool("_OUTWORLD_gfreddy")
	or myself:GetNW2Bool("_OUTWORLD_gfreddy") and !killer:GetNW2Bool("_OUTWORLD_target") then
		return false
	end
end)

hook.Add( "PlayerFootstep", "fh_nosteps_outworlded", function( ply, pos, foot, sound, volume, rf )
	myself = myself or LocalPlayer()
	
	if !IsValid(myself) then return end
	
	if ply:GetNW2Bool("_OUTWORLD_target") and !myself:GetNW2Bool("_OUTWORLD_gfreddy") 
	or myself:GetNW2Bool("_OUTWORLD_target") and ply ~= myself 
	or myself:GetNW2Bool("_OUTWORLD_gfreddy") and !ply:GetNW2Bool("_OUTWORLD_target") then
		return true
	end
end)

hook.Add( "EntityNetworkedVarChanged", "fh_wgfreddy_network_handler", function( ent, name, oldval, newval )
	if !ent:IsPlayer() then return end
	
	if name ~= "_OUTWORLD_target" then return end
	
	if newval == true then
		ent:DrawShadow(false)
	elseif newval == false then
		ent:DrawShadow(true)
	end
end)

local outworld_ambient = outworld_ambient or nil
net.Receive("wgfreddy_second_ambience", function()
	if IsValid(outworld_ambient) then
		outworld_ambient:Stop()
		outworld_ambient = nil
	end
	
	sound.PlayFile("sound/fnaf2/gfreddy/outworld_ambient_2.wav", "noplay noblock", function(chan, errID, errStr)
		if IsValid(chan) then
			outworld_ambient = chan
			chan:SetVolume(1)
			chan:SetPos(LocalPlayer():GetPos())
			chan:EnableLooping(true)
			chan:Play()
		end
	end)
end)

local ourTarget
local GFREDDY_COLOR   = Color(255, 200, 0, 255)
local function getGFreddyTarget(lp, rule)
	if not lp:GetNW2Bool("_OUTWORLD_gfreddy") then return nil end

	if not IsValid(ourTarget) then return nil end

	local pos = ourTarget:GetPos()
	if !pos:ToScreen().visible then return end

	local entry = OUTLINE.NormalizeEntry(rule, {
		ent = ourTarget,
		outline_color = GFREDDY_COLOR
	})

	return entry and { entry } or nil
end

OUTLINE.RegisterRule("gfreddy_outworld_target", {
	priority = 155,
	render_max_dist = 9000,

	outline_color = GFREDDY_COLOR,
	outline_width = 1.5,
	outline_min_dist = 0,
	outline_max_dist = 0,

	fill_color = GFREDDY_COLOR,
	fill_min_dist = 0,
	fill_max_dist = 0,

	mode = OUTLINE_MODE_BOTH,
	collect = getGFreddyTarget
})

local function getGFreddySelectie(lp, rule)
	local pill = lp:GetPillCostume()
	if not IsValid(pill) or pill:GetPillName() ~= "pill_wgfreddy2" then return nil end
	if lp:GetNW2Bool("_OUTWORLD_gfreddy") then return nil end

	local target = fh_get_wgfreddy_target(lp)
	if not IsValid(target) then return nil end

	local maxDist = tonumber(rule.render_max_dist) or math.huge
	local maxDistSqr = maxDist > 0 and (maxDist * maxDist) or math.huge
	local pos = target:GetPos()
	if !pos:ToScreen().visible then return nil end

	local entry = OUTLINE.NormalizeEntry(rule, {
		ent = target,
		outline_color = GFREDDY_COLOR
	})

	return entry and { entry } or nil
end

OUTLINE.RegisterRule("gfreddy_selecting", {
	priority = 150,
	render_max_dist = 600,

	outline_color = GFREDDY_COLOR,
	outline_width = 2,
	outline_min_dist = 0,
	outline_max_dist = 0,
	
	fill_color = GFREDDY_COLOR,
	fill_min_dist = 0,
	fill_max_dist = 0,

	mode = OUTLINE_MODE_BOTH,
	collect = getGFreddySelectie
})

local function fh_wgfreddy_selecting_halo()
	hook.Add("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local target = fh_get_wgfreddy_target(ply)
		if not IsValid(target) then return end
	
		local pos = target:GetPos() + Vector(0, 0, 85)
		local ang = LocalPlayer():EyeAngles()
		ang:RotateAroundAxis(ang:Up(), -90)
		ang:RotateAroundAxis(ang:Forward(), 90)
	
		cam.Start3D2D(pos, ang, 0.1)
			draw.SimpleTextOutlined(language.GetPhrase("fazhunt.wgfreddy.press_r"), "timerFontBelow", 0, 0, Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black)
		cam.End3D2D()
	end)
end

hook.Add("PillApply", "wgfreddy_Apply", function(ply, ent)
	if ply == LocalPlayer() and ent.formTable and ent.formTable.name == "pill_wgfreddy2" then
		fh_wgfreddy_selecting_halo()
	end
end)

net.Receive("fh_wgfreddy_selecting_halo", fh_wgfreddy_selecting_halo)

local mat_Grayscale = Material( "effects/shaders/merc_grayscale" )
local function grayscale()
	needsDepth = true
	render.UpdateScreenEffectTexture()
	mat_Grayscale:SetFloat("$c0_x", -0.8 )
	mat_Grayscale:SetFloat("$c0_y", 0.5 )
	render.SetMaterial(mat_Grayscale)
	render.DrawScreenQuad()
	needsDepth = false
end

-- интерфейс

surface.CreateFont("OutworldHealth", 
	{ font = "Plate New", size = 48, extended = true, weight = 400, antialias = true, bold = true, shadow = true })

--[[
	# ЗАГРАННЫЙ МИР: ЖЕРТВА
	НАЧАЛО ИВЕНТА
]]
net.Receive("fh_wgfreddy_target_outworld_start", function()
	myself = myself or LocalPlayer()
	local assasin = net.ReadPlayer()
	
	stopDrawingEveryone(assasin)
	
	fh_cl_draw_plushies()
	
	if !myself:GetNW2Bool("KillerObsessed") then
		myself:SetDSP(16)
		
		sound.PlayFile("sound/fnaf2/gfreddy/outworld_enter.wav", "noplay", function(chan, errID, errStr)
			if IsValid(chan) then
				chan:SetPos(LocalPlayer():GetPos())
				chan:Play()
			end
		end)
		
		sound.PlayFile("sound/fnaf2/gfreddy/outworld_ambient_loop.wav", "noplay noblock", function(chan, errID, errStr)
			if IsValid(chan) then
				outworld_ambient = chan
				chan:SetVolume(1)
				chan:SetPos(LocalPlayer():GetPos())
				chan:EnableLooping(true)
				chan:Play()
			end
		end)
	end
	
	isin_outworld = true
	myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 4, 0.5)

	--[[
		Тестили.
		
		Тестер смотрел в пол, или в потолок. Поэтому мы делаем вот такое водт
	]]
	hook.Add("CreateMove", "fh_limit_camera_outworld", function(cmd)
		if _G.fh_is_scared_lock then return end
		
		local ang = cmd:GetViewAngles()
		local offset = math.Clamp(ang.p - 0, -45, 45)
		
		ang.p = 0 + offset
		
		cmd:SetViewAngles(ang)
	end)
	hook.Add("RenderScreenspaceEffects", "merc_grayscale_hook", grayscale)
	hook.Add("NeedsDepthPass", "merc_grayscale_depth", function()
		DOFModeHack(true)
		return true
	end)
	hook.Add("SetupWorldFog", "WhiteFogEffect", function()
		render.FogMode(MATERIAL_FOG_LINEAR)
		render.FogStart(0)
		render.FogEnd(1500)
		render.FogMaxDensity(1)
		render.FogColor(150, 150, 150) -- Белый цвет
		return true
	end)
	hook.Add("SetupSkyboxFog", "WhiteFogEffectSkybox", function(scale)
		render.FogMode(MATERIAL_FOG_LINEAR)
		render.FogStart(0)
		render.FogEnd(1500 * scale)
		render.FogMaxDensity(1)
		render.FogColor(150, 150, 150)
		return true
	end)
	hook.Add("FH_PreDrawHud", "gfreddy_hud", function()
		return true
	end)
	hook.Add("PreDrawEffects", "gfreddy_hud", function()
	
		local w = ScrW()
		local h = ScrH()
		
		local hp = myself:Health()

		cam.Start2D()
			draw.SimpleText( hp .. " HP", "OutworldHealth", w/2, h - 32, healthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		cam.End2D()
	end)

	local PARTICLE_TEXTURE = "particles/smokinweed"
	local RADIUS = 1200
	local PARTICLE_INTERVAL = 0.03
	local PARTICLES_PER_TICK = 2
	local nextParticleTime = 0
	hook.Add("Think", "GroundDustParticlesDense", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end
		if CurTime() < nextParticleTime then return end

		nextParticleTime = CurTime() + PARTICLE_INTERVAL

		local emitter = ParticleEmitter(ply:GetPos(), false)
		if not emitter then return end

		for i = 1, PARTICLES_PER_TICK do
			local angle = math.Rand(0, 2 * math.pi)
			local distance = math.Rand(50, RADIUS)
			local offset = Vector(math.cos(angle), math.sin(angle), 0) * distance

			local traceData = {
				start = ply:GetPos() + offset + Vector(0, 0, 100),
				endpos = ply:GetPos() + offset - Vector(0, 0, 200),
				mask = MASK_SOLID_BRUSHONLY
			}
			local tr = util.TraceLine(traceData)
			if not tr.Hit then continue end

			local pos = tr.HitPos + Vector(0, 0, 2)

			local particle = emitter:Add(PARTICLE_TEXTURE, pos)
			if particle then
				local upVelocity = Vector(0, 0, math.Rand(10, 20))
				local sideVelocity = ply:GetRight() * math.Rand(5, 10)

				particle:SetVelocity(upVelocity + sideVelocity)
				particle:SetLifeTime(0)
				particle:SetDieTime(math.Rand(2, 3))
				particle:SetStartAlpha(math.Rand(80, 120))
				particle:SetEndAlpha(0)
				particle:SetStartSize(math.Rand(1, 6))
				particle:SetEndSize(math.Rand(6, 12))
				particle:SetRoll(math.Rand(0, 360))
				particle:SetRollDelta(math.Rand(-0.3, 0.3))
				particle:SetColor(170, 170, 170)
				particle:SetAirResistance(25)
			end
		end

		emitter:Finish()
	end)
end)
--[[
	# ЗАГРАННЫЙ МИР: ЖЕРТВА
	КОНЕЦ ИВЕНТА
]]
net.Receive("fh_wgfreddy_target_outworld_end", function()
	myself = myself or LocalPlayer()
	
	startDrawingEveryone()
	fh_cl_dontdraw_plushies()
	
	if IsValid(outworld_ambient) then
		outworld_ambient:Stop()
		outworld_ambient = nil
	end
	
	isin_outworld = false
	myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 2, 0.5)
	
	hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
	hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
	hook.Remove("SetupWorldFog", "WhiteFogEffect")
	hook.Remove("SetupSkyboxFog", "WhiteFogEffectSkybox")
	hook.Remove("RenderScreenspaceEffects", "merc_videoglitch_hook")
	hook.Remove("Think", "GroundDustParticlesDense")
	hook.Remove("CreateMove", "fh_limit_camera_outworld")
	hook.Remove("FH_PreDrawHud", "gfreddy_hud")
	hook.Remove("PreDrawEffects", "gfreddy_hud")
	ourTarget = nil
end)

--[[
	# ЗАГРАННЫЙ МИР: ЗОЛОТОЙ ФРЕДДИ
	НАЧАЛО ИВЕНТА
]]
net.Receive("fh_wgfreddy_outworld_start", function()
	myself = myself or LocalPlayer()
	local target = net.ReadPlayer()
	ourTarget = target
	
	stopDrawingEveryone(target)
	
	fh_cl_draw_plushies()
	
	hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
	
	myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 4, 0.5)
	hook.Add("RenderScreenspaceEffects", "merc_grayscale_hook", grayscale)
	hook.Add("NeedsDepthPass", "merc_grayscale_depth", function()
		DOFModeHack(true)
		return true
	end)

	local wgf_target_orb = Material("vgui/wgfreddy_target_orb.png", "noclamp smooth")
	hook.Add("HUDPaint", "fh_draw_wgfreddy_target_orb", function()
		if !IsValid(target) then
			hook.Remove("HUDPaint", "fh_draw_wgfreddy_target_orb")
			return
		end
	
		cam.Start3D()
			target:DrawModel()
		cam.End3D()
		
		draw_orbs({ [target] = yellow_clr }, wgf_target_orb )
	end)
end)

--[[
	# ЗАГРАННЫЙ МИР: ЗОЛОТОЙ ФРЕДДИ
	КОНЕЦ ИВЕНТА
]]
net.Receive("fh_wgfreddy_outworld_stop", function()
	myself = myself or LocalPlayer()
	
	startDrawingEveryone()
	hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
	
	myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 1, 0.5)
	hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
	hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
	hook.Remove("HUDPaint", "fh_draw_wgfreddy_target_orb")
	
	isin_outworld = false
	fh_cl_dontdraw_plushies()
end)

hook.Add( "PostCleanupMap", "fh_pill_wgfreddy_reset", function( name )
	hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
	hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
	hook.Remove("HUDPaint", "fh_draw_wgfreddy_target_orb")
	hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
	hook.Remove("SetupWorldFog", "WhiteFogEffect")
	hook.Remove("SetupSkyboxFog", "WhiteFogEffectSkybox")
	hook.Remove("RenderScreenspaceEffects", "merc_videoglitch_hook")
	hook.Remove("CreateMove", "fh_limit_camera_outworld")
	
	-- victim
	hook.Remove("FH_PreDrawHud", "gfreddy_hud")
	hook.Remove("PreDrawEffects", "gfreddy_hud")
	hook.Remove("Think", "GroundDustParticlesDense")
	
	isin_outworld = false
	fh_cl_dontdraw_plushies()
	ourTarget = nil
end)