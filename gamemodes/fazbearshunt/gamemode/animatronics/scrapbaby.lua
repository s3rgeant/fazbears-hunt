AddCSLuaFile()

if SERVER then
	util.PrecacheModel("models/torres/ffps/salvage/scrapbabyv19.mdl")
end

sound.Add({
	name = 			"scrapbaby.rollers",
	channel = 		CHAN_STATIC,
	level = 		90,
	volume = 		1.0,
	sound = 			{
							"animatronics/scrapbaby/baby_rollers1.mp3",
							"animatronics/scrapbaby/baby_rollers2.mp3",
							"animatronics/scrapbaby/baby_rollers3.mp3",
						}
})

sound.Add({
	name = 			"scrapbaby.foot.rollers",
	channel = 		CHAN_STATIC,
	level = 		80,
	volume = 		1.0,
	sound = 			{
							"animatronics/scrapbaby/baby_rollers_walk1.mp3",
							"animatronics/scrapbaby/baby_rollers_walk2.mp3",
							"animatronics/scrapbaby/baby_rollers_walk3.mp3",
						}
})

local BABY_MISS_CD = 1 --7
local BABY_HIT_CD = 1 --10

local BABY = GetPillTemplate()
local babyOrange = Color(255,110,0)

BABY.printName="Scrap Baby"
BABY.model="models/torres/ffps/salvage/scrapbabyv19.mdl"
BABY.anims={
	default={
		idle="idle",
		--crouch="crouch",
		--crouch_walk="crouchmove",
		walk="walk",
		run="run",
		jump="jump",
		glide="glide",
		land="land",
		scare="clawscare",
		stun="stun",
		clawscare="clawscare",
	},
	gestures={
		--melee="melee",
		aim="aim",
		aimL="aim-loop",
		shoot="shoot",
		shootL="shoot-loop",
	},
}
BABY.moveSpeed={
	maxwalk=150,
	walk=220,
	run=485,
	ducked=160,
}
BABY.camera.offset=Vector(0, 0, 88)
BABY.duckBy=60
BABY.viewmodel={
	weapon="v_scrapbaby",
	func=function(wep, ply, ent)
		wep:SetPillCostume(ent)
	end,
}
BABY.sounds={
	jump="fnaf3/sprjump.mp3",
	land="fnaf3/sprland.mp3",
	melee="animatronics/scrapbaby/jumpscare.mp3",
}
BABY.chaseTheme="scrapbaby"
BABY.startFunction=function(ply,ent)
	chaseVoicelineChecker(ply, ent, "endo")
end
BABY.killCondition=function(ply,ent)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep.CanJumpscare then
		if not wep:CanJumpscare() then return end
	end
		
	local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
	
	if IsValid(target) and !target:IsInvisible() and !target:IsJumpscared() then
		return true
	end
	return false
end
BABY.attack={
	mode="trigger", func=function(ply,ent)
		if cooldown.Exists(ply, "kill") then return end
			
		if IsValid(ply:GetEntityInUse()) then return end
		
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.CanJumpscare then
			if not wep:CanJumpscare() then return end
		end
		
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		local jumpscare = performJumpscare(ply, ent, target, 1.6, "scrapbaby", 52, "v_scrapbaby")
		
		if !IsValid(target) or !jumpscare then 
			if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
			return 
		end
	end
}
BABY.clawPlayerHit=function(ply, ent, claw, target)
	target:TakeDamage( 10, ply, claw )
	
	target:SetNW2Bool("_SBBlockInteract", true)
	
	cooldown.Set(ply, "snatch", BABY_HIT_CD)
	cooldown.Send(ply, "snatch")
	
	if target:IsAnimatronic() then return end
	
	local plyIndex = target:EntIndex()
	local timerName = "scrapbaby_clawhitDamage" .. plyIndex
	
	timer.Create(timerName, 0.35, 0, function()
		if not IsValid(target) then timer.Remove(timerName) return end
		if not target:Alive() then
			target:SetNWEntity("_ScrapBabyHooker", NULL)
			timer.Remove("SmoothLookAt_" .. target:EntIndex())
			if IsValid(claw) then
				claw:SetParent()
				claw:SetSucker()
			end
			timer.Remove(timerName)
			return
		end
		if not IsValid(ent) then timer.Remove(timerName) return end
		if not IsValid(ply) or not ply:Alive() then timer.Remove(timerName) return end
		target:TakeDamage( 4.5, ply, claw )
		
		local edata = EffectData()
		edata:SetOrigin(target:EyePos())
		edata:SetEntity(target)
		util.Effect("BloodImpact", edata, true, true)
	end)
end
BABY.clawEnvironmentHit=function(ply, ent, target)
	cooldown.Set(ply, "snatch", BABY_MISS_CD)
	cooldown.Send(ply, "snatch")
end
BABY.playerCatch=function(ply, ent, claw, target)
	local plyIndex = target:EntIndex()
	local timerName = "scrapbaby_clawhitDamage" .. plyIndex
	
	target:SetNW2Bool("_SBBlockInteract", false)
	
	timer.Remove(timerName)
	
	if target:IsAnimatronic() then 
		target._skipLandAnim = true
		target:NoPlayerCollide(0.2)
		
		timer.Simple(0, function()
			if IsValid(target) and target:IsStuck() then
				target:Unstuck()
			end
		end)
		return 
	end
	
	ent:PillAnim("clawscare", true, .5)
	--ent:PillSound("melee",false)
	
	jumpscareEvent(ply, ent, target, 60)
	target:SetJumpscared(true)
	ply.jumpscaring = target
	
	cooldown.Set(ply, "kill", 3)
	cooldown.Send(ply, "kill")
	
	timer.Simple(0.7, function()
		if IsValid(ent) then
			ent:SetUseForceAngles(false)
		end
		if IsValid(ply) then 
			ply:Freeze(false)
			ply.jumpscaring = nil
			
			if IsValid(target) then
				local dir = ply:GetForward()
				target:SetVelocity(dir * 800 + target:GetUp() * 200)
			end
		end
		if IsValid(target) then 
			target:TakeDamage( 25, ply )
			
			target:SetJumpscared(false)
			target:SetCollisionGroup(5)
			target:CollisionRulesChanged()
			
			if target:IsPlayer() then
				target:Freeze(false)
			end
			
			timer.Simple(0, function()
				if IsValid(target) and target:Alive() and target:Health() > 0 then
					for _, anim in ipairs(team.GetPlayers( TEAM_PILLS )) do
						highlight.Add(anim, target, nil, babyOrange)
					end
				end
			end)
		end
	end)
end
BABY.land=function(ply,ent)
	if IsGoodLandConditions(ply, ent) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.CanLand then
			if wep:CanLand() then 
				ent:PillAnim("land",true)
			end
		end
	end
	landTripCheck(ply, ent, "sbaby")
end
BABY.reload=function(ply,ent)
	highlight.ByDistance(ply, ent)
end

pills.register("fh_scrapbaby", BABY)

killers.Register("fh_scrapbaby", "scrapbaby", "Scrap Baby", babyOrange)

killers.SetAbilities("scrapbaby", {
	{ name = 'highlight', key = 'R' },
	{ name = 'kill', key = 'LMB', hidden = true },
	{ name = 'snatch', key = 'RMB' },
})

local function resetSBB_NW(ply)
	if ply:GetNW2Bool("_SBBlockInteract") then
		ply:SetNW2Bool("_SBBlockInteract", false)
	end
end

hook.Add("PlayerDeath", "scrapbaby_reset_NW", resetSBB_NW)
hook.Add("PlayerSilentDeath", "scrapbaby_reset_NW", resetSBB_NW)