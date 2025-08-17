AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "FH Gift"
ENT.Author = "sergeant"
ENT.Spawnable = true
ENT.Category = "Fun + Games"

ENT.InitialZ = 0

if SERVER then
    util.AddNetworkString("fh_hl_badkid")
    util.AddNetworkString("fh_hl_animatronics")
    util.AddNetworkString("fh_net_thinkfast")
end

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_halloween/halloween_gift.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
        self:SetTrigger(true)
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 32))
        self:EmitSound("items/battery_pickup.wav")
        self.IsUsed = false
    end
    self.InitialZ = self:GetPos().z
    self.SpawnTime = CurTime()
end

if SERVER then
    function ENT:Think()
        return true
    end

    function ENT:Touch(ent)
        if self.IsUsed then return end
        if CurTime() - self.SpawnTime > 1.5 and (ent:IsPlayer() and !ent:IsBot()) and ent:IsSurvivor() then
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
    function ENT:Draw()
        self:DrawModel()
        if IsValid(self:GetOwner()) then
            local distance = LocalPlayer():GetPos():Distance(self:GetPos())
            if distance <= 1300 then
                local ang = LocalPlayer():EyeAngles()
                ang:RotateAroundAxis(ang:Forward(), 90)
                ang:RotateAroundAxis(ang:Right(), 90)
                
                cam.Start3D2D(self:GetPos() + Vector(0, 0, 65), Angle(0, ang.y, 90), 0.25)
                draw.SimpleText(string.format( language.GetPhrase("fazhunt.gifts.owner"), self:GetOwner():Nick() ), "timerFontUpper", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
            end
        end
    end

    function ENT:Think()
        local height = math.sin((CurTime() - self.SpawnTime) * 2) * 5
        local pos = self:GetPos()
        pos.z = self.InitialZ + height
        self:SetPos(pos)

        self:NextThink(CurTime())
        self:SetRenderAngles(self:GetAngles() + Angle(0, 1, 0))
        self:SetNextClientThink(CurTime())
        return true
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
    {
        name = "heal",
		desc = "fazhunt.gifts.heal",
		num = 35,
        func = function(ply)
            ply:SetHealth(ply:Health() + 35)
        end,
		req = function(ply)
			if ply:Health() < 100 then
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
    {
        name = "armor",
		desc = "fazhunt.gifts.armor",
		num = 50,
        func = function(ply)
			ply:SetArmor(math.min(ply:Armor() + 50, 100))
        end,
        req = function(ply)
			return ply:Armor() < 100
        end
    },
    {
        name = "invisibility",
		desc = "fazhunt.gifts.invisibility",
        func = function(ply)
            ply:Give("weapon_mask")
        end,
        req = function(ply)
			return ( !timer.Exists("EndGameTimer") or timer.Exists("EndGameTimer") and timer.TimeLeft("EndGameTimer") >= 120 ) 
			and !ply:HasWeapon("weapon_mask")
        end
    },
    {
        name = "gravity_gun",
		desc = "fazhunt.gifts.gravity_gun",
        func = function(ply)
            ply:Give("weapon_physcannon")
        end,
        req = function(ply)
			return !ply:HasWeapon("weapon_physcannon") and #ents.FindByClass("prop_physics") > 100
        end
    },
    {
        name = "animatronics_visibility",
		desc = "fazhunt.gifts.animatronics_visibility",
        func = function(ply)
            net.Start("fh_hl_animatronics")
            net.Send(ply)
        end
    },
    {
        name = "defibrilator",
		desc = "fazhunt.gifts.defibrilator",
        func = function(ply)
            ply:Give("weapon_defibrilator")
            effectDesc = 'fazhunt.gifts.defibrilator'
        end,
        req = function(ply)
			return !ply:HasWeapon("weapon_defibrilator")
        end
    },
    {
        name = "bananas",
		desc = "fazhunt.gifts.bananas",
		num = 5,
        func = function(ply)
            ply:Give("weapon_banana")
            ply:GiveAmmo(4, "ammo_banana", true)
        end
    },
    {
        name = "speed_buff",
		desc = "fazhunt.gifts.speed_buff",
		num = 15,
        func = function(ply)
            ply:SetWalkSpeed(ply:GetWalkSpeed() * 1.2)
            ply:SetRunSpeed(ply:GetRunSpeed() * 1.2)
            ply:SetCrouchedWalkSpeed(ply:GetCrouchedWalkSpeed() * 1.4)
			
			local trail = util.SpriteTrail(ply, ply:LookupAttachment( "chest" ), Color(0, 169, 255, 255), true, 32, 0, 1, 1 / ( ( 32 + 0 ) * 0.5 ), "trails/physbeam")
            
            timer.Simple(15, function()
                if IsValid(ply) then
                    ply:SetWalkSpeed(ply:GetWalkSpeed() / 1.2)
                    ply:SetRunSpeed(ply:GetRunSpeed() / 1.2)
                    ply:SetCrouchedWalkSpeed(ply:GetCrouchedWalkSpeed() / 1.4)
					if IsValid(trail) then
						trail:Remove()
					end
                end
            end)
        end,
        req = function(ply)
			return ply:GetRunSpeed() < 600
        end
    },
    {
        name = "jump_buff",
		desc = "fazhunt.gifts.jump_buff",
		num = 25,
        func = function(ply)
            ply:SetJumpPower(ply:GetJumpPower() * 2)
            
            timer.Simple(25, function()
                if IsValid(ply) then
                    ply:SetJumpPower(math.max(ply:GetJumpPower() / 2, 200))
                end
            end)
        end,
        req = function(ply)
			return fh.GetActiveUsedKiller("pill_wfoxy2") or fh.GetActiveUsedKiller("pill_sfreddy2")
        end
    }
}

-- Негативные эффекты
local negativeEffects = {
    {
        name = "spawn_car",
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
    {
        name = "animatronics_alert",
		desc = "fazhunt.gifts.animatronics_alert",
        func = function(ply)
            net.Start("fh_hl_badkid")
            net.WriteEntity(ply)
            net.Broadcast()
            
            table.insert(affectedPlayers, ply)
        
            if timer.Exists("RemoveAffectedPlayer" .. ply:SteamID64()) then
                timer.Remove("RemoveAffectedPlayer" .. ply:SteamID64())
            end
        
            timer.Create("RemoveAffectedPlayer" .. ply:SteamID64(), conVars.halo_time:GetFloat(), 1, function()
                table.RemoveByValue(affectedPlayers, ply)
            end)
        end
    },
    {
        name = "reduce_step",
		desc = "fazhunt.gifts.reduce_step",
        func = function(ply)
            ply:SetStepSize(0)
        end
    },
    {
        name = "strip_weapons",
		desc = "fazhunt.gifts.strip_weapons",
        func = function(ply)
            ply:StripWeapons()
        end
    },
    {
        name = "thinkfast",
		desc = "",
        func = function(ply)
            net.Start('fh_net_thinkfast')
            net.Send(ply)
        end
    },
    {
        name = "fov_buff",
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
    {
        name = "sound_dsp",
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
    }
}

if SERVER then
	function gifts.AddPositiveEffect(name, desc, num, func, req)
		table.insert(positiveEffects, {
			name = name,
			desc = desc or "",
			num = num or -1,
			func = func,
			req = req or nil
		})
	end
	
	function gifts.AddNegativeEffect(name, desc, num, func)
		table.insert(negativeEffects, {
			name = name,
			desc = desc or "",
			num = num or -1,
			func = func
		})
	end
	
	--[[
	gifts.AddPositiveEffect('die', 			-- Имя: чисто по приколу
							"ИДИ НАХУЙ", 	-- Описание: Можно вставить просто текст, а можно строчку перевода
							-1, 			-- Если в описании используется %i а указанное слева число равно или больше 0, то игра попробует заменить %i в описании на эту цифру.
	function(ply) 							-- Функция когда берём подарок
		ply:Kill()
	end,
	function(ply) 							-- ОПЦИОНАЛЬНО: Условие выдачи подарка (Если у игрока есть монтировка, убиваем его нахуй) (Если мы, НАПРИМЕР, выдаём игроку монтировку, то в условии надо проверять что монтировки у игрока нету, чтобы не пытаться выдать игроку ещё одну монтировку)
		return ply:HasWeapon("weapon_crowbar")
	end)
	]]--
end

function ENT:ApplyEffect(player)
    local isOwner = self:GetOwner() == player
    local effects = {}
    
    local availablePositiveEffects = {}
    for _, effect in ipairs(positiveEffects) do
		if effect.req and effect.req(player) then
			table.insert(availablePositiveEffects, effect)
        elseif !effect.req then
            table.insert(availablePositiveEffects, effect)
        end
    end
    
    if isOwner then
        effects = availablePositiveEffects
    else
        effects = {}
        for _, effect in ipairs(availablePositiveEffects) do
            table.insert(effects, effect)
        end
        for _, effect in ipairs(negativeEffects) do
            table.insert(effects, effect)
        end
    end
    
    if #effects == 0 then
        self:Remove()
        return
    end
    
    local effect = effects[math.random(#effects)]
    effect.func(player)
    
    local isPositive = false
    for _, posEffect in ipairs(availablePositiveEffects) do
        if posEffect.name == effect.name then
            isPositive = true
            break
        end
    end
    
    if isPositive then
        self:EmitSound("orch_hit_csharp_short.wav")
        
        net.Start('fh_net_display')
        net.WriteString('fazhunt.gifts.positive')
        net.WriteString(effect.desc or "")
        net.WriteFloat(effect.num or -1)
        net.WriteFloat(5)
        net.Send(player)
    else
        self:EmitSound("ahuitebe.mp3")
        
        net.Start('fh_net_display')
        net.WriteString('fazhunt.gifts.negative')
        net.WriteString(effect.desc or "")
        net.WriteFloat(effect.num or -1)
        net.WriteFloat(5)
        net.Send(player)
    end
end