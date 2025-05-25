AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("NotifyCupcakeOwner")
util.AddNetworkString("NotifySoundCupcakeOwner")
util.AddNetworkString("NotifyCupcakeVictim")

util.AddNetworkString("fh_remove_hud_mine")

util.AddNetworkString("AddServerAffectedPlayers")

util.PrecacheModel("models/team vr/cupcake.mdl")

local nearPlayers = {}

function ENT:Initialize()
    self:SetModel("models/team vr/cupcake.mdl")
	self:SetModelScale(0.4, 0)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
	//self:SetColor(Color(255, 255, 255, 100))
	self:SetRenderMode( RENDERMODE_TRANSCOLOR )
	
    local phys = self:GetPhysicsObject()
	
    if phys:IsValid() then
        phys:Wake()
    end

    self:SetHealth(10)

    timer.Create("CheckPlayersTimer_" .. self:EntIndex(), 0.5, 0, function()
        if not IsValid(self) then return end
        self:CheckForPlayers()
    end)
end

function ENT:OnRemove()
    timer.Remove("CheckPlayersTimer_" .. self:EntIndex())
	self:EmitExplosion()
	
	net.Start('fh_remove_hud_mine')
	net.Send(self:GetOwner())
	
	self:CheckForPlayers()
end

function ENT:CheckForPlayers()
    local pos = self:GetPos()
    local radius = 200
	local totalPlayers = {}

    for _, ply in pairs(ents.FindInSphere(pos, radius)) do
        if ply:IsPlayer() and ply ~= self:GetOwner() and ply:Team() != 2701 and ply:Team() != TEAM_SPECTATOR and !table.HasValue(nearPlayers, ply) then
			
			local trace = util.TraceLine({
				start = pos,
				endpos = ply:GetPos(),
				filter = function(ent)
					return ent != ignorePlayer and !ent:IsPlayer() and !ent:IsNPC()
				end,
				mask = MASK_PLAYERSOLID_BRUSHONLY
			})
			
			if trace.Hit then return end
			
			net.Start("NotifyCupcakeVictim")
			net.Send(ply)
			
			table.insert(nearPlayers, ply)
			table.insert(totalPlayers, ply)
			
            ply:SetRunSpeed(ply:GetRunSpeed() * 0.5)
			
			if timer.Exists('C_deploycake'..self:GetOwner():EntIndex()) then
				timer.Adjust("C_deploycake"..self:GetOwner():EntIndex(), 10)
			else
				timer.Create("C_deploycake"..self:GetOwner():EntIndex(), 10, 1, function() end)
			end
			
			net.Start("fh_net_killer_change")
			net.WriteString("Mine")
			net.WriteFloat(10)
			net.Send(ply)
            
            timer.Simple(7, function()
                if IsValid(ply) then
					ply:SetRunSpeed(ply:GetRunSpeed() / 0.5)
                end
            end)
			
			timer.Simple(20, function()
				table.RemoveByValue(nearPlayers, ply)
			end)
        end
    end
	if table.Count(totalPlayers) == 0 then return end
	self:EmitSparks()
			
	net.Start("AddAffectedPlayers")
	net.WriteTable(totalPlayers)
	net.Send(self:GetOwner())
	
	for _, player in pairs(totalPlayers) do
		if !table.HasValue(affectedPlayers, player) then
			table.insert(affectedPlayers, player)
		end
	end
			
	net.Start("NotifySoundCupcakeOwner")
	net.Send(self:GetOwner())
end

function ENT:OnTakeDamage(dmginfo)
    self:TakePhysicsDamage(dmginfo)
	
    local health = self:Health()
    health = health - dmginfo:GetDamage()
    self:SetHealth(health)

    if health <= 0 then
        self:Remove()
    end
end

function ENT:PhysgunPickup(ply, ent)
    return false
end

hook.Add("GravGunPickupAllowed", "fh_cakemine_pickup", function(player, entity)
    if entity:GetClass() == "cakemine" then
        return false
    end
end)

hook.Add("GravGunPunt", "fh_cakemine_punt", function(player, entity)
    if entity:GetClass() == "cakemine" then
        return false
    end
end)

function ENT:EmitExplosion()
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetScale(1)
    util.Effect("Explosion", effectdata)
end

function ENT:EmitSparks()
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetScale(1)
    util.Effect("cball_explode", effectdata)
end