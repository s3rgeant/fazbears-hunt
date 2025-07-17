AddCSLuaFile()

function fh_spawnPlushies(ply)
	if !IsValid(ply) then return end

	local origin = ply:GetPos()
	local minDistFromPlayer = 800
	local maxDistFromPlayerStrict = 2500
	local maxDistFromPlayerLoose = 2000
	local minSpacing = 2000
	local plushCount = 4
	local placed = 0
	local usedPositions = {}
	
	local function isWithinStrictRange(pos)
		local distSqr = origin:DistToSqr(pos)
		return distSqr >= minDistFromPlayer^2 and distSqr <= maxDistFromPlayerStrict^2
	end
	
	local function isFarFromOthers(pos)
		for _, used in ipairs(usedPositions) do
			if used:DistToSqr(pos) < minSpacing^2 then
				return false
			end
		end
		return true
	end
	
	local function isLooseCandidate(pos)
		return origin:DistToSqr(pos) <= maxDistFromPlayerLoose^2
	end
	
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
	
	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then
		print("[fh_plushie] Нет nav-меша.")
		return
	end
	
	table.Shuffle(areas)
	
	for _, area in ipairs(areas) do
		if placed >= plushCount then break end
		if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
	
		local pos = area:GetCenter()
		if isWithinStrictRange(pos) and isFarFromOthers(pos) then
			spawnPlushAt(pos)
		end
	end
	
	if placed < plushCount then
		for _, area in ipairs(areas) do
			if placed >= plushCount then break end
			if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
	
			local pos = area:GetCenter()
			if isLooseCandidate(pos) then
				spawnPlushAt(pos)
			end
		end
	end
	
	if placed < plushCount then
		print("[fh_plushie] Не удалось заспавнить 3 плюшки. Заспавнено: " .. placed)
	else
		print("[fh_plushie] Успешно заспавнены 3 плюшки.")
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
	hook.Add( "CanPlayerSuicide", "fh_pill2_suicide", function( ply )
		if outworld_victims[ply] then
			return false
		end
	end )
end

if CLIENT then
	local mat_Grayscale = Material( "effects/shaders/merc_grayscale" )
	
	local outworld_ambient = outworld_ambient or nil
	
	local outworlded_ppl = {}
	
	hook.Add("PrePlayerDraw", "fh_dontdraw_outworlded" , function(ply)
		if outworlded_ppl[ply] then
			return true
		end
	end)
	hook.Add( "PlayerFootstep", "fh_nosteps_outworlded", function( ply, pos, foot, sound, volume, rf )
		if outworlded_ppl[ply] then
			return true
		end
	end)
	
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
					ent.dontdraw = true
				end
			end
		end
		hook.Add("PrePlayerDraw", "fh_outworld_pv", function(ply)
			if ply ~= myself then
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
	end)
	
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
				ent.dontdraw = false
			end
		end
		hook.Remove("PrePlayerDraw", "fh_outworld_pv")
		hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
		hook.Remove("NeedsDepthPass", "merc_grayscale_depth")
		hook.Remove("SetupWorldFog", "WhiteFogEffect")
		hook.Remove("SetupSkyboxFog", "WhiteFogEffectSkybox")
		hook.Remove("RenderScreenspaceEffects", "merc_videoglitch_hook")
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
					ent.dontdraw = true
				end
			end
		end
		hook.Add("PrePlayerDraw", "fh_gfreddy_outworld_pv", function(ply)
			if ply ~= target then
				return true
			end
		end)
	end)
	
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
				ent.dontdraw = false
			end
		end
		
		fh_cl_dontdraw_plushies()
	end)
	
	net.Receive("fh_dontdraw_player", function()
		local dude = net.ReadPlayer()
		
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
	
	net.Receive("fh_dontdraw_anim", function()
		local ent = net.ReadEntity()
		
		ent.dontdraw = true
	end)
	
	net.Receive("fh_draw_player", function()
		local dude = net.ReadPlayer()
		
		outworlded_ppl[dude] = false
		
		dude:SetNoDraw(false)
        dude:DrawShadow(true)
		
		for _, wep in ipairs(dude:GetWeapons()) do
			if IsValid(wep) then
				wep:SetNoDraw(false)
				wep:DrawShadow(true)
				wep:SetRenderMode(RENDERMODE_NORMAL)
			end
		end
	end)
	
	net.Receive("fh_draw_anim", function()
		local ent = net.ReadEntity()
		
		ent.dontdraw = false
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
		
		fh_cl_dontdraw_plushies()
		
		table.Empty(outworlded_ppl)
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

local function cancel_outworld_target(ply)
	outworld_victims[ply] = nil

	net.Start("fh_draw_player")
	net.WritePlayer(ply)
	net.Broadcast()

	ply:SetJumpBoostMultiplier(1)
	ply:SetRunSpeed(420)
	ply:SetWalkSpeed(200)
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	ply:SetCustomCollisionCheck(true)
	ply:CollisionRulesChanged()
	ply:SetDSP(0)
	ply:SetFOV(0)
	fh_cant_hear[ply] = false
		
	ply:SetPushImmune(false)
	ply:SetPushBlocked(false)

	net.Start("fh_wgfreddy_target_outworld_end")
	net.Send(ply)

	net.Start("fh_adv_sound_play")
	net.WriteString("fnaf2/gfreddy/outworld_escaped.wav")
	net.Send(ply)
end

local sfreddy_noclip_movement = {500, 600, 500, 250}
local function cancel_outworld_wgfreddy(ply)
	wgfreddy_targets[ply] = nil
	
	net.Start("fh_wgfreddy_outworld_stop")
	net.Send(ply)

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

function start_outworld(ply, target)
	net.Start("fh_play_sound")
	net.WriteString('fnaf2/gfreddy/gfreddy_target.wav')
	net.Send(ply)
	
	net.Start("fh_wgfreddy_outworld_start")
	net.WritePlayer(target)
	net.Send(ply)
	
	ply:ChatPrint(target:Nick() .. " - твоя цель.")
	
	table.insert(affectedPlayers, target)
	
	-- никто не видит их
	for _, player in player.Iterator() do
		if player ~= ply and player ~= target and player:Team() != TEAM_SPECTATOR and player:Alive() then
			net.Start("fh_dontdraw_player")
			net.WritePlayer(target)
			net.Send(player)
			
			net.Start("fh_dontdraw_anim")
			net.WriteEntity(ent)
			net.Send(player)
		end
	end
	
	ply:SetPushImmune(true)
	ply:SetPushBlocked(true)
	target:SetPushImmune(true)
	target:SetPushBlocked(true)
	
	fh_cant_hear[target] = true
	target:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
	target:SetCustomCollisionCheck(true)
	target:SetRunSpeed(240)
	target:SetWalkSpeed(120)
	target:SetJumpBoostMultiplier(0)
	target:SetFOV(75)
	
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
	
		if #plushies == 0 then return end
	
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
	
	fh_spawnPlushies(target)
	
	wgfreddy_targets[ply] = target
	outworld_victims[target] = true
	outworld_victims_count[target] = 0
	
	net.Start("fh_wgfreddy_target_outworld_start")
	net.WritePlayer(ply)
	net.Send(target)
end

function cancel_outworld(ply)
	if wgfreddy_targets[ply] then
		cancel_outworld_wgfreddy(ply)
		cancel_outworld_target(wgfreddy_targets[ply])
		killPlushies(wgfreddy_targets[ply])
		return
	end
	
	if outworld_victims[ply] then
		cancel_outworld_target(ply)
		killPlushies(ply)
		
		for wgfreddy, target in pairs(wgfreddy_targets) do
			if target == ply then
				cancel_outworld_wgfreddy(wgfreddy)
			end
		end
	end

	outworld_victims[ply] = nil
	wgfreddy_targets[ply] = nil
end