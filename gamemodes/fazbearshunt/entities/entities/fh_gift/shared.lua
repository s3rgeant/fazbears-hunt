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
			self:EmitSound( "items/battery_pickup.wav" )
            self:ApplyEffect(ent)
            self:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        if IsValid(self:GetOwner()) then
            local ang = LocalPlayer():EyeAngles()
            ang:RotateAroundAxis(ang:Forward(), 90)
            ang:RotateAroundAxis(ang:Right(), 90)
            
            cam.Start3D2D(self:GetPos() + Vector(0, 0, 80), Angle(0, ang.y, 90), 0.25)
            draw.SimpleText("Подарок для " .. self:GetOwner():Nick(), "DermaLarge", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
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

function ENT:ApplyEffect(player)
    local isOwner = self:GetOwner() == player
    local effects = {}
    
    -- Позитивные эффекты
    local positiveEffects = {
        function(ply)
            ply:SetHealth(ply:Health() + 35)
        end,
        function(ply)
            ply:Give("weapon_physcannon")
        end,
        function(ply)
            net.Start("fh_hl_animatronics")
            net.Send(ply)
            ply:ChatPrint("Теперь ты видишь аниматроников через стены!")
        end,
        function(ply)
            ply:Give("weapon_rpg")
            ply:GiveAmmo(8, "RPG_Round", true)
            ply:ChatPrint("Вы получили RPG с 8 ракетами!")
        end,
        function(ply)
            ply:SetWalkSpeed(ply:GetWalkSpeed() * 1.2)
            ply:SetRunSpeed(ply:GetRunSpeed() * 1.2)
            ply:ChatPrint("Вы ускорены на 10 секунд!")
            
            timer.Simple(10, function()
                if IsValid(ply) then
                    ply:SetWalkSpeed(ply:GetWalkSpeed() / 1.2)
                    ply:SetRunSpeed(ply:GetRunSpeed() / 1.2)
                    ply:ChatPrint("Ваше ускорение закончилось.")
                end
            end)
        end
    }
    
    -- Негативные эффекты
    local negativeEffects = {
        function(ply)
            local car = ents.Create("prop_physics")
            car:SetModel("models/props_vehicles/truck001a.mdl")
            car:SetPos(ply:GetPos() + Vector(0, 0, 500))
            car:Spawn()
            car:Activate()
			timer.Simple(10, function()
				car:Remove()
			end)
        end,
        function(ply)
            net.Start("fh_hl_badkid")
            net.WriteEntity(ply)
            net.Broadcast()
            ply:ChatPrint("Они знают...")
        end,
        function(ply)
			ply:SetStepSize(0)
            ply:ChatPrint("Вы не можете подниматься по ступенькам!")
        end,
        function(ply)
            ply:StripWeapons()
            ply:ChatPrint("Все ваши оружия были изъяты!")
        end,
        function(ply)
            ply:SetFOV(30, 1)
            ply:SetCanZoom(false)
            ply:StopZooming()
            ply:ChatPrint("Ваше поле зрения уменьшено на 30 секунд!")
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetFOV(0, 1)
					ply:SetCanZoom(true)
                end
            end)
        end,
        function(ply)
            ply:SetDSP(31, false)
            ply:ChatPrint("Ваши звуки приглушены на 30 секунд!")
            
            timer.Simple(30, function()
                if IsValid(ply) then
                    ply:SetDSP(1, false)
                end
            end)
        end
    }
    
    -- Формируем список эффектов в зависимости от владельца
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
    
    -- Выбираем случайный эффект
    local effect = effects[math.random(#effects)]
    effect(player)
end