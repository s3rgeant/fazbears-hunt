AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "FH Gift"
ENT.Author = "sergeant"
ENT.Spawnable = true
ENT.Category = "Fun + Games"

if SERVER then
    util.AddNetworkString("fh_hl_badkid")
    util.AddNetworkString("fh_hl_animatronics")
    util.AddNetworkString("fh_net_thinkfast")
    util.AddNetworkString("fh_gift_notify")
end

local giftModel = IsHalloween() and "pumpkin_loot" or "halloween_gift"
local modelScale = (giftModel == "pumpkin_loot") and 1.5 or 1

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Boosted")
end

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_halloween/" .. giftModel .. ".mdl")
		self:SetModelScale(modelScale)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		self:SetTrigger(true)
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 32))
        self:EmitSound("items/battery_pickup.wav")
        self.IsUsed = false
    end
    self.SpawnTime = CurTime()
	
	local owner = self:GetOwner()
	if IsValid(owner) then
		local ground = owner:GetGroundEntity()
		if IsValid(ground) and ground:GetClass() == "func_tracktrain" then
			self:SetParent(ground)
		end
	end
end

if SERVER then
    function ENT:Think()
        return true
    end

    function ENT:Touch(ent)
        if self.IsUsed then return end
		local isOwner = ent == self:GetOwner()
		local curtime = CurTime()
		
        if isOwner and curtime - self.SpawnTime >= 1.3 or curtime - self.SpawnTime >= 2 then 
			if (ent:IsPlayer() and !ent:IsBot()) and ent:IsSurvivor() then
				if hook.Run("FH_HandleGiftPickup", self, ent) == false then return end
				
				self.IsUsed = true
				self:ApplyEffect(ent, self:GetBoosted() and 2 or 1)
				self:Remove()
			end
        end
    end
	
	function ENT:OnRemove()
		if IsValid( self:GetOwner() ) then
			self:GetOwner():SetGiftOwnership(false)
		end
	end
end

if CLIENT then

	function ENT:RenderOverride(flags)
		local basePos = self:GetPos()

		local height = math.sin((CurTime() - self.SpawnTime) * 2) * 5
		local renderPos = basePos + Vector(0, 0, height)

		local ang = self:GetAngles()
		ang.y = ang.y + ((CurTime() * 140) % 360)

		self:SetRenderOrigin(renderPos)
		self:SetRenderAngles(ang)

		self:DrawModel()

		self:SetRenderOrigin()
		self:SetRenderAngles()

		if IsValid(self:GetOwner()) then
			local distance = LocalPlayer():GetPos():Distance(basePos)
			if distance <= 1000 then
				local a = LocalPlayer():EyeAngles()
				a:RotateAroundAxis(a:Forward(), 90)
				a:RotateAroundAxis(a:Right(),   90)

				cam.Start3D2D(basePos + Vector(0,0,65 + height), Angle(0, a.y, 90), 0.25)
					draw.SimpleText(
						string.format(language.GetPhrase("fazhunt.gifts.owner"), self:GetOwner():Nick()),
						"timerFontUpper",
						0, 0,
						Color(255,255,255),
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
					)
				cam.End3D2D()
			end
		end
	end
	
	local overlayMat = Material("models/props_combine/portalball001_sheet")

	function ENT:Draw()
		self:DrawModel()

		if self:GetBoosted() then
			render.MaterialOverride(overlayMat)
			render.SetBlend(.8)
			self:DrawModel()
			render.MaterialOverride()
			render.SetBlend(1)
		end
	end
end

local PLAYER = FindMetaTable("Player")

if PLAYER then
	function PLAYER:SetGiftOwnership(bool)
		self:SetNWBool("GiftOwnership", bool or false)
	end
	
	function PLAYER:GetGiftOwnership()
		return self:GetNWBool("GiftOwnership", false)
	end
end

gifts = gifts or {}

local effectDesc = ''
local format_num = -1

-- Позитивные эффекты
local positiveEffects = {
	["medkit"] = {
		name = "medkit",
		desc = "fazhunt.gifts.medkit",
		func = function(ply)
			if !ply:HasWeapon("weapon_fh_medkit") then
				ply:Give("weapon_fh_medkit")
			else
				local wep = ply:GetWeapon( "weapon_fh_medkit" )
				
				if IsValid(wep) then
					wep:SetClip1( wep:Clip1() + 25 )
				end
			end
		end,
		req = function(ply)
			if ply:Health() < 85 then
				return true
			end
		
			local damageOnlyAnims = killers.GetAllDamageOnly()
			
			for k, v in pairs(damageOnlyAnims) do
				if fh.GetActiveUsedKiller(k) then
					return true
				end
			end
			return false
		end
	},
	["invisibility"] = {
		name = "invisibility",
		desc = "fazhunt.gifts.invisibility",
		func = function(ply)
			ply:Give("weapon_mask")
		end,
		req = function(ply)
			return ( !isGameOn or fh.timer.Exists() and fh.timer.GetTimeLeft() >= 120 )
			and !ply:HasWeapon("weapon_mask")
		end
	},
	["gravity_gun"] = {
		name = "gravity_gun",
		desc = "fazhunt.gifts.gravity_gun",
		func = function(ply)
			ply:Give("weapon_physcannon")
		end,
		req = function(ply)
			return !ply:HasWeapon("weapon_physcannon") and #ents.FindByClass("prop_physics") > 100
		end
	},
	["defibrilator"] = {
		name = "defibrilator",
		desc = "fazhunt.gifts.defibrillator",
		func = function(ply)
			ply:Give("weapon_defibrillator")
		end,
		req = function(ply)
			if team.NumPlayers(TEAM_SPECTATOR) ~= 0 then
				if !ply:HasWeapon("weapon_defibrillator") then
					return true
				end
				return false
			end
			return false
		end
	},
	["bananas"] = {
		name = "bananas",
		desc = "fazhunt.gifts.bananas",
		num = 5,
		func = function(ply)
			local toGive = 4
			
			if ply:HasWeapon("weapon_banana") then
				toGive = 5
			end
			
			ply:Give("weapon_banana")
			
			ply:SetSuppressPickupNotices(true)
			ply:GiveAmmo(toGive, "ammo_banana", true)
			ply:SetSuppressPickupNotices(false)
		end
	},
	["adrenaline"] = {
		name = "adrenaline",
		desc = "fazhunt.gifts.adrenaline",
		func = function(ply)
			ply:Give("weapon_adrenaline")
		end,
		req = function(ply)
			return !ply:HasWeapon("weapon_adrenaline")
		end
	},
	["fanta"] = {
        name = "fanta",
		desc = "fazhunt.gifts.fanta",
        func = function(ply)
            ply:Give("weapon_fanta")
        end,
        req = function(ply)
			if !ply:HasWeapon("weapon_fanta") then
				if fh.GetActiveUsedKiller("pill_wfoxy2") or fh.GetActiveUsedKiller("pill_sfreddy2") or fh.GetActiveUsedKiller("pill_mangle") or fh.GetActiveUsedKiller("pill_clown") then
					return true
				end
			end
			return false
        end
    },
	["killer_mask"] = {
		name = "killer_mask",
		desc = "fazhunt.gifts.killer_mask",
		func = function(ply)
			ply:Give("weapon_killmask")
		end,
		req = function(ply)
			if not killermask.IsGiftingAllowed() then
				return false
			end
			
			local fuck = false
			for _, ply in player.Iterator() do
				if ply:HasWeapon("weapon_killmask") or ply:HasWeapon("weapon_killer_axe") then
					fuck = true
					break
				end
			end
			
			
			if fuck then
				return false
			end
		
			local animCount = team.NumPlayers(2701)
			
			if fh.GetActiveUsedKiller("pill_plushtrap") then
				animCount = math.max(animCount - 1, 1)
			end
		
			if animCount > 1 and math.random(1,10) == 1 then
				if !ply:HasWeapon("weapon_killmask") then
					return true
				end
			end
			return false
		end
	},
	["crucifix"] = {
		name = "crucifix",
		desc = "fazhunt.gifts.crucifix",
		func = function(ply)
			ply:Give("weapon_crucifix")
		end,
		req = function(ply)
			return not ply:HasWeapon("weapon_crucifix")
		end
	},
	["oldshotgun"] = {
		name = "oldshotgun",
		desc = "fazhunt.gifts.oldshotgun",
		func = function(ply)
			ply:Give("weapon_oldshotgun")
			
			local buckshotAmmo = ply:GetAmmoCount(7)
			if buckshotAmmo < 12 then
				ply:GiveAmmo(12 - buckshotAmmo, "buckshot", true)
			end
			
			ply:GiveAmmo(4 * team.NumPlayers(TEAM_PILLS), "buckshot", true)
		end,
		req = function(ply)
			return not ply:HasWeapon("weapon_oldshotgun")
		end
	},
	["tablet"] = {
		name = "tablet",
		desc = "fazhunt.gifts.tablet",
		func = function(ply)
			ply:Give("weapon_tablet")
		end,
		req = function(ply)
			return not ply:HasWeapon("weapon_tablet")
		end
	},
	["detector"] = {
		name = "detector",
		desc = "fazhunt.gifts.detector",
		func = function(ply)
			ply:Give("weapon_detector")
		end,
		req = function(ply)
			return not ply:HasWeapon("weapon_detector")
		end
	},
	["dummy"] = {
		name = "dummy",
		desc = "fazhunt.gifts.dummy",
		func = function(ply)
			local pos = ply:GetPos()
			local ang = ply:GetAngles()
			ang.p = 0
			
			dummy = ents.Create("fh_dummy")
			dummy:SetPos(pos+Vector(0,0,1))
			dummy:SetAngles(ang)
			dummy:SetOwner(ply)
			dummy:Spawn()
		end,
		req = function(ply)
			return not ply:GetDummy()
		end
	},
	["jammer"] = {
		name = "jammer",
		desc = "fazhunt.gifts.jammer",
		func = function(ply)
			ply:Give("weapon_jammer")
		end,
		req = function(ply)
			return not ply:HasWeapon("weapon_jammer")
		end
	},
}

-- Негативные эффекты
local negativeEffects = {
    ["spawn_car"] = {
		desc = "",
        func = function(ply)
            local playerPos = ply:GetPos()
            local playerHeight = ply:OBBMaxs().z - ply:OBBMins().z
        
            local car = ents.Create("prop_physics")
            car:SetModel("models/props_vehicles/truck001a.mdl")
        
            local carMins, carMaxs = car:GetCollisionBounds()
            local carHeight = carMaxs.z - carMins.z
        
            local startPos = playerPos + Vector(0, 0, playerHeight + (carHeight / 2) + 10)
            local endPos = startPos + Vector(0, 0, 400)
        
            local tr = util.TraceHull({
                start = startPos,
                endpos = endPos,
                filter = {ply, car},
                mins = carMins,
                maxs = carMaxs
            })
        
            local spawnPos
            if tr.Hit then
                spawnPos = tr.HitPos
            else
                spawnPos = endPos
            end
        
            car:SetPos(spawnPos)
            car:Spawn()
            car:Activate()
			
			local phys = car:GetPhysicsObject()
			
			if IsValid(phys) then
				phys:SetVelocity(-car:GetUp() * 2000)
			end
        
            timer.Simple(10, function()
                if IsValid(car) then
                    car:Remove()
                end
            end)
        end
    },
    ["animatronics_alert"] = {
		desc = "fazhunt.gifts.animatronics_alert",
        func = function(ply)
			local sendies = team.GetPlayers( TEAM_PILLS )
			table.insert(sendies, ply)
		
            net.Start("fh_hl_badkid")
            net.WriteEntity(ply)
            net.Send(ply)
			
			for _, player in player.Iterator() do
				if player:Team() == TEAM_PILLS then
					highlight.Add(player, ply)
				end
			end
        end
    },
    ["reduce_step"] = {
		desc = "fazhunt.gifts.reduce_step",
        func = function(ply)
            ply:SetStepSize(0)
        end
    },
    ["strip_weapons"] = {
		desc = "fazhunt.gifts.strip_weapons",
        func = function(ply)
            ply:StripWeapons()
        end
    },
    ["thinkfast"] = {
		desc = "",
        func = function(ply)
            net.Start('fh_net_thinkfast')
            net.Send(ply)
        end
    },
    ["fov_buff"] = {
		desc = "fazhunt.gifts.fov_buff",
		num = 30,
        func = function(ply)
            ply:SetFOV(30, 1)
            ply:SetCanZoom(false)
            ply:StopZooming()
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetFOV(0, 1)
                    ply:SetCanZoom(true)
                end
            end)
        end
    },
    ["sound_dsp"] = {
		desc = "fazhunt.gifts.sound_dsp",
		num = 30,
        func = function(ply)
            ply:SetDSP(31, false)
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetDSP(1, false)
                end
            end)
        end
    },
    ["vanish"] = {
		desc = "",
		silent=true,
        func = function(ply)
			local pos = ply:GetPos()
			local ang = ply:GetAngles()
			
			local ragdoll
			
			if ply:GetModel() == "models/player/skeleton.mdl" then
				local effectdata = EffectData()
				effectdata:SetOrigin(pos+Vector(0,0,16))
				effectdata:SetScale(1)
				util.Effect("Explosion", effectdata, true, true)
			else
				ragdoll = ents.Create("prop_ragdoll")
				ragdoll:SetModel("models/player/skeleton.mdl")
				ragdoll:SetPos(pos)
				ragdoll:SetAngles(ang)
				ragdoll:Spawn()
				ragdoll:Activate()
				--ragdoll:SetOwner(ply)
				
				ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
				ragdoll:SetCustomCollisionCheck( true )
				
				local plyvel = ply:GetVelocity()

				for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
					local bone = ragdoll:GetPhysicsObjectNum(i)
					
					if bone and bone:IsValid() then
						local bonepos, boneang = ply:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
						
						if bonepos and boneang then
							bone:SetPos(bonepos)
							bone:SetAngles(boneang)
							bone:SetVelocity(plyvel)
						end
					end
				end
				
				timer.Simple(0, function()
					local bones = ragdoll:GetPhysicsObjectCount()
					for bone = 1, bones - 1 do
						
						local constr = constraint.Weld( ragdoll, ragdoll, 0, bone, 0 )
						local effectdata = EffectData()
						effectdata:SetOrigin( ragdoll:GetPhysicsObjectNum( bone ):GetPos() )
						effectdata:SetScale( 1 )
						effectdata:SetMagnitude( 1 )
						util.Effect( "GlassImpact", effectdata, true, true )

					end
				end)
				
				ragdoll:EmitSound("lobotomy.mp3")
			end
			
            ply:KillSilent()
			
			ply:SpectateEntity(ragdoll)
			ply:Spectate(OBS_MODE_CHASE)
        end
    },
    ["bearling_attack"] = {
		desc = "",
        func = function(ply)
			local bearlings = {}
			for i = 1,5 do
			
				local bearling = ents.Create("bearling")
				if not IsValid(bearling) then return end
				
				bearling:SetPos(ply:GetPos())
				bearling:Spawn()
				bearling:Activate()
				
				bearling:SetTarget(ply)
				
				bearlings[bearling] = true
			end
			
			timer.Simple(60, function()
				for bear, _ in pairs(bearlings) do
					if IsValid(bear) then
						bear:Remove()
					end
				end
			end)
        end,
		req = function(ply)
			return navmesh.IsLoaded()
		end,
    },
}

if SERVER then
	function gifts.AddPositiveEffect(name, desc, num, func, req)
		positiveEffects[name] = {
			desc = desc or "",
			num = num or -1,
			func = func,
			req = req or nil,
		}
	end
	
	function gifts.SetBlockPositiveEffect(name, bool)
		if positiveEffects[name] then
			positiveEffects[name].blocked = bool
		end
	end
	
	function gifts.AddNegativeEffect(name, desc, num, func, req)
		negativeEffects[name] = {
			desc = desc or "",
			num = num or -1,
			func = func,
			req = req or nil,
		}
	end
	
	function gifts.GrantEffect(ply, name)
		if IsValid(ply) and ply:IsPlayer() then
			if positiveEffects[name] then
				positiveEffects[name].func(ply)
			end
		end
	end
end

function ENT:ApplyEffect(player, amount)
	local isOwner = self:GetOwner() == player
	local isPositive = true
	amount = amount or 1
	
	if !isOwner then
		isPositive = math.random(1,2) == 1
	end
	
	local effects = {}
	
	if isPositive then
		for name, effect in pairs(positiveEffects) do
			if effect.blocked then continue end
			if effect.req and effect.req(player, self, isOwner) then
				effects[name] = effect
			elseif !effect.req then
				effects[name] = effect
			end
		end
	else
		for name, effect in pairs(negativeEffects) do
			effects[name] = effect
		end
	end
	
	if table.IsEmpty(effects) then
		self:Remove()
		return
	end
	
	local receivedEffects = {}
	local isSilent = false
	
	for i = 1, amount do
		if table.Count(effects) <= 0 then break end
		
		local effect, name = table.Random(effects)
		effect.func(player, self, isOwner)
		
		if effect.silent then isSilent = true end
		
		effects[name] = nil
		table.insert(receivedEffects, effect)
	end
	
	
	if not isSilent then
		if isPositive then
			self:EmitSound("orch_hit_csharp_short.wav")
		else
			self:EmitSound("ahuitebe.mp3")
		end
	end
		
	net.Start('fh_gift_notify')
		net.WriteString('fazhunt.gifts.' .. (isPositive and 'positive' or 'negative'))
	
		for i = 1, #receivedEffects do
			local effect = receivedEffects[i]
		
			net.WriteString(effect.desc or "")
			net.WriteFloat(effect.num or -1)
			net.WriteBit(i < #receivedEffects)
		end
		
		net.WriteFloat(5)
	net.Send(player)
end

if CLIENT then
	--local gift_bar = Material("vgui/base/gift_bar.png")
	--local gift_bar_w = gift_bar:Width()
	--local gift_bar_h = gift_bar:Height()
	
	local gift_status_bar = Material("vgui/base/gift_status_bar.png")
	local gift_status_bar_w = gift_status_bar:Width()
	local gift_status_bar_h = gift_status_bar:Height()
	
	local gift_desc_bar = Material("vgui/base/gift_desc_bar.png")
	local gift_desc_bar_w = gift_desc_bar:Width()
	local gift_desc_bar_h = gift_desc_bar:Height()
	
	local gift_spin = Material("vgui/gift_spin")
	local gift_spin_w = gift_spin:Width()
	local gift_spin_h = gift_spin:Height()
	
	local gifts_color = Color(255,195,0)
	
	-- текст смешной сверху
	surface.CreateFont("GiftUpper", {
		font = "Share Tech Mono",
		shadow = true,
		extended = true,
		antialias = true,
		size = 40,
		weight = 700
	})

	surface.CreateFont("GiftMiddle", {
		font = "Share Tech Mono",
		shadow = true,
		extended = true,
		antialias = true,
		size = 32,
		weight = 500
	})

	surface.CreateFont("GiftSmall", {
		font = "Share Tech Mono",
		shadow = true,
		extended = true,
		antialias = true,
		size = 26,
		weight = 500
	})

	function DisplayGiftNotify(status, text2, duration, smallerFont)
		local displayText1 = status
		local displayText2 = text2
		local duration = duration
		local startTime = CurTime()
		
		local secondFont = smallerFont and "GiftSmall" or "GiftMiddle"
		local giftColor = gifts_color:Copy()
		
		hook.Add("HUDPaint", "fh_gift_notify", function()
			if GetConVar("cl_drawhud"):GetBool() then
				local elapsedTime = CurTime() - startTime
				local alpha = 255

				if elapsedTime > duration then
					local fadeDuration = 1
					local fadeTime = elapsedTime - duration
					if fadeTime < fadeDuration then
						alpha = 255 * (1 - fadeTime / fadeDuration)
					else
						hook.Remove("HUDPaint", "fh_gift_notify")
						return
					end
				end
				
				local scrW = ScrW()
				local scrH = ScrH()
				
				local halfW = scrW * .5
				
				local status_w = gift_status_bar_w
				local w = status_w
				local status_h = gift_status_bar_h
				local h = status_h
				
				local status_y = scrH - 372
	
				surface.SetMaterial( gift_status_bar )
				surface.SetDrawColor( 255, 255, 255, alpha )
				surface.DrawTexturedRect( halfW - w*.5, status_y, w, gift_status_bar_h ) --768
				
				--text

				surface.SetFont("GiftUpper")
				surface.SetTextColor(255, 255, 255, alpha)

				local w, h = surface.GetTextSize(displayText1)
				local x = halfW - w * .5
				local y = scrH - 342 - h * .5

				surface.SetTextPos(x, y)
				surface.DrawText(displayText1)
				
				if displayText2 and displayText2:len() > 0 then
					local w = gift_desc_bar_w
				
					local desc_y = status_y + h + 32
					
					local w2, h2 = surface.GetTextSize(displayText2)
					local x2 = halfW
					
					local gift_desc_w = math.max(w, w2*.8)
		
					surface.SetMaterial( gift_desc_bar )
					surface.SetDrawColor( 255, 255, 255, alpha )
					surface.DrawTexturedRect( halfW - gift_desc_w*.5, desc_y, gift_desc_w, gift_desc_bar_h )
					
					giftColor.a = alpha
					
					draw.DrawText( displayText2, secondFont, x2, desc_y + (gift_desc_bar_h*.5 - h2*.45), giftColor, TEXT_ALIGN_CENTER )
				end
				
				-- gift spins
				
				local s = 48
	
				surface.SetMaterial( gift_spin )
				surface.SetDrawColor( 255, 255, 255, alpha )
				surface.DrawTexturedRect( halfW - s*.5 - 290, scrH - 342 - s * .5, s, s )
	
				surface.SetMaterial( gift_spin )
				surface.SetDrawColor( 255, 255, 255, alpha )
				surface.DrawTexturedRect( halfW - s*.5 + 290, scrH - 342 - s * .5, s, s )
				
			end
		end)
	end
	
	local fullString
	local function getGiftNotifyText()
		
		local text2 = net.ReadString()
		local frmt = net.ReadFloat() or -1
		
		if text2:len() > 0 then text2 = language.GetPhrase(text2) end
		
		if frmt > 0 then
			text2 = string.format(tostring(text2), frmt)
		end
		
		if not fullString then
			fullString = text2
		else
			fullString = fullString .. "\n" .. text2
		end
		
		local goNext = net.ReadBit()
		
		if goNext == 1 then
			return getGiftNotifyText()
		else
			return fullString
		end
		return "?"
	end

	net.Receive("fh_gift_notify", function()
		fullString = nil
		
		local text1 = net.ReadString()
		if text1:len() > 0 then text1 = language.GetPhrase(text1) end
		
		local text2 = getGiftNotifyText()
		
		local duration = net.ReadFloat()
		DisplayGiftNotify(text1, text2, duration)
	end)

	concommand.Add("fh_test_gift", function(ply, cmd, args)
		if ply:IsAdmin() then
			local text1 = args[1] or "Hello"
			local text2 = args[2] or "World"
			local duration = tonumber(args[3]) or 5
			
			DisplayGiftNotify(text1, text2, duration)
		end
	end)
end