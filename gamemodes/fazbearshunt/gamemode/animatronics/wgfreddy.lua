AddCSLuaFile()

util.PrecacheSound("fnaf2/gfreddy/plushie_hint.mp3")
util.PrecacheSound("fnaf2/gfreddy/plushie_taken.wav")
util.PrecacheSound("fnaf2/gfreddy/plushie_taken_alert.wav")
util.PrecacheSound("fnaf2/gfreddy/gfreddy_target.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_escaped.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_enter.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_ambient_loop.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_ambient_2.wav")

team.SetUp( 27, "Secret Animatronics", Color(255, 0, 0), true )

hook.Add("fh_startgame", "spawn_wgfreddy", function(roundType)
	if !navmesh.IsLoaded() or navmesh.GetNavAreaCount() < 5 then
		return
	end
	
	if math.random(1,8) == 1 or GetConVar( "developer" ):GetBool() then
		if roundType == 0 then
			local players = team.GetPlayers(TEAM_UNASSIGNED)
			local count = table.Count(players)
			
			if count >= 8 or ( GetConVar( "developer" ):GetBool() and count > 2 ) then
				players = fh.GetEarnedKillers(players)
				
				local chosenPlayer = fh.randomChoice(players)
		
				giveKillerSilent(chosenPlayer, "pill_wgfreddy2", true)
				chosenPlayer:ReturnToSpawn()
			end
		end
	end
end)

hook.Add("PillSound", "gf_pillsound_management", function(ply, ent, name)
	if !table.IsEmpty(wgfreddy_targets) then
		for k, v in pairs( wgfreddy_targets ) do
			local victim = v
			
			if IsValid(victim) then -- на всякий случень
				if ply ~= outworld_victims[victim] then
			
					local rf = RecipientFilter()
					rf:AddAllPlayers()
					rf:RemovePlayer(victim)
					
					return rf
				end
			end
		end
	end
end)

hook.Add("PlayerShouldTakeDamage", "gf_nodamage", function(ply, attacker)
	if fh.GetActiveUsedKiller("pill_wgfreddy2") == ply then
		return false
	end
	
	if outworld_victims[ply] and (attacker ~= outworld_victims[ply] and attacker ~= game.GetWorld()) then
		return false
	end
end)

hook.Add("FH_HandleTaserHit", "gf_notaser", function(ply)
	if wgfreddy_targets[ply] then
		return false
	end
end)

hook.Add("FH_HandlePlayerGrab", "gf_victim_nograb", function(endo, ply)
	if outworld_victims[ply] then
		return false
	end
end)

if SERVER then
	hook.Add("PillServerApply", "gf_joinpill", function(ply, name)
		if name == "pill_wgfreddy2" then
			ply:SetTeam(27)
		end
	end)
end

function fh_spawnPlushies(ply)
	if !IsValid(ply) then return -1 end

	local origin = ply:GetPos()
	local minDistFromPlayer = 1000
	local maxDistFromPlayerStrict = 2700
	local maxDistFromPlayerLoose = 2400
	local sameFloorDist = 140
	local sameFloorDistMax = 450
	local minSpacing = 1600
	local plushCount = 4
	local placed = 0
	local usedPositions = {}
	
	local function spawnPlushAt(pos)
		local ent = ents.Create("fh_plushie")
		if IsValid(ent) then
			ent:Spawn()
            ent:SetPos(pos)
			ent.owner = ply
			table.insert(usedPositions, pos)
			placed = placed + 1
		end
	end
	
	local function isFarFromOthers(pos, minimumSpacing)
		minimumSpacing = minimumSpacing or minSpacing
		for _, used in ipairs(usedPositions) do
			if used:DistToSqr(pos) < minimumSpacing^2 then
				return false
			end
		end
		return true
	end
	
	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then
		print("[fh_plushie] Нет nav-меша.")
		return -2
	end
	
	table.Shuffle(areas)
	
	for _, area in ipairs(areas) do
		if placed >= plushCount then break end
		if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
	
		local pos = area:GetCenter()
		local distSqr = origin:DistToSqr(pos)
		
		if distSqr >= minDistFromPlayer^2 and distSqr <= maxDistFromPlayerStrict^2 and isFarFromOthers(pos) and math.abs(origin.z - pos.z) < sameFloorDist then
			spawnPlushAt(pos)
		end
	end
	
	if placed < plushCount then
		for _, area in ipairs(areas) do
			if placed >= plushCount then break end
			if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
	
			local pos = area:GetCenter()
			if origin:DistToSqr(pos) <= maxDistFromPlayerLoose^2 and isFarFromOthers(pos, 800) and math.abs(origin.z - pos.z) < sameFloorDistMax then
				spawnPlushAt(pos)
			end
		end
	end
	
	if placed < plushCount then
		print("[fh_plushie] Не удалось заспавнить "..plushCount.." плюшки. Заспавнено: " .. placed)
		if placed < 3 and placed > 0 then
			outworld_victims_count[ply] = (outworld_victims_count[ply] or 0) + (3 - placed)
		end
	else
		print("[fh_plushie] Успешно заспавнены "..plushCount.." плюшки.")
	end
	return placed
end

function killPlushies(ply)
	for _, ent in ipairs( ents.FindByClass("fh_plushie") ) do
		if ent.owner == ply then
			ent:Remove()
		end
	end
end

hook.Add("KeyPress", "fh_plushie_use_check", function(ply, key)
	if key ~= IN_USE then return end
	if !IsValid(ply) or !outworld_victims[ply] then return end

	local eyePos = ply:EyePos()
	local viewDir = ply:GetAimVector()

	for _, ent in ipairs(ents.FindByClass("fh_plushie")) do
		if !IsValid(ent) then continue end

		local toEnt = ent:GetPos() - eyePos
		local distSqr = toEnt:LengthSqr()
		if distSqr > (200 * 200) then continue end

		local dirToEnt = toEnt:GetNormalized()
		local dot = viewDir:Dot(dirToEnt)

		if dot >= 0.9848 then -- примерно 10 градусов угол
			ent:Remove()

			outworld_victims_count[ply] = (outworld_victims_count[ply] or 0) + 1

			if outworld_victims_count[ply] == 3 then
				cancel_outworld(ply)
			else
				net.Start("fh_ui_sound_play")
				net.WriteString("fnaf2/gfreddy/plushie_taken.wav")
				net.Send(ply)
				
				ply._LastGFPlushie = CurTime()
				
				PauseDamage(ply, 10)
				
				for k,v in pairs( wgfreddy_targets ) do
					if ply == v then
						net.Start("fh_ui_sound_play")
						net.WriteString("fnaf2/gfreddy/plushie_taken_alert.wav")
						net.Send(k)
						
						break
					end
				end
			end

			break
		end
	end
end)

if SERVER then
	hook.Add( "CanPlayerSuicide", "fh_gfreddy_suicide", function( ply )
		if outworld_victims[ply] then
			return false
		end
	end )
end

if CLIENT then
	local mat_Grayscale = Material( "effects/shaders/merc_grayscale" )
	
	local outworld_ambient = outworld_ambient or nil
	
	local outworlded_ppl = {}
	
	local PARTICLE_TEXTURE = "particles/smokinweed"
	local RADIUS = 1200
	local PARTICLE_INTERVAL = 0.03
	local PARTICLES_PER_TICK = 2

	local nextParticleTime = 0
	
	local centerPitch = 0
	local maxOffset = 45
	
	hook.Add("PrePlayerDraw", "fh_dontdraw_outworlded" , function(ply)
		if outworlded_ppl[ply] then
			ply:DestroyShadow()
		
			for _, wep in ipairs(ply:GetWeapons()) do
				if IsValid(wep) then
					wep:DestroyShadow()
				end
			end
			return true
		end
	end)
	hook.Add( "PlayerFootstep", "fh_nosteps_outworlded", function( ply, pos, foot, sound, volume, rf )
		if outworlded_ppl[ply] then
			return true
		end
	end)
	
	--[[
		# ЗАГРАННЫЙ МИР: ЖЕРТВА
		НАЧАЛО ИВЕНТА
	]]
	net.Receive("fh_wgfreddy_target_outworld_start", function()
		local myself = LocalPlayer()
		local assasin = net.ReadPlayer()
		
		fh_cl_draw_plushies()
		
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
		
		myself.outworld = true
		myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 4, 0.5)
		for _,ply in player.Iterator() do
			ply:SetNoDraw(true)
			ply:DrawShadow(false)
			
			outworlded_ppl[ply] = true
			
			for _, wep in ipairs(ply:GetWeapons()) do
				if IsValid(wep) then
					wep:SetNoDraw(true)
					wep:DrawShadow(false)
					wep:SetRenderMode(RENDERMODE_NONE)
				end
			end
			
			if ply ~= assasin then
				local ent = pills.getMappedEnt(ply)
				
				if IsValid(ent) then
					ent:SetNoDraw(true)
				end
			end
		end

		--[[
			Тестили.
			
			Тестер смотрел в пол, или в потолок. Поэтому мы делаем вот такое водт
		]]
		hook.Add("CreateMove", "fh_limit_camera_outworld", function(cmd)
			if _G.fh_is_scared_lock then return end
			
			local ang = cmd:GetViewAngles()
			local offset = math.Clamp(ang.p - centerPitch, -maxOffset, maxOffset)
			
			ang.p = centerPitch + offset
			
			cmd:SetViewAngles(ang)
		end)
		hook.Add("PrePlayerDraw", "fh_outworld_pv", function(ply)
			if ply ~= myself then
				ply:DestroyShadow()
		
				for _, wep in ipairs(ply:GetWeapons()) do
					if IsValid(wep) then
						wep:DestroyShadow()
					end
				end
				return true
			end
		end)
        hook.Add("RenderScreenspaceEffects", "merc_grayscale_hook", function()
            needsDepth = true
            render.UpdateScreenEffectTexture()
            mat_Grayscale:SetFloat("$c0_x", -0.8 )
            mat_Grayscale:SetFloat("$c0_y", 0.7 )
            render.SetMaterial(mat_Grayscale)
            render.DrawScreenQuad()
            needsDepth = false
        end)
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
	
	--[[
		# ЗАГРАННЫЙ МИР: ЖЕРТВА
		КОНЕЦ ИВЕНТА
	]]
	net.Receive("fh_wgfreddy_target_outworld_end", function()
		local myself = LocalPlayer()
		
		fh_cl_dontdraw_plushies()
		
		if IsValid(outworld_ambient) then
			outworld_ambient:Stop()
			outworld_ambient = nil
		end
		
		myself.outworld = false
		myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 2, 0.5)
		for _,ply in player.Iterator() do
			ply:SetNoDraw(false)
            ply:DrawShadow(true)
			
			outworlded_ppl[ply] = false
			
            for _, wep in ipairs(ply:GetWeapons()) do
                if IsValid(wep) then
                    wep:SetNoDraw(false)
                    wep:DrawShadow(true)
                    wep:SetRenderMode(RENDERMODE_NORMAL)
                end
            end
			
			local ent = pills.getMappedEnt(ply)
			
			if IsValid(ent) then
				ent:SetNoDraw(false)
			end
		end
		hook.Remove("PrePlayerDraw", "fh_outworld_pv")
		hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
		hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
		hook.Remove("SetupWorldFog", "WhiteFogEffect")
		hook.Remove("SetupSkyboxFog", "WhiteFogEffectSkybox")
		hook.Remove("RenderScreenspaceEffects", "merc_videoglitch_hook")
		hook.Remove("Think", "GroundDustParticlesDense")
		hook.Remove("CreateMove", "fh_limit_camera_outworld")
	end)
	
	local function fh_wgfreddy_selecting_halo()
		hook.Add("PreDrawHalos", "fh_wgfreddy_draw_halo", function()
			local ply = LocalPlayer()
			if not IsValid(ply) then return end
		
			local eyePos = ply:EyePos()
			local aimDir = ply:GetAimVector()
		
			local closestPlayer = nil
			local closestDist = math.huge
			local maxDistToLine = 50
			local maxRadius = 300
		
			for _, target in player.Iterator() do
				if target == ply or !IsValid(target) or !target:Alive() or target:Team() != TEAM_UNASSIGNED then continue end
				
				if target:GetGFreddyImmune() then continue end
		
				local targetPos = target:GetPos() + Vector(0, 0, 40)
				local toTarget = targetPos - eyePos
				local projLength = toTarget:Dot(aimDir)
				local closestPoint = eyePos + aimDir * projLength
		
				local distToLine = targetPos:Distance(closestPoint)
				local distToPlayer = ply:GetPos():Distance(target:GetPos())
		
				if distToLine <= maxDistToLine and distToPlayer <= maxRadius then
					if distToLine < closestDist then
						closestDist = distToLine
						closestPlayer = target
					end
				end
			end
		
			if IsValid(closestPlayer) then
				halo.Add({closestPlayer}, Color(255, 200, 0), 2, 2, 1, true, true)
				hook.Add("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text", function()
					if not IsValid(closestPlayer) then return end
				
					local pos = closestPlayer:GetPos() + Vector(0, 0, 85)
					local ang = LocalPlayer():EyeAngles()
					ang:RotateAroundAxis(ang:Up(), -90)
					ang:RotateAroundAxis(ang:Forward(), 90)
				
					cam.Start3D2D(pos, ang, 0.1)
						draw.SimpleText(language.GetPhrase("fazhunt.wgfreddy.press_r"), "timerFontBelow", 0, 0, Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					cam.End3D2D()
				end)
			else
				hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
			end
		end)
	end
	
	net.Receive("fh_wgfreddy_selecting_halo", fh_wgfreddy_selecting_halo)
	
	net.Receive("fh_wgfreddy_stop_selection_halo", function()
		hook.Remove("PreDrawHalos", "fh_wgfreddy_draw_halo")
		hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
	end)
	
	--[[
		# ЗАГРАННЫЙ МИР: ЗОЛОТОЙ ФРЕДДИ
		НАЧАЛО ИВЕНТА
	]]
	net.Receive("fh_wgfreddy_outworld_start", function()
		local myself = LocalPlayer()
		local target = net.ReadPlayer()
		
		fh_cl_draw_plushies()
		
		hook.Remove("PreDrawHalos", "fh_wgfreddy_draw_halo")
		hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
		
		myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 4, 0.5)
        hook.Add("RenderScreenspaceEffects", "merc_grayscale_hook", function()
            needsDepth = true
            render.UpdateScreenEffectTexture()
            mat_Grayscale:SetFloat("$c0_x", -0.8 )
            mat_Grayscale:SetFloat("$c0_y", 0.7 )
            render.SetMaterial(mat_Grayscale)
            render.DrawScreenQuad()
            needsDepth = false
        end)
        hook.Add("NeedsDepthPass", "merc_grayscale_depth", function()
            DOFModeHack(true)
            return true
        end)
		hook.Add( "PreDrawHalos", "fh_wgfreddy_halo", function()
			halo.Add({target}, Color(255, 200, 0, 255), 0.5, 0.5, 1, true, true)
		end)

		local wgf_target_orb = Material("vgui/wgfreddy_target_orb.png", "noclamp smooth")
		hook.Add("HUDPaint", "fh_draw_wgfreddy_target_orb", function()
			cam.Start3D()
				target:DrawModel()
			cam.End3D()
			
			draw_orbs({target}, wgf_target_orb)
		end)
		for _,ply in player.Iterator() do
			if ply ~= target and ply ~= LocalPlayer() then
				ply:SetNoDraw(true)
				ply:DrawShadow(false)
		
				outworlded_ppl[ply] = true
				
				for _, wep in ipairs(ply:GetWeapons()) do
					if IsValid(wep) then
						wep:SetNoDraw(true)
						wep:DrawShadow(false)
						wep:SetRenderMode(RENDERMODE_NONE)
					end
				end
				
				local ent = pills.getMappedEnt(ply)
				
				if IsValid(ent) then
					dontdrawanim[ent] = true
				end
			end
		end
		hook.Add("PrePlayerDraw", "fh_gfreddy_outworld_pv", function(ply)
			if ply ~= target then
				ply:DestroyShadow()
			
				for _, wep in ipairs(ply:GetWeapons()) do
					if IsValid(wep) then
						wep:DestroyShadow()
					end
				end
				return true
			end
		end)
	end)
	
	--[[
		# ЗАГРАННЫЙ МИР: ЗОЛОТОЙ ФРЕДДИ
		КОНЕЦ ИВЕНТА
	]]
	net.Receive("fh_wgfreddy_outworld_stop", function()
		local myself = LocalPlayer()
		
		hook.Remove("PreDrawHalos", "fh_wgfreddy_draw_halo")
		hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
		
		myself:ScreenFade(SCREENFADE.IN, Color(0,0,0), 1, 0.5)
        hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
        hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
		hook.Remove( "PreDrawHalos", "fh_wgfreddy_halo")
		hook.Remove("HUDPaint", "fh_draw_wgfreddy_target_orb")
		hook.Remove("PrePlayerDraw", "fh_gfreddy_outworld_pv")
		
		for _,ply in player.Iterator() do
			ply:SetNoDraw(false)
            ply:DrawShadow(true)
		
			outworlded_ppl[ply] = false
			
            for _, wep in ipairs(ply:GetWeapons()) do
                if IsValid(wep) then
                    wep:SetNoDraw(false)
                    wep:DrawShadow(true)
                    wep:SetRenderMode(RENDERMODE_NORMAL)
                end
            end
			
			local ent = pills.getMappedEnt(ply)
				
			if IsValid(ent) then
				dontdrawanim[ent] = false
			end
		end
		
		fh_cl_dontdraw_plushies()
	end)
	
	net.Receive("fh_dontdraw_player", function()
		local dude = net.ReadPlayer()
		
		if !IsValid(dude) then return end
		
		outworlded_ppl[dude] = true
		
		dude:SetNoDraw(true)
		dude:DrawShadow(false)
		
		for _, wep in ipairs(dude:GetWeapons()) do
			if IsValid(wep) then
				wep:SetNoDraw(true)
				wep:DrawShadow(false)
				wep:SetRenderMode(RENDERMODE_NONE)
			end
		end
	end)
	
	local dontdrawanim = {}
	net.Receive("fh_dontdraw_anim", function()
		local ent = net.ReadEntity()

		if IsValid(ent) then
			dontdrawanim[ent] = true
		end
	end)
	
	net.Receive("fh_draw_player", function()
		local dude = net.ReadPlayer()
		
		outworlded_ppl[dude] = false
		
		dude:SetNoDraw(false)
        dude:DrawShadow(true)
		
		if IsValid(dude) then
			for _, wep in ipairs(dude:GetWeapons()) do
				if IsValid(wep) then
					wep:SetNoDraw(false)
					wep:DrawShadow(true)
					wep:SetRenderMode(RENDERMODE_NORMAL)
				end
			end
		end
	end)
	
	net.Receive("fh_draw_anim", function()
		local ent = net.ReadEntity()
		
		if IsValid(ent) then
			dontdrawanim[ent] = nil
		end
	end)

	hook.Add( "PostCleanupMap", "fh_pill_wgfreddy_reset", function( name )
        hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
        hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
		hook.Remove( "PreDrawHalos", "fh_wgfreddy_halo")
		hook.Remove("HUDPaint", "fh_draw_wgfreddy_target_orb")
		hook.Remove("PrePlayerDraw", "fh_gfreddy_outworld_pv")
		hook.Remove("PreDrawHalos", "fh_wgfreddy_draw_halo")
		hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
		hook.Remove("PrePlayerDraw", "fh_outworld_pv")
		hook.Remove("SetupWorldFog", "WhiteFogEffect")
		hook.Remove("SetupSkyboxFog", "WhiteFogEffectSkybox")
		hook.Remove("RenderScreenspaceEffects", "merc_videoglitch_hook")
		hook.Remove("CreateMove", "fh_limit_camera_outworld")
		
		fh_cl_dontdraw_plushies()
		
		table.Empty(outworlded_ppl)
		table.Empty(dontdrawanim)
	end)

	hook.Add( "ForceDrawPill", "fh_pill_wgfreddy_nodraw", function( ply, ent )
		local myself = LocalPlayer()
		if myself:Alive() and dontdrawanim[ent] then
			return false
		end
	end)
end

function fh_get_wgfreddy_target(ply)
	local eyePos = ply:EyePos()
	local aimDir = ply:GetAimVector()
	
	local closestPlayer = nil
	local closestDist = math.huge
	local maxDistToLine = 50
	local maxRadius = 300
	
	for _, target in player.Iterator() do
		if target == ply or not IsValid(target) or !target:Alive() or target:Team() != TEAM_UNASSIGNED or target == stalkTarget then continue end
		
		if target:GetGFreddyImmune() then continue end
	
		local targetPos = target:GetPos() + Vector(0, 0, 40)
		local toTarget = targetPos - eyePos
		local projLength = toTarget:Dot(aimDir)
		local closestPoint = eyePos + aimDir * projLength
	
		local distToLine = targetPos:Distance(closestPoint)
		local distToPlayer = ply:GetPos():Distance(target:GetPos())
	
		if distToLine <= maxDistToLine and distToPlayer <= maxRadius then
			if distToLine < closestDist then
				closestDist = distToLine
				closestPlayer = target
			end
		end
	end
	return closestPlayer
end

local PLAYER = FindMetaTable("Player")

if PLAYER then
	function PLAYER:SetGFreddyImmune(bool)
		self:SetNWBool("GFreddyImmune", bool)
	end
	
	function PLAYER:GetGFreddyImmune()
		return self:GetNWBool("GFreddyImmune", false)
	end
end

local function cancel_outworld_target(ply)
	net.Start("fh_draw_player")
	net.WritePlayer(ply)
	net.Broadcast()
	
	net.Start("fh_net_scarysound")
	net.WriteBool(true)
	net.Send(ply)

	ply:SetJumpBoostMultiplier(getScaledJumpBoost())
	ply:SetRunSpeed(420)
	ply:SetWalkSpeed(200)
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	ply:SetCustomCollisionCheck(true)
	ply:CollisionRulesChanged()
	ply:SetDSP(0)
	ply:SetFOV(0, 0, game.GetWorld())
		
	ply:SetPushImmune(false)
	ply:SetPushBlocked(false)
	
	ply:SetAudible(true)
	
	ply:SetGFreddyImmune(true)
	
	for _, enemy in ipairs( ents.FindInSphere( ply:GetPos(), 350 ) ) do
		if not enemy:IsPlayer() or not enemy:Alive() or enemy:IsSurvivor() then continue end
		
		if enemy:IsAnimatronic() then -- находим первого попавшего анимона и даруем бессмертие жертве
			
			ply:GodEnable()
			ply:SetRunSpeed(500)
			
			timer.Simple(8, function()
				if IsValid(ply) then
					ply:GodDisable()
					ply:SetRunSpeed(420)
				end
			end)
			
			break
		end
	end

	net.Start("fh_wgfreddy_target_outworld_end")
	net.Send(ply)

	net.Start("fh_adv_sound_play")
	net.WriteString("fnaf2/gfreddy/outworld_escaped.wav")
	net.Send(ply)
	
	if outworld_victims[ply] then
		outworld_victims[ply] = nil
	end
end

hook.Add("PlayerSpawn", "wgfreddy_noimmune", function(ply)
	ply:SetGFreddyImmune(false)
end)

local sfreddy_noclip_movement = {500, 600, 500, 250}
local function cancel_outworld_wgfreddy(ply)
	wgfreddy_targets[ply] = nil
	
	ply:ResetListenPlayer()
	
	net.Start("fh_wgfreddy_outworld_stop")
	net.Send(ply)
	
	ply:SetNWBool("wgfreddy_enraged", false)

	local ent = pills.getMappedEnt(ply)
	if !IsValid(ent) or !ply:Alive() then return end
		
	net.Start("fh_wgfreddy_selecting_halo")
	net.Send(ply)

	net.Start("fh_draw_anim")
	net.WriteEntity(ent)
	net.Broadcast()

	if not ent.cloaked then
		ent:SetSpeed(unpack(sfreddy_noclip_movement))
		ply:DrawViewModel(false)

		ent:SetMaterial("models/null")
		ent:DrawShadow(false)
		
		ply:SetPushImmune(false)
		ply:SetPushBlocked(false)

		ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		ply:SetCustomCollisionCheck(true)
		ply:CollisionRulesChanged()

		ent.cloaked = true
	end
end

concommand.Add( "dev_start_outworld", function( ply, cmd, args )
	if !ply:IsSuperAdmin() then return end

	local nick1 = tostring(args[1])
	local nick2 = tostring(args[2])
	
	local gf = nil
	local target = nil
	
	for _, ply in player.Iterator() do
		local nickname = ply:Nick():lower()
	
		if !IsValid(gf) and nickname:match( nick1:lower() ) then
			gf = ply
			
			if IsValid(target) then
				break
			else
				continue
			end
		end
		
		if !IsValid(target) and nickname:match( nick2:lower() ) then
			target = ply
			
			if IsValid(gf) then
				break
			else
				continue
			end
		end
	end
	
	if IsValid(ply) and !IsValid(target) then
		target = ply
	end
	
	if IsValid(gf) and IsValid(target) then
		local ent = pills.getMappedEnt(gf)
		
		if IsValid(ent) then
			start_outworld(gf, ent, target)
			return
		else
			print("dev_start_outworld - has failed! Check if first player is Golden Freddy.")
			return
		end
	end
	
	print("dev_start_outworld - has failed! Maybe the nicknames were wrong.")
end )

function start_outworld(ply, ent, target)
	local placedPlushies = fh_spawnPlushies(target)
	
	if placedPlushies <= 0 then
		print("[GF] Failed to spawn plushies for Golden Freddy: " .. ply:Nick() .. " and Target: " .. target:Nick())
		print("[GF] Plushie Error Code: " .. placedPlushies)
		return
	end

	net.Start("fh_play_sound")
	net.WriteString('fnaf2/gfreddy/gfreddy_target.wav')
	net.Send(ply)
	
	net.Start("fh_wgfreddy_outworld_start") -- для ЗФ
	net.WritePlayer(target)
	net.Send(ply)
	
	ply:ChatPrint(target:Nick() .. " - твоя цель.")
	
	StartDelayedDamage(target)
	
	target:SetNWBool("can_be_gf_scared", true)
	
	hook.Add("SetupPlayerVisibility", "fh_seenet_dontdraw_pvs", function(player)
		if player ~= ply and player ~= target then
			AddOriginToPVS(ply:GetPos())
			AddOriginToPVS(target:GetPos())
		end
	end)
	
	hook.Add("SetupPlayerVisibility", "fh_seenet_dontdraw_pvs_everyone", function(ployer)
		if ployer == ply or ployer == target then
			for _, kent in player.Iterator() do
				AddOriginToPVS(kent:GetPos())
			end
		end
	end)
	
	-- никто не видит их
	for _, player in player.Iterator() do
		if player ~= ply and player ~= target and player:Team() ~= TEAM_SPECTATOR and player:Alive() then
			net.Start("fh_dontdraw_player")
			net.WritePlayer(target)
			net.Send(player)
			
			net.Start("fh_dontdraw_anim")
			net.WriteEntity(ent)
			net.Send(player)
		end
	end
	
	timer.Simple(5, function()
		hook.Remove("SetupPlayerVisibility", "fh_seenet_dontdraw_pvs")
		hook.Remove("SetupPlayerVisibility", "fh_seenet_dontdraw_pvs_everyone")
	end)
	
	ply:SetPushImmune(true)
	ply:SetPushBlocked(true)
	target:SetPushImmune(true)
	target:SetPushBlocked(true)
	
	target:SetAudible(false)
	ply:ForceListenPlayer(target)
	
	target:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
	target:SetCustomCollisionCheck(true)
	target:SetRunSpeed(240)
	target:SetWalkSpeed(120)
	target:SetJumpBoostMultiplier(0)
	target:SetFOV(75, 0, game.GetWorld())
	
	target._LastGFPlushie = CurTime()
	
	net.Start("fh_net_wgfreddy_scarysound")
	net.WriteBool(true)
	net.WritePlayer(ply)
	net.Send(target)
	
	if target:HasWeapon("weapon_crapvidcam") then
		target:StripWeapon("weapon_crapvidcam")
	end
	
	local timer_name = "plushie_hint_" .. ply:EntIndex()
	
	timer.Create(timer_name, 20, 0, function()
		if !IsValid(ply) or !IsValid(target) then
			timer.Remove(timer_name)
			return 
		end
	
		local plushies = ents.FindByClass("fh_plushie")
	
		if #plushies == 0 then
			timer.Remove(timer_name)
			return
		end
	
		local allFar = true
		local closestPlushie = nil
		local closestDistance = math.huge
	
		for _, plushie in ipairs(plushies) do
			if not IsValid(plushie) then continue end
	
			local dist = plushie:GetPos():Distance(target:GetPos())
	
			if dist <= 1400 then
				allFar = false
				break
			end
	
			if dist < closestDistance then
				closestDistance = dist
				closestPlushie = plushie
			end
		end
	
		if allFar and IsValid(closestPlushie) then
			net.Start("fh_pos_sound_play")
			net.WriteString("fnaf2/gfreddy/plushie_hint.mp3")
			net.WriteVector(closestPlushie:GetPos())
			net.Send(target)
		end
	end)
	
	wgfreddy_targets[ply] = target
	outworld_victims[target] = ply
	outworld_victims_count[target] = 0
	
	net.Start("fh_wgfreddy_target_outworld_start")
	net.WritePlayer(ply)
	net.Send(target)
	
	hook.Run("FH_OutworldStart", ply, target)
end

local first_damage_received = {}

function cancel_outworld(ply)
	if wgfreddy_targets[ply] then
		local target = wgfreddy_targets[ply]
	
		cancel_outworld_wgfreddy(ply)
		cancel_outworld_target(target)
		StopDelayedDamage(target)
		killPlushies(target)
	
		target:SetNWBool("can_be_gf_scared", false)
		return
	end
		
	net.Start('fh_sound_stop')
	net.WriteString('fnaf2/gfreddy/gfreddy_enraged.wav')
	net.Broadcast()
	
	if outworld_victims[ply] then
		cancel_outworld_target(ply)
		StopDelayedDamage(ply)
		killPlushies(ply)
		ply:SetNWBool("can_be_gf_scared", false)
		
		for wgfreddy, target in pairs(wgfreddy_targets) do
			if target == ply then
				cancel_outworld_wgfreddy(wgfreddy)
			end
		end
	end
	
	hook.Run("FH_OutworldEnd", ply)

	outworld_victims[ply] = nil
	wgfreddy_targets[ply] = nil
	first_damage_received[ply] = nil
end

hook.Add( "SetupPlayerVisibility", "fh_pvs_wgfreddy_target", function( ply, viewEntity )
	for player,v in pairs( outworld_victims ) do
		if player ~= ply then
			AddOriginToPVS(player:GetPos())
		end
	end
end )

hook.Add("FH_ShouldPlayerReceiveGifts", "no_outworld_gifts", function(ply)
	if outworld_victims[ply] then
		return false
	end
end)

hook.Add("FH_PlayerShouldHearVoiceline", "no_outworld_voicelines", function(ply)
	if outworld_victims[ply] or wgfreddy_targets[ply] then
		return false
	end
end)

local DamageTimers = {}

function StartDelayedDamage(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local steamID = ply:SteamID()
    
    if DamageTimers[steamID] then return end

    timer.Simple(10, function()
        if not IsValid(ply) or !outworld_victims[ply] then return end

        local timerName = "DamagePlayer_" .. steamID
        DamageTimers[steamID] = timerName

        timer.Create(timerName, 2, 0, function()
            if not IsValid(ply) or !outworld_victims[ply] then
                StopDelayedDamage(ply)
                return
            end

            if ply._damagePausedUntil and CurTime() < ply._damagePausedUntil then
                return
            end
			
			local playerIsHealthy = ply:Health() > 100 
				or ply:Armor() > 10 
				or (timer.Exists("EndGameTimer") and timer.TimeLeft("EndGameTimer") < 180)
				or (ply._LastGFPlushie and ply._LastGFPlushie < CurTime() - 60)
				
			--print(ply._LastGFPlushie, CurTime(), CurTime() - 60)

            local dmg = DamageInfo()
            dmg:SetDamage(playerIsHealthy and 2 or 1)
            dmg:SetAttacker(game.GetWorld())
            dmg:SetDamageType(DMG_GENERIC)
            ply:TakeDamageInfo(dmg)
        end)
    end)
end

function PauseDamage(ply, duration)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply._damagePausedUntil = CurTime() + duration
end

function StopDelayedDamage(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local steamID = ply:SteamID()
    local timerName = DamageTimers[steamID]

    if timerName then
        timer.Remove(timerName)
        DamageTimers[steamID] = nil
    end

    ply._damagePausedUntil = nil
end

if SERVER then
	local gfreddy_enraged_movement = {130, 560, 130, 250}
	net.Receive("cl_target_wgfreddy_scared", function( len, ply )
		if outworld_victims[ply] and ply:Alive() then
			local wgfreddy = outworld_victims[ply]
		
            ply:TakeDamage( math.min(ply:Health() / 2, 20), wgfreddy, wgfreddy:GetActiveWeapon() )
			
			if !first_damage_received[ply] then
				net.Start("wgfreddy_second_ambience")
				net.Send(ply)
			end
			
			first_damage_received[ply] = true
			
			local ent = pills.getMappedEnt(wgfreddy)
			
			if !IsValid(ent) then return end
			
			if ply:Health() < 30 then
				StopDelayedDamage(ply)
				
				if ent.cloaked then
					ply:DrawViewModel(true)
					
					ent:SetMaterial()
					ent:DrawShadow(true)
						
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
					ply:SetCustomCollisionCheck(true)
					ply:CollisionRulesChanged()
								
					ent.cloaked=false
					timer.Simple(0.5, function()
						if IsValid(wgfreddy) and wgfreddy:IsStuck() then
							wgfreddy:Unstuck()
						end
					end)
				end
				
				wgfreddy:SetNWBool("wgfreddy_enraged", true)
				ent:SetSpeed(unpack(gfreddy_enraged_movement))
				ent:PillAnim("rage",true)
				ply:SetNWBool("can_be_gf_scared", false)
				
				net.Start("fh_ui_sound_play")
				net.WriteString('fnaf2/gfreddy/gfreddy_rage_start.wav')
				net.Send({ply, wgfreddy})
				
				ply:SetJumpBoostMultiplier(getScaledJumpBoost())
				ply:SetRunSpeed(420)
				ply:SetWalkSpeed(200)
				
				timer.Simple(10, function()
					if IsValid(ent) and IsValid(ply) then
						
						net.Start('fh_ent_sound_play')
						net.WritePlayer(ply)
						net.WriteString('fnaf2/gfreddy/gfreddy_enraged.wav')
						net.Send({ply, wgfreddy})
					end
				end)
				
				return
			end
			
			if not ent.cloaked then
			
				if fh_can_see_player(wgfreddy_targets[wgfreddy], wgfreddy, 1500) then
					wgfreddy_targets[wgfreddy]:ScreenFade(SCREENFADE.IN, Color(0,0,0), 1, 0.5)
					
					EmitSound("gfreddy.laugh", wgfreddy:GetPos())
				end
				
				cooldown.Set(wgfreddy, 'appear', 12)
				
				net.Start("fh_net_killer_change")
				net.WriteString("submerge")
				net.WriteFloat(12)
				net.Send(wgfreddy)
				
				ent:SetSpeed(unpack(sfreddy_noclip_movement))
				wgfreddy:DrawViewModel(false)

				ent:SetMaterial("models/null")
				ent:DrawShadow(false)

				wgfreddy:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				wgfreddy:SetCustomCollisionCheck(true)
				wgfreddy:CollisionRulesChanged()

				ent.cloaked = true
			end
			
			net.Start("fh_play_sound")
			net.WriteString("fnaf2/gfreddy/gfreddy_success_scare.wav")
			net.Send(wgfreddy)
			
			PauseDamage(ply, 10)
		end
	end)
end