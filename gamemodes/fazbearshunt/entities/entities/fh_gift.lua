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
end

local giftModel = IsHalloween() and "pumpkin_loot" or "halloween_gift"
local modelScale = (giftModel == "pumpkin_loot") and 1.5 or 1

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
        if CurTime() - self.SpawnTime > 1.5 and (ent:IsPlayer() and !ent:IsBot()) and ent:IsSurvivor() then
			if hook.Run("FH_HandleGiftPickup", self, ent) == false then return end
			
            self.IsUsed = true
            self:ApplyEffect(ent)
            self:Remove()
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
		
			local damageOnlyAnims = killers.getAllDamageOnly()
			
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
    ["killer_mask"] = {
        name = "killer_mask",
		desc = "fazhunt.gifts.killer_mask",
        func = function(ply)
            ply:Give("weapon_killmask")
        end,
        req = function(ply)
			local fuck = false
			for _, ply in player.Iterator() do
				if ply:HasWeapon("weapon_killmask") or ply:HasWeapon("weapon_killer_axe") then
					fuck = true
					break
				end
			end
			
			if not killermask.IsGiftingAllowed() then
				return false
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
            local endPos = startPos + Vector(0, 0, 500)
        
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

function ENT:ApplyEffect(player)
	local isOwner = self:GetOwner() == player
	local effects = {}
	
	for name, effect in pairs(positiveEffects) do
		if effect.req and effect.req(player, self, isOwner) then
			effects[name] = effect
		elseif !effect.req then
			effects[name] = effect
		end
	end
	
	if table.IsEmpty(effects) then
		self:Remove()
		return
	end
	
	local effect = table.Random(effects)
	effect.func(player, self, isOwner)
	
	local isPositive = false
	for name, posEffect in pairs(effects) do
		if positiveEffects[name] == effect then
			isPositive = true
			break
		end
	end
	
	if !effect.silent then
		if isPositive then
			self:EmitSound("orch_hit_csharp_short.wav")
		else
			self:EmitSound("ahuitebe.mp3")
		end
	end
		
	net.Start('fh_net_display')
	net.WriteString('fazhunt.gifts.' .. (isPositive and 'positive' or 'negative'))
	net.WriteString(effect.desc or "")
	net.WriteFloat(effect.num or -1)
	net.WriteFloat(5)
	net.Send(player)
end