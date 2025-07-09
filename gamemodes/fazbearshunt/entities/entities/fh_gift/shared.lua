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
        if CurTime() - self.SpawnTime > 1.5 and (ent:IsPlayer() and !ent:IsBot()) and ent:Team() != 2701 then
            self.IsUsed = true
            self:ApplyEffect(ent)
            self:Remove()
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
                draw.SimpleText("Подарок для " .. self:GetOwner():Nick(), "timerFontUpper", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

local effectDesc = ''
local format_num = -1

-- Позитивные эффекты
local positiveEffects = {
    {
        name = "heal",
        func = function(ply)
            ply:SetHealth(ply:Health() + 35)
            effectDesc = 'fazhunt.gifts.heal'
			format_num = 35
        end
    },
    {
        name = "armor",
        func = function(ply)
			ply:SetArmor(math.min(ply:Armor() + 50, 100))
            effectDesc = 'fazhunt.gifts.armor'
			format_num = 50
        end
    },
    {
        name = "invisibility",
        func = function(ply)
			if not IsValid(ply) then return end
	
			ply.invisible = true
			ply:SetRenderMode(RENDERMODE_TRANSALPHA)
			ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			ply:SetCustomCollisionCheck(true)
			ply:CollisionRulesChanged()
			ply:SetColor(Color(255, 255, 255, 0))
			ply:SetNoDraw(true)
			ply:DrawShadow(false)
			effectDesc = 'fazhunt.gifts.invisibility'
			format_num = 30
	
			timer.Simple(30, function()
				if IsValid(ply) then
					ply:SetColor(Color(255, 255, 255, 255))
					ply:SetNoDraw(false)
					ply:DrawShadow(true)
					ply.invisible = false
	
					local function IsStuck(ent)
						if not IsValid(ent) then return false end
				
						local trace = util.TraceEntity({
							start = ent:GetPos(),
							endpos = ent:GetPos(),
							filter = ent,
							mask = MASK_SOLID
						}, ent)
				
						return trace.Hit
					end
					
					timer.Create("fh_gift_collision_reset" .. ply:EntIndex(), 0.5, 0, function()
						if IsValid(ply) and !IsStuck(ply) then
							ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
							ply:SetCustomCollisionCheck(false)
							ply:CollisionRulesChanged()
						end
				
						if !IsValid(ply) or !IsStuck(ply) then
							timer.Remove("fh_gift_collision_reset" .. ply:EntIndex())
						end
					end)
					
				end
			end)
        end
    },
    {
        name = "gravity_gun",
        func = function(ply)
            ply:Give("weapon_physcannon")
            effectDesc = 'fazhunt.gifts.gravity_gun'
			format_num = -1
        end
    },
    {
        name = "animatronics_visibility",
        func = function(ply)
            net.Start("fh_hl_animatronics")
            net.Send(ply)
            effectDesc = 'fazhunt.gifts.animatronics_visibility'
			format_num = -1
        end
    },
    {
        name = "defibrilator",
        func = function(ply)
            ply:Give("weapon_defibrilator")
            effectDesc = 'fazhunt.gifts.defibrilator'
			format_num = -1
        end
    },
    {
        name = "bananas",
        func = function(ply)
            ply:Give("weapon_banana")
            ply:GiveAmmo(4, "ammo_banana", true)
            effectDesc = 'fazhunt.gifts.bananas'
			format_num = 5
        end
    },
    {
        name = "speed_buff",
        func = function(ply)
            ply:SetWalkSpeed(ply:GetWalkSpeed() * 1.2)
            ply:SetRunSpeed(ply:GetRunSpeed() * 1.2)
            ply:SetCrouchedWalkSpeed(ply:GetCrouchedWalkSpeed() * 1.4)
            effectDesc = 'fazhunt.gifts.speed_buff'
			format_num = 15
			
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
        end
    },
    {
        name = "jump_buff",
        func = function(ply)
            ply:SetJumpPower(ply:GetJumpPower() * 2)
            effectDesc = 'fazhunt.gifts.jump_buff'
			format_num = 25
            
            timer.Simple(25, function()
                if IsValid(ply) then
                    ply:SetJumpPower(math.max(ply:GetJumpPower() / 2, 200))
                end
            end)
        end
    }
}

-- Негативные эффекты
local negativeEffects = {
    {
        name = "spawn_car",
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
            effectDesc = ''
			format_num = -1
        end
    },
    {
        name = "animatronics_alert",
        func = function(ply)
            net.Start("fh_hl_badkid")
            net.WriteEntity(ply)
            net.Broadcast()
            effectDesc = 'fazhunt.gifts.animatronics_alert'
			format_num = -1
            
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
        func = function(ply)
            ply:SetStepSize(0)
            effectDesc = 'fazhunt.gifts.reduce_step'
			format_num = -1
        end
    },
    {
        name = "strip_weapons",
        func = function(ply)
            ply:StripWeapons()
            effectDesc = 'fazhunt.gifts.strip_weapons'
			format_num = -1
        end
    },
    {
        name = "thinkfast",
        func = function(ply)
            net.Start('fh_net_thinkfast')
            net.Send(ply)
            effectDesc = ''
			format_num = -1
        end
    },
    {
        name = "fov_buff",
        func = function(ply)
            ply:SetFOV(30, 1)
            ply:SetCanZoom(false)
            ply:StopZooming()
            effectDesc = 'fazhunt.gifts.fov_buff'
			format_num = 30
            
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
        func = function(ply)
            ply:SetDSP(31, false)
            effectDesc = 'fazhunt.gifts.sound_dsp'
			format_num = 30
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetDSP(1, false)
                end
            end)
        end
    }
}

function ENT:ApplyEffect(player)
    local isOwner = self:GetOwner() == player
    local effects = {}
    
    local availablePositiveEffects = {}
    for _, effect in ipairs(positiveEffects) do
        if effect.name == "defibrilator" then
            if !player:HasWeapon("weapon_defibrilator") then
                table.insert(availablePositiveEffects, effect)
            end
        elseif effect.name == "gravity_gun" then
            if !player:HasWeapon("weapon_physcannon") then
                table.insert(availablePositiveEffects, effect)
            end
		elseif effect.name == "invisibility" then
			if timer.Exists("EndGameTimer") and timer.TimeLeft("EndGameTimer") >= 120 then
                table.insert(availablePositiveEffects, effect)
			end
		elseif effect.name == "armor" then
			if player:Armor() < 100 then
                table.insert(availablePositiveEffects, effect)
			end
		elseif effect.name == "jump_buff" then
			if fh.GetActiveUsedKiller("pill_wfoxy2") or fh.GetActiveUsedKiller("pill_sfreddy2") then
                table.insert(availablePositiveEffects, effect)
			end
        else
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
        net.WriteString(effectDesc)
		net.WriteFloat(format_num)
        net.WriteFloat(5)
        net.Send(player)
    else
        self:EmitSound("ahuitebe.mp3")
        
        net.Start('fh_net_display')
        net.WriteString('fazhunt.gifts.negative')
        net.WriteString(effectDesc)
		net.WriteFloat(format_num)
        net.WriteFloat(5)
        net.Send(player)
    end
end