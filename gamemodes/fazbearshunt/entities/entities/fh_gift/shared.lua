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
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 64))
		self:EmitSound( "items/battery_pickup.wav" )
	end
	self.InitialZ = self:GetPos().z
	self.SpawnTime = CurTime()
end

if SERVER then
    function ENT:Think()
        return true
    end

    function ENT:Touch(ent)
        if CurTime() - self.SpawnTime > 1.5 and (ent:IsPlayer() and !ent:IsBot()) and ent:Team() != 2701 then
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
				
				cam.Start3D2D(self:GetPos() + Vector(0, 0, 80), Angle(0, ang.y, 90), 0.25)
				draw.SimpleText("Подарок для " .. self:GetOwner():Nick(), "DermaLarge", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
function ENT:ApplyEffect(player)
    local isOwner = self:GetOwner() == player
    local effects = {}
    
    -- Позитивные эффекты
    local positiveEffects = {
        function(ply)
            ply:SetHealth(ply:Health() + 35)
			effectDesc = '+35 HP'
        end,
        function(ply)
            ply:Give("weapon_physcannon")
			effectDesc = '+ Гравити Ган'
        end,
        function(ply)
            net.Start("fh_hl_animatronics")
            net.Send(ply)
			effectDesc = 'Теперь ты можешь видить аниматроников через стены.'
        end,
        function(ply)
            ply:Give("weapon_gpee")
			effectDesc = '+ Ссаньё'
        end,
        function(ply)
            ply:Give("weapon_defibrilator")
			effectDesc = '+ Дефибрилятор'
        end,
        function(ply)
            ply:Give("weapon_banana")
            ply:GiveAmmo(9, "ammo_banana", true)
			effectDesc = '+ 10 бананов'
        end,
        function(ply)
            ply:SetWalkSpeed(ply:GetWalkSpeed() * 1.2)
            ply:SetRunSpeed(ply:GetRunSpeed() * 1.2)
            ply:SetCrouchedWalkSpeed(ply:GetCrouchedWalkSpeed() * 1.4)
			effectDesc = 'Тебе выдано ускорение на 15 секунд!'
            
            timer.Simple(15, function()
                if IsValid(ply) then
                    ply:SetWalkSpeed(ply:GetWalkSpeed() / 1.2)
                    ply:SetRunSpeed(ply:GetRunSpeed() / 1.2)
					ply:SetCrouchedWalkSpeed(ply:GetCrouchedWalkSpeed() / 1.4)
                end
            end)
        end,
        function(ply)
            ply:SetJumpPower(ply:GetJumpPower() * 2)
			effectDesc = 'Теперь ты прыгаешь выше 25 секунд!'
            
            timer.Simple(25, function()
                if IsValid(ply) then
                    ply:SetJumpPower(ply:GetJumpPower() / 2)
                end
            end)
        end
    }
    
    -- Негативные эффекты
    local negativeEffects = {
        function(ply)
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
		
			timer.Simple(10, function()
				if IsValid(car) then
					car:Remove()
				end
			end)
			effectDesc = ''
		end,
        function(ply)
            net.Start("fh_hl_badkid")
            net.WriteEntity(ply)
            net.Broadcast()
			effectDesc = 'Все аниматроники знают где ты.'
			
			table.insert(affectedPlayers, ply)
		
			if timer.Exists( "RemoveAffectedPlayer"..ply:SteamID64() ) then
				timer.Remove( "RemoveAffectedPlayer"..ply:SteamID64())
			end
		
			timer.Create( "RemoveAffectedPlayer"..ply:SteamID64(), conVars.halo_time:GetFloat(), 1, function()
				table.RemoveByValue(affectedPlayers, ply)
			end)
        end,
        function(ply)
			ply:SetStepSize(0)
			effectDesc = 'Теперь тебе сложнее подниматься по ступенькам.'
        end,
        function(ply)
            ply:StripWeapons()
			effectDesc = 'Больше у тебя нет оружия.'
        end,
        function(ply)
			effectDesc = ''
			net.Start('fh_net_thinkfast')
			net.Send(ply)
        end,
        function(ply)
            ply:SetFOV(30, 1)
            ply:SetCanZoom(false)
            ply:StopZooming()
			effectDesc = 'Твоё поле зрения увеличено на 30 секунд.'
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetFOV(0, 1)
					ply:SetCanZoom(true)
                end
            end)
        end,
        function(ply)
            ply:SetDSP(31, false)
			effectDesc = 'Твой звук приглушен на 30 секунд.'
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetDSP(1, false)
                end
            end)
        end
    }
    
    if isOwner then
        effects = positiveEffects
    else
        for _, effect in ipairs(positiveEffects) do
            table.insert(effects, effect)
        end
        for _, effect in ipairs(negativeEffects) do
            table.insert(effects, effect)
        end
    end
    
    local effect = effects[math.random(#effects)]
    effect(player)
	if table.HasValue(positiveEffects, effect) then
		self:EmitSound( "orch_hit_csharp_short.wav" )
		
		net.Start('fh_net_display')
		net.WriteString('Ты подобрал подарок!')
		net.WriteString(effectDesc)
		net.WriteFloat(5)
		net.Send(player)
	end
	if table.HasValue(negativeEffects, effect) then
		self:EmitSound( "ahuitebe.mp3" )
		
		net.Start('fh_net_display')
		net.WriteString('Ты украл чужой подарок.')
		net.WriteString(effectDesc)
		net.WriteFloat(5)
		net.Send(player)
	end
end