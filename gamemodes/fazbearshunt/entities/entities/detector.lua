AddCSLuaFile()

ENT.Type = "anim"

ENT.PrintName = "Detector"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.List = {}

local LASER_SPRITE = "sprites/laserbeam.vmt"

function ENT:Initialize()

    self:SetModel("models/fh/weapons/w_detector.mdl")
    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_BBOX)
	
	self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	self:EnableCustomCollisions(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self:SetBodygroup(0, 3)
    self:SetCollisionBounds(Vector(-4, -4, -2), Vector(4, 4, 2))
	
    if CLIENT then return end

    local sk_plr_dmg = GetConVar("sk_plr_dmg_tripmine")
    local sk_radius = GetConVar("sk_tripmine_radius")

    self.m_flDamage = (sk_plr_dmg and sk_plr_dmg:GetFloat() > 0) and sk_plr_dmg:GetFloat() or 150
    self.m_DmgRadius = (sk_radius and sk_radius:GetFloat() > 0) and sk_radius:GetFloat() or 200
    self.m_iHealth = 1
    self.m_bIsLive = false

    self:SetHealth(self.m_iHealth)
    self:SetMaxHealth(self.m_iHealth)

    self:EmitSound("TripmineGrenade.Place")

    local angles = self:GetAngles()
    angles.p = angles.p - 90
    self.m_vecDir = angles:Forward()
    self.m_vecEnd = self:GetPos() + self.m_vecDir * 2048

    self.m_flPowerUp = CurTime() + 1.5
    self:NextThink(CurTime() + 0.2)
end

function ENT:Think()
    if CLIENT then return end

    if not self.m_bIsLive then
        self:PowerupThink()
    else
        self:BeamBreakThink()
    end

    return true
end

function ENT:PowerupThink()
	if CurTime() > self.m_flPowerUp then
		self:MakeBeam()
		self.m_bIsLive = true
		self:EmitSound("TripmineGrenade.Activate")
		
		self:SetUseType( SIMPLE_USE )
	else
		self:NextThink(CurTime() + 0.1)
	end
end

function ENT:KillBeam()
	if IsValid(self.m_pBeam) then
		self.m_pBeam:Remove()
		self.m_pBeam = nil
	end
	if IsValid(self.m_pBeamEndEnt) then
		self.m_pBeamEndEnt:Remove()
		self.m_pBeamEndEnt = nil
	end
end

function ENT:MakeBeam()
	self:KillBeam()
	
	local tr = util.TraceLine({
		start = self:GetPos(),
		endpos = self.m_vecEnd,
		filter = self,
		mask = MASK_SHOT
	})
	
	self.m_flBeamLength = tr.Fraction
	local drawLength = tr.Fraction
	
	local target = tr.Entity
	
	if IsValid(target) and target:IsPlayer() and target:IsAnimatronic() then
		local tr2 = util.TraceLine({
			start = self:GetPos(),
			endpos = self.m_vecEnd,
			filter = {self, target},
			mask = MASK_SHOT
		})
		self.m_flBeamLength = tr2.Fraction
	end
	
	local vecTmpEnd = self:GetPos() + self.m_vecDir * (2048 * drawLength)

   local beamEnd = ents.Create("info_target")

	beamEnd:SetName("tripmine_target_" .. beamEnd:EntIndex())
	beamEnd:SetPos(vecTmpEnd)

	beamEnd:Spawn()
	beamEnd:Activate()
	self.m_pBeamEndEnt = beamEnd

    self:SetName("tripmine_" .. self:EntIndex())

	local beam = ents.Create("env_beam")

	beam:SetPos(self:GetPos())

	beam:SetKeyValue("targetname", "tripmine_beam_" .. beam:EntIndex())

	beam:SetKeyValue("LightningStart", self:GetName())
	beam:SetKeyValue("LightningEnd", beamEnd:GetName())

	beam:SetKeyValue("texture", "sprites/laserbeam.vmt")
	beam:SetKeyValue("rendercolor", "255 55 52")
	beam:SetKeyValue("renderamt", "5")

	beam:SetKeyValue("BoltWidth", "0.6")
	beam:SetKeyValue("NoiseAmplitude", "0")
	beam:SetKeyValue("TextureScroll", "25.6")

	beam:SetKeyValue("life", "0")
	beam:SetKeyValue("damage", "0")

	beam:SetKeyValue("spawnflags", "1")

	beam:Spawn()
	beam:Activate()

	beam:Fire("TurnOn", "", 0)

	self.m_pBeam = beam

    self:NextThink(CurTime() + 0.1)
end

function ENT:HighlightEnemy(target)
	local owner = self:GetOwner()
	
	if IsValid(owner) and target ~= owner then
		highlight.Add(owner, target, 10)
		
		local sendTbl = {}
		
		for ply, _ in pairs(survivors) do
			if ply == owner then continue end
			
			local pos = target:GetPos()
			local distance = ply:GetPos():Distance(pos)
			if distance > 1500 then continue end
			
			highlight.Add(ply, target, 8)
			
			sendTbl[#sendTbl + 1] = ply
		end
		
		if #sendTbl > 0 then
			net.Start("fh_play_sound")
				net.WriteString("weapons/detector/detected_others.mp3")
			net.Send(sendTbl)
		end
		
		net.Start("fh_play_sound")
			net.WriteString("weapons/detector/detected.mp3")
		net.Send(owner)
		
		self:EmitSound("weapons/detector/detected_world.mp3", 60, nil, .5)
		
		self.List[target] = CurTime() + 12
	end
end

function ENT:BeamBreakThink()
    local tr = util.TraceLine({
        start = self:GetPos(),
        endpos = self.m_vecEnd,
        filter = self,
        mask = MASK_SOLID
    })
	
    local target = tr.Entity

    if not IsValid(self.m_pBeam) then
        self:MakeBeam()
    end

    local isCharacter = IsValid(target) and target:IsPlayer() and target:IsAnimatronic()

    if isCharacter and math.abs(self.m_flBeamLength - tr.Fraction) > 0.001 then
		if self.List[target] and CurTime() < self.List[target] then
			self:NextThink(CurTime() + 0)
			return
		end
		self:HighlightEnemy(target)
    end

    self:NextThink(CurTime() + 0)
end

function ENT:OnTakeDamage(dmginfo)
    if self:Health() <= 0 then return end

    self:SetHealth(0)
    self:Event_Killed(dmginfo)
end

function ENT:Event_Killed(dmginfo)
	self:DelayDeathThink()
    self:NextThink(CurTime() + 0.25)

    self:StopSound("TripmineGrenade.Place")
    self:StopSound("TripmineGrenade.Activate")
end

function ENT:DelayDeathThink()
    self:KillBeam()

    util.ScreenShake(self:GetPos(), 25.0, 150.0, 1.0, 750)

    local explode = ents.Create("env_explosion")
    explode:SetPos(self:GetPos() + self.m_vecDir * 8)
    explode:SetAngles(self:GetAngles())
    explode:SetOwner(IsValid(self:GetOwner()) and self:GetOwner() or self)
    explode:SetKeyValue("iMagnitude", self.m_flDamage)
    explode:SetKeyValue("iRadiusOverride", self.m_DmgRadius)
    explode:SetKeyValue("spawnflags", "19") -- NOSPARKS | NODLIGHTS | NOSMOKE
    explode:Spawn()
    explode:Fire("Explode", "", 0)

    self:Remove()
end

function ENT:OutlineOnUse(ply)
	local owner = self:GetOwner()
	return owner == ply
end

function ENT:Use( ply )
	if ply:IsPlayer() and ply:IsSurvivor() then 
		local owner = self:GetOwner()
		
		if not IsValid(owner) or ply == owner then
			if not ply:HasWeapon("weapon_detector") then
				self:KillBeam()
				self:Remove()
				
				ply:SetSuppressPickupNotices(true)
				ply:Give("weapon_detector", true)
				ply:SetSuppressPickupNotices(false)
				if ply:HasWeapon("weapon_detector") then -- incase it wasn't given for some reason
					ply:SelectWeapon("weapon_detector")
					ply:GetActiveWeapon():SendWeaponAnim(ACT_SLAM_TRIPMINE_DRAW)
				end
			end
		end
	end
end

function ENT:OnRemove()
    self:KillBeam()
end

function ENT:Draw()
    self:DrawModel()
end