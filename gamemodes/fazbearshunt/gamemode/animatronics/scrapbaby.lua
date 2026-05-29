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
	level = 		90,
	volume = 		1.0,
	sound = 			{
							"animatronics/scrapbaby/baby_rollers_walk1.mp3",
							"animatronics/scrapbaby/baby_rollers_walk2.mp3",
							"animatronics/scrapbaby/baby_rollers_walk3.mp3",
						}
})

local BABY = GetPillTemplate()

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
		--scare="scare",
		--stun="stun",
	},
	gestures={
		--melee="melee",
		aim="aim",
		aimL="aim-loop",
	},
}
BABY.moveSpeed={
	walk=240,
	run=485,
	ducked=160,
}
BABY.camera.offset=Vector(0, 0, 88)
BABY.duckBy=60
BABY.viewmodel={
	weapon="v_scrapbaby"
}
BABY.sounds={
	jump="fnaf3/sprjump.mp3",
	land="fnaf3/sprland.mp3",
	loop_breathing="springtrap.breath",
}
BABY.chaseTheme="scrapbaby"
BABY.startFunction=function(ply,ent)
	chaseVoicelineChecker(ply, ent, "endo")
end
BABY.killCondition=function(ply,ent)
	local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
	
	if IsValid(target) and !target:IsInvisible() and !target:IsJumpscared() then
		return true
	end
	return false
end
BABY.attack={
	mode="trigger", func=function(ply,ent)
		if IsValid(ply:GetEntityInUse()) then return end
		
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		local jumpscare = performJumpscare(ply, ent, target, 1.6, "sbaby", 52, "v_scrapbaby")
		
		if !IsValid(target) or !jumpscare then 
			AnimatronicBreakProp(ply, ent)
			return 
		end
	end
}
BABY.land=function(ply,ent)
	if ply:WaterLevel() < 2 then
		if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 then
			if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
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

killers.Register("fh_scrapbaby", "scrapbaby", "Scrap Baby", Color(0,120,255))