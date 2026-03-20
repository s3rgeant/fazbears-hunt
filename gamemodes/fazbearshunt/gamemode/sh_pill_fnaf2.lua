pills.packStart("FH Animatronics","FHPills","icon/fnafur2we.png")

include( "animatronics/wgfreddy.lua" )
include( "animatronics/mangle.lua" )
include( "animatronics/toychica.lua" )

include( "animatronics/freddy.lua" )
include( "animatronics/bonnie.lua" )
include( "animatronics/chica.lua" )
include( "animatronics/foxy.lua" )

include( "animatronics/bear5.lua" )

local model_prefix = IsHalloween() and "phantom" or "old"

if SERVER then
	util.AddNetworkString("JumpscareLight")
	
	util.AddNetworkString("fh_adv_sound_play")
	util.AddNetworkString("fh_ui_sound_play")
	util.AddNetworkString("fh_pos_sound_play")
	util.AddNetworkString("fh_ent_sound_play")
	util.AddNetworkString("fh_3d_sound_play")
	util.AddNetworkString("fh_sound_stop")
	
	util.AddNetworkString("fh_play_voiceline")
	
	util.AddNetworkString("fh_draw_hl_overlay")
	util.AddNetworkString("fh_draw_hl_overlay_timed")
	util.AddNetworkString("fh_nodraw_hl_overlay")
	
	util.AddNetworkString("fh_play_sound")
	
	util.PrecacheModel("models/speps/pill/oldchica.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddy.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddyhead.mdl")
	util.PrecacheModel("models/mountroid/thudner/hw withered pack/endo02.mdl")
	
	resource.AddFile( "materials/models/null.vmt" )
end

function chaseVoicelineChecker(ply, ent, name)
	timer.Create("CheckConditions"..ply:EntIndex(), 2, 0, function()
		if !IsValid(ent) then
			if timer.Exists( "CheckConditions"..ply:EntIndex()) then
				timer.Remove("CheckConditions"..ply:EntIndex())
			end
			if timer.Exists( "ChaseCheck"..ply:EntIndex()) then
				timer.Remove("ChaseCheck"..ply:EntIndex())
			end
			return
		end
		
		chaseCheck(ply, name, ent)
	end)
end

shadow_freddyability = CreateConVar( "fh_sfreddy_noclip", "1", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, 
"Should Shadow Freddy Noclip or just slide throught objects while being invisible?" )

--shadow





--[[
	КД ШЕДОУ МИШКИ
	
	КД на убийство когда вышел из ноуклипа; 	когда вошёл в ноуклип;		когда вышел из него
	
]]
local sfreddy_cooldowns = {1.5, 7, 7.5}

-- ХОДЬБА, БЕГ, ВПРИСЯДИ, СИЛА ПРЫЖКА
local sfreddy_default_movement = {100, 100, 65, 250} -- обычное передвижение
local sfreddy_noclip_movement = {500, 600, 500, 250} -- это на случай если - fuppr_sfreddy_noclip 0

pills.register("pill_sfreddy2",{
	printName="Shadow Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",
		
	options=function() return {
		["default"] = {
			skin = 1,
		},
		["halloween"] = {
			skin = 2,
		}
	} end,
	option=IsHalloween() and "halloween" or "default",

	bodyGroups={[12] = 1},
	
	anims={
		default={
			idle="sidle",
			crouch="scrouch",
			crouch_walk="scrouchmove",
			walk="swalk",
			run="srun",
			cloak="sdisappear",
			uncloak="sappear",
			jump="sjump",
			glide="sglide",
			scare="sscare",
			stun="sstun",
			melee="melee",
			land_snd="land",
		},
		speedCap={
			walk=90,
		},
	},
	moveSpeed={
		walk=sfreddy_default_movement[1],
		run=sfreddy_default_movement[2],
		ducked=sfreddy_default_movement[3],
	},
	sounds={
		jump="sfreddylunge.mp3",
		land="sfreddyland.mp3",
		melee=pills.helpers.makeList("fnaf2/sxscream.wav",2),
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_freddy",
		skin=IsHalloween() and 4 or 2,
		func=function(wep)
			wep.walk_string = "slowwalk"
			wep.walk_act = ACT_WALK_STEALTH
		end
	},
	
	cloak={
		max=-1
	},
    jumpPower=sfreddy_default_movement[4],
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	bloodType=BLOOD_COLOR_MECH,
	
	muteSteps = true,

	noFallDamage=true,
	restore=function(ply,ent)
		ply:SetPushBlocked(false)
		ply._SF_TouchedFloor_Uncloaked = nil
	end,
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "sfreddy")
		ply._SF_TouchedFloor_Uncloaked = true
	end,
	
	killCondition=function(ply,ent)
		if ply:GetMoveType() == MOVETYPE_NOCLIP then return false end
		if cooldown.Exists(ply, "kill") then return false end
		local target = FindNearestPlayer(ply:EyePos(), 130, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ent.cloaked or cooldown.Exists(ply, 'kill') then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 36)
			
			local jumpscare
			
			if ply._SF_TouchedFloor_Uncloaked then
				jumpscare = performJumpscare(ply, ent, target, 1.6, "sfreddy", 52, "v_freddy")
			end
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },
	 
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if cooldown.Exists(ply, 'submerge') then return end
			
			ply:LagCompensation( false )

			if !ply:KeyDown(IN_USE) then
			
				if ent.cloaked then
					local trace = util.TraceHull({
						start = ply:GetPos(),
						endpos = ply:GetPos(),
						mins = ply:OBBMins(),
						maxs = ply:OBBMaxs(),
						filter = ply,
						mask = MASK_PLAYERSOLID,
					})
					
					if trace.Hit then
						net.Start("fh_play_sound")
						net.WriteString('sfreddyerror.wav')
						net.Send(ply)
						return 
					end
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:HandleAnimation("draw", 0.5)
					end
					
					ply:DrawViewModel(true)
					ply:SetPushBlocked(false)
					ply:EmitSound("sfreddyout.mp3")
					
					ent.cloaked=false
					
					hook.Run("FH_SFreddySubmergeOut", ply, ent)
	
					ent:ToggleCloak()
						
					timer.Remove("ext" .. ply:EntIndex())
							
					ply:SetMoveType( MOVETYPE_WALK )
							
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					
					if SERVER then
						if ply:OnGround() then
							cooldown.Set(ply, "kill", sfreddy_cooldowns[1])
							cooldown.Send(ply, "kill")
							
							ply._SF_TouchedFloor_Uncloaked = true
						end
						
						timer.Simple(0.1, function()
							if ply:OnGround() and !ply._SF_TouchedFloor_Uncloaked then
								cooldown.Set(ply, "kill", sfreddy_cooldowns[1])
								cooldown.Send(ply, "kill")
								
								ply._SF_TouchedFloor_Uncloaked = true
							end
						end)
					
						cooldown.Set(ply, "submerge", sfreddy_cooldowns[3])
						cooldown.Send(ply, "submerge")
					end
					
					ent:SetSpeed( unpack(sfreddy_default_movement) )
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.2, 1, function()
						if !IsValid(ent) then return end
						
						ent:PillAnim("uncloak")
						ent:SetMaterial()
						ent:DrawShadow(true)
					end)
				else
					if !ply:OnGround() and ply:WaterLevel() == 0 and !ply:IsStuck() then return end
					if !IsValid(ent) then return end
					cooldown.Set(ply, "submerge", sfreddy_cooldowns[2])
					cooldown.Send(ply, "submerge")
					
					ply:EmitSound("sfreddyin.mp3")
					ply:SetPushBlocked(true)
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:HandleAnimation("deploy", 99999)
					end
					
					ent:PillAnim("cloak")
					
					ply:SetJumpPower( 0 )
					
					timer.Create( "ext" .. ply:EntIndex(), 0.2, 0, function() 
						if !IsValid(ent) then return end
						if ply:Health() < 1000 then ply:SetHealth(ply:Health()+1) end
						if ent:IsOnFire() then ent:Extinguish() end
						if ply:IsOnFire() then ply:Extinguish() end
					end)
					
					ent.cloaked=true
					
					hook.Run("FH_SFreddySubmergeIn", ply, ent)
					ent:ToggleCloak()
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.55, 1, function()
						if !IsValid(ent) then return end
						ply:DrawViewModel(false)
					
						ply._SF_TouchedFloor_Uncloaked = false
						
						if shadow_freddyability:GetInt() == 0 then
							ent:SetSpeed( unpack(sfreddy_noclip_movement) )
						end
						if shadow_freddyability:GetInt() == 1 then
							ply:SetMoveType( MOVETYPE_NOCLIP )
						end
						
						ent:SetMaterial("models/null")
						ent:DrawShadow(false)
						
						ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS )
						
						hook.Run("FH_SFreddySubmergePostIn", ply, ent)
					end)
				end
			end
			ply:LagCompensation( true )
		end
	},
	
	land=function(ply,ent)
		if !ply._SF_TouchedFloor_Uncloaked then
			cooldown.Set(ply, "kill", sfreddy_cooldowns[1])
			cooldown.Send(ply, "kill")
			
			ply._SF_TouchedFloor_Uncloaked = true
		end
		
		if ent.cloaked then return end
		
		ent:PillGesture('land', 2, 1, 0, 0.5)
		ent:PillSound("land_snd", false)
		landTripCheck(ply, ent, "sfreddy")
	end,
 
	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		if ent.cloaked then return end
		ent:PillSound("jump",false)
	end
})



--endo

pills.register("pill_endo02",{
	printName="Endo02",
	model="models/mountroid/thudner/hw withered pack/endo02.mdl",
		
	options=function() return {
		["default"] = {
			bodyGroups = { ["Ears"] = 1 },
			skin = 1,
		},
		["halloween"] = {
			bodyGroups = { ["Ears"] = 1, ["Eyes"] = 4 },
			skin = 1,
		},
		["christmas"] = {
			bodyGroups = { ["Ears"] = 1 },
			skin = 1,
		},
	} end,
	option=IsHalloween() and "halloween" or IsChristmas() and "christmas" or "default",
	
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special",
			jump="jump",
			glide="glide",
			land="land",
			scare="scare",
			stun="stun",
			melee="melee",
		},
	},
	moveSpeed={
		walk=120,
		run=475,
		ducked=160,
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 96),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=66,
	bloodType=BLOOD_COLOR_MECH,
	
	viewmodel={
		weapon="v_endo"
	},
	
    jumpPower=255,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	muteSteps = true,

	noFallDamage=true,
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "endo")
	end,
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_endo")
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if cooldown.Exists(ply, 'grab') then return end
			takePlayer(ply,ent)
		end
	},
	
	land=function(ply,ent)
		if ply:WaterLevel() < 2 then
			if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 then
				if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
					ent:PillAnim("land",true)
				end
			end
		end
		
		landTripCheck(ply, ent, "endo")
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,

	onRemove=function(ent,formTable,ply)
		endoRelease(ply)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
	
})


function fh_can_see_player(observer, target, radius)
    if not IsValid(observer) or not IsValid(target) then return false end

    if radius then
        local distance = observer:GetPos():Distance(target:GetPos())
        if distance > radius then
            return false
        end
    end

    local function can_see_pos(pos)
        local traceData = {
            start = observer:EyePos(),
            endpos = pos,
            filter = function(ent)
                return ent ~= observer
            end,
            mask = MASK_VISIBLE
        }

        local trace = util.TraceLine(traceData)
        if trace.Fraction == 1 or (IsValid(trace.Entity) and trace.Entity:GetPos():Distance(pos) < 5) then
            local dirToTarget = (pos - observer:GetPos()):GetNormalized()
            local viewDot = observer:GetAimVector():Dot(dirToTarget)
            return viewDot > 0.5
        end

        return false
    end

    if can_see_pos(target:EyePos()) then
        return true
    end

    local mapped = pills and pills.getMappedEnt and pills.getMappedEnt(target)
    if IsValid(mapped) and mapped:GetBoneCount() > 0 then
        for boneIndex = 0, mapped:GetBoneCount() - 1 do
            local bonePos = mapped:GetBonePosition(boneIndex)
            if bonePos and can_see_pos(bonePos) then
                return true
            end
        end
    end

    return false
end



-- GFREDDY HEAD

pills.register("pill_wgfreddyhead2",{
	printName="Withered Golden Freddy Head",
	model="models/speps/pill/oldgoldenfreddyhead.mdl",
	bodyGroups={[0] = 1},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			walk="walk",
			out="special",
			inn="tohead",
			run="run",
		},
	},
	modelScale="2.5",
	moveSpeed={
		walk=300,
		run=1000,
		ducked=0,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs={"fnaf2/wgfreddy_glitchsound.wav",
		"fnaf2/wgfreddy_glitchsound2.wav"},
		scream="fnaf2/bonniescream.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	bloodType=BLOOD_COLOR_MECH,
	hull=Vector(32,32,86),
	duckBy=60,
	
	muteSteps = true,
	
	cloak={
		max=-1
	},
    jumpPower=0,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	noFallDamage=true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 75)
			if !IsValid(target) then return end
			target:TakeDamage(target:Health() + target:Armor(), ply)
			ent:PillSound("melee",false)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end
		end
	},
	
	flashlight=function(ply,ent)
		if !ply:OnGround() then return end

		timer.Simple(.1,function()
			if !IsValid(ent) then return end
			local tracein={}
			tracein.maxs=Vector(16,16,72)
			tracein.mins=Vector(-16,-16,0)
			tracein.start=ply:EyePos()
			tracein.endpos=ply:EyePos()+ply:EyeAngles():Forward()*9999
			tracein.filter = {ply,ent}

			local traceout= util.TraceHull(tracein)
			ply:SetPos(traceout.HitPos)
			ent:PillSound("teleport")
		end)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("gs",false)
	end
})

function playVoiceline(character, line, who, when)
	if CLIENT then return end

	if who:IsSpeaking() then return end

	if ( timer.Exists( "fh_PlayVoiceLine" .. who:SteamID64()) or timer.Exists( "fh_DontVoiceLine" .. who:SteamID64() ) ) then return end
	
	timer.Create("fh_PlayVoiceLine" .. who:SteamID64(), when or 0, 1, function()
		local ent = pills.getMappedEnt(who)
		
		if IsValid(ent) then
			local FH_OverrideVoiceline = hook.Run("FH_OverrideVoiceline", who, character, line)
			if FH_OverrideVoiceline ~= nil and isstring(FH_OverrideVoiceline) then
				line = FH_OverrideVoiceline
			end
			
			local rf = RecipientFilter()
			
			for _, ply in player.Iterator() do
				if ply:GetInfoNum("fh_voicelines", 1) == 0 then continue end
				
				if hook.Run("FH_PlayerShouldHearVoiceline", ply, who,
				{char = character, voiceline = line} ) == false then continue end
				
				rf:AddPlayer(ply)
			end
			
			local isHalloweenish = {
				["freddy"] = true,
				["bonnie"] = true,
				["chica"] = true,
				["foxy"] = true,
				["endo"] = true
			}
			
			local dsp = IsHalloween() and isHalloweenish[character] and 38 or 0
			
			who:EmitSound(character .. "." .. line, 75, 100, 1, CHAN_VOICE, 0, dsp, rf)
			
			--[[
			net.Start("fh_play_voiceline")
			net.WriteString(character)
			net.WriteString(line)
			net.WritePlayer(who)
			net.Broadcast()
			]]--
			
			timer.Create("fh_DontVoiceLine" .. who:SteamID64(), 5, 1, function() end)
		end
	end)
end

hook.Add("FH_OverrideVoiceline", "fh_lastkill_vc", function(ply, anim, line)
	if line:match("kill") and !line:match("last") then
		if anim ~= "sfreddy" then
			if #team.GetPlayers(TEAM_SURVIVOR) == 0 then
				return "lastkill"
			end	
		end
	end
end)

function FindNearestPlayer(origin, radius, ignorePlayer, fov)
    local nearestPlayer = nil
    local nearestDistance = radius

    local useFov = fov and fov > 0
    local candidates
    local eyePos = IsValid(ignorePlayer) and ignorePlayer:EyePos() or origin

    if useFov and IsValid(ignorePlayer) then
        local dir = ignorePlayer:EyeAngles():Forward()
        candidates = ents.FindInCone(eyePos, dir, radius, math.cos(math.rad(fov)))
		
    else
        candidates = ents.FindInSphere(origin, radius)
    end

    for _, ply in ipairs(candidates) do
        if ply ~= ignorePlayer and ((ply:IsPlayer() and ply:IsSurvivor()) or ply:IsNPC()) then
            local pos = ply:GetPos()
            local distance = origin:Distance(pos)
            if distance <= nearestDistance then
                local trace = util.TraceLine({
                    start = eyePos,
                    endpos = ply:GetPos() + ply:OBBCenter(),
                    filter = function(ent) return !ent:IsPlayer() and ent ~= ignorePlayer and ent ~= ply end
                })
                if not trace.Hit then
                    nearestDistance = math.sqrt(distance)
                    nearestPlayer = ply
                end
            end
        end
    end

    return nearestPlayer
end

function fh_get_nearest_players(origin, radius, ignorePlayer)
    local players = {}

    for _, ply in ipairs( ents.FindInSphere( origin, radius ) ) do
        if ply ~= ignorePlayer and ((ply:IsPlayer() and ply:IsSurvivor()) or ply:IsNPC()) then
			local trace = util.TraceLine({
				start = origin,
				endpos = ply:GetPos(),
				filter = function(ent)
				return ent != ignorePlayer and !ent:IsPlayer() and !ent:IsNPC() and ent:GetClass() != "fh_gift"
				end
			})
			if !trace.Hit then
				table.insert(players, ply)
			end
        end
    end

	if !table.IsEmpty(players) then
		return players
	end
	return nil
end

function fh_get_nearest_props(origin, radius)
    local props = {}

    for _, v in ipairs( ents.FindInSphere( origin, radius ) ) do
        if v:GetClass() == 'prop_physics' or v:GetClass() == 'prop_dynamic' or v:GetClass() == 'func_breakable_surf' or v:GetClass() == 'func_breakable' then
			table.insert(props, v)
        end
    end

	if !table.IsEmpty(props) then
		return props
	end
	return nil
end

local playersHoldingRightClick = {}
local noClipBlockedPlayers = {}
resource.AddFile("sound/grab_player.wav")
resource.AddFile("sound/throw_player.wav")

function performJumpscare(ply, ent, target, killDelay, voiceCharacter, jumpscareDistance, wepClass)
	if not IsValid(target) then return false end
	
	if target:IsPlayer() and target:HasGodMode() then return false end
	
	if target:Health() <= 0 then return end
	
	if target:IsJumpscared() then return end
	
	if hook.Run("FH_PlayerShouldJumpscare", ply, ent, target) == false then return false end

	hook.Run("FH_AnimatronicJumpscare", ply, ent, target, 
		{delay = killDelay, char = voiceCharacter, dist = jumpscareDistance, wep = wepClass}
	)

	ent:PillSound("melee", false)

	target:SetJumpscared(true)
	ply.jumpscaring = target

	ply:LagCompensation(false)
	jumpscareEvent(ply, ent, target, jumpscareDistance or 50)
	ent:PillAnim("scare", true)
	ply:LagCompensation(true)
	
	cooldown.Set(ply, "kill", killDelay)
	cooldown.Send(ply, "kill")

	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == wepClass then
		wep:HandleAnimation("scare", 1.6)
	end

	timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), killDelay, 1, function()
		if IsValid(ent) then
			ent:SetUseForceAngles(false)
		end
		if IsValid(ply) then 
			ply:Freeze(false)
			ply.jumpscaring = nil
		end
		if IsValid(target) then 
			target:SetJumpscared(false)
			
			if target:IsPlayer() then
				target:Freeze(false)
			end
			
			local armor = target:IsPlayer() and target:Armor() or 0
			
			target:TakeDamage(target:Health() + armor, ply)
		end
	end)
	
	return true
end

local ENTITY = FindMetaTable("Entity")

function ENTITY:SetJumpscared(bool)
	self:SetNW2Bool("_FH_Jumpscared", bool or false)
end

function ENTITY:IsJumpscared()
	return self:GetNW2Bool("_FH_Jumpscared")
end

function jumpscareEvent(ply, ent, target, dist)
	if CLIENT then return end
	if not IsValid(target) then return end

	local distance = dist or 50
	local attackerPos = ply:GetPos()
	local attackerForward = ply:GetForward()

	local forwardPos = attackerPos + attackerForward * distance
	local backwardPos = attackerPos - attackerForward * distance

	local plyMins, plyMaxs = ply:OBBMins(), ply:OBBMaxs()
	local targetMins, targetMaxs = target:OBBMins(), target:OBBMaxs()

	local forwardTr = util.TraceHull({
		start = forwardPos,
		endpos = forwardPos,
		mins = targetMins,
		maxs = targetMaxs,
		mask = MASK_PLAYERSOLID,
		filter = { ply, target }
	})

	local backwardTr = util.TraceHull({
		start = backwardPos,
		endpos = backwardPos,
		mins = targetMins,
		maxs = targetMaxs,
		mask = MASK_PLAYERSOLID,
		filter = { ply, target }
	})

	local canTeleportForward = not forwardTr.Hit
	local canTeleportBackward = not backwardTr.Hit

	local teleportPlyPos = nil
	local teleportTargetPos = nil

	if canTeleportForward then
		teleportPlyPos = attackerPos
		teleportTargetPos = forwardPos
	elseif canTeleportBackward then
		teleportPlyPos = backwardPos
		teleportTargetPos = backwardPos + attackerForward * distance
	end

	hook.Run("FH_JumpscareEvent", ply, ent, target, dist)

	if target:IsPlayer() then
		net.Start("JumpscareLight")
		net.Send(target)
	end

	target:DropToFloor()
	ply:DropToFloor()

	if target:IsPlayer() then
		target:Freeze(true)
	end
	ply:Freeze(true)

	local target_phys = target:GetPhysicsObject()
	if IsValid(target_phys) then
		target_phys:SetVelocityInstantaneous(Vector(0, 0, 0))
	end
	target:SetVelocity(-target:GetVelocity())

	local ply_phys = ply:GetPhysicsObject()
	if IsValid(ply_phys) then
		ply_phys:SetVelocityInstantaneous(Vector(0, 0, 0))
	end
	ply:SetVelocity(-ply:GetVelocity())

	util.ScreenShake(target:GetPos(), 5, 5, 2, 500)

	if teleportPlyPos and teleportTargetPos then
		ply:SetPos(teleportPlyPos)
		target:SetPos(teleportTargetPos)
	end
	
	if target:IsNPC() then -- я хз чё тут делать
		target:MoveStop()
		target:MovePause()
		target:StopMoving()
		target:ResetMoveCalc()
		target:ClearGoal()
		target:ClearSchedule()
		target:TaskComplete()
	end

	local directionToTarget = (target:EyePos() - ply:EyePos()):Angle()
	ply:SetEyeAngles(directionToTarget)
	directionToTarget.p = 0
	ent:SetForceAngles(directionToTarget)
	ent:SetUseForceAngles(true)

	if target:IsPlayer() then
		local directionToAttacker = (ply:GetPos() - target:GetPos()):Angle()
		target:SetEyeAngles(directionToAttacker)
	end
end

local takenPlayers = {}

function takePlayer(ply, ent)

    local nearestPlayer = FindNearestPlayer(ply:EyePos(), 125, ply, 75)
	
	if !takenPlayers[ply] then
		takenPlayers[ply] = {}
	end
	
	local remember_taken = takenPlayers[ply]

    if IsValid(nearestPlayer) and (nearestPlayer:IsPlayer() and !nearestPlayer:IsFrozen() or nearestPlayer:IsNPC()) then
		if hook.Run("FH_HandlePlayerGrab", ply, nearestPlayer) == false then return end
		
		if !table.HasValue(remember_taken, nearestPlayer) then
			table.insert(remember_taken, nearestPlayer)
			
			takenPlayers[ply] = remember_taken
			stats.Add(ply, "grabbed", 1)
		end
		
		ply:EmitSound("grab_player.wav")
		
		if ent.formTable.name == "pill_endo02" then
			if math.random(1,10) > 2 then
				playVoiceline("endo", 'grab', ply, 0.2)
			end
		end
		
        nearestPlayer:SetMoveType(MOVETYPE_NONE)
        nearestPlayer:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		
		nearestPlayer:SetNWEntity("MyEndoGrabber", ply)

        noClipBlockedPlayers[nearestPlayer] = true

        playersHoldingRightClick[ply] = nearestPlayer
		ply._endoHoldingPlayer = nearestPlayer

        timer.Create("UpdateCameraAndPosition" .. ply:EntIndex(), 0.01, 0, function()
			if !IsValid(ply) or !ply:KeyDown(IN_ATTACK2) then
				timer.Remove("UpdateCameraAndPosition" .. ply:EntIndex())
				return
			end
		
			if IsValid(nearestPlayer) then
				local eyePos = ply:EyePos()
				nearestPlayer:SetEyeAngles((eyePos - nearestPlayer:EyePos()):Angle())
				
				local vectorOffset = 50
				
				if ply:Crouching() then vectorOffset = 5 end
		
				local offset = (ply:EyeAngles():Forward() * 50)
				local newPos = ((ply:GetPos() + ply:EyePos()) / 2) + offset
		
				local traceData = {}
				traceData.start = ply:EyePos()
				traceData.endpos = newPos
				traceData.filter = {ply, nearestPlayer}
		
				local trace = util.TraceEntity(traceData, nearestPlayer)
		
				if trace.Hit then
					local safeDistance = trace.Fraction * 50
					offset = (Vector(0, 0, vectorOffset)) + (ply:EyeAngles():Forward() * safeDistance)
					newPos = ply:GetPos() + offset
				end
				debugoverlay.Line(traceData.start, traceData.endpos, 0.05, Color(255, 0, 0), true)
				--debugoverlay.Box( newPos, traceData.mins, traceData.maxs, 0.05, Color( 255, 255, 255, 20 ) )
		
				nearestPlayer:SetPos(newPos)
			end
		end)
    end
end

hook.Add("KeyRelease", "endo_key_release", function(ply, key)
    if key == IN_ATTACK2 then
		ply:LagCompensation(true)
		endoRelease(ply)
		ply:LagCompensation(false)
    end
end)

function endoRelease(ply, noVoiceline)
	noVoiceline = noVoiceline or false
	local target = playersHoldingRightClick[ply]
	if IsValid(target) then
		if ply:Alive() then
			ply:EmitSound("throw_player.wav")
		end
		if !noVoiceline then
			if math.random(1,10) > 2 then
				playVoiceline("endo", 'throw', ply, 0.1)
			end
		end
	
		target:SetMoveType(MOVETYPE_WALK)
		target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		noClipBlockedPlayers[target] = nil
		
		target._GrabbedByEndoTime = CurTime()
		target._LastEndo = ply
		
		target:SetNWEntity("MyEndoGrabber", NULL)
		
		local plyPos = ply:GetPos()
		local plyHeight = ply:OBBMaxs().z - ply:OBBMins().z
		local targetHeight = target:OBBMaxs().z - target:OBBMins().z
		local newPos = plyPos + Vector(0, 0, plyHeight - targetHeight)

		local traceData = {}
		traceData.start = target:GetPos()
		traceData.endpos = target:GetPos()
		traceData.filter = {ply, target}

		local trace = util.TraceEntity(traceData, target)

		if trace.Hit then
			target:SetPos(newPos)
		end
	
		local direction = (ply:EyeAngles():Forward() * 50):GetNormalized()
		target:SetVelocity(direction * 800)
	
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		
		hook.Run("fh_endo_release", ply, target)
		
		timer.Simple(1, function()
			if IsValid(target) then
				if target:IsStuck() then
					target:Unstuck()
				end
			end
		end)
	
		cooldown.Set(ply, 'grab', 1)
		cooldown.Send(ply, "grab")
	
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
	
		-- чтобы случайно не вернуть коллизию пока он в пропе или ещё гдета
		timer.Create("CheckCollisionReset" .. ply:EntIndex(), 0.5, 0, function()
			if IsValid(ply) and not IsStuck(ply) then
				ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			end
			if IsValid(target) and not IsStuck(target) and noClipBlockedPlayers[target] == nil then
				target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			end
	
			if (not IsValid(ply) or not IsStuck(ply)) and 
			(not IsValid(target) or not IsStuck(target)) then
				timer.Remove("CheckCollisionReset" .. ply:EntIndex())
			end
		end)
	end
	
	playersHoldingRightClick[ply] = nil
	ply._endoHoldingPlayer = nil
	timer.Remove("UpdateCameraAndPosition" .. ply:EntIndex())
end

function breakBustDoor(ply, door, dur)
	local dur = dur or 90
	if not IsValid(door) then return end

	local mdl = door:GetModel()
	if not mdl then return end

	local pos = door:GetPos()
	local ang = door:GetAngles()
	local skin = door:GetSkin()

	local mins = door:OBBMins()
	local maxs = door:OBBMaxs()

	door:Fire("Unlock", "", 0)
	door:Fire("Open", "", 0)
	
	local oldColl = door:GetCollisionGroup()

	door:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
	timer.Simple(0, function()
		if IsValid(door) then
			door:SetNoDraw(true)
            door:SetNotSolid(true)
			
			for _, child in pairs(door:GetChildren()) do
				child:SetNoDraw(true)
                child:SetNotSolid(true)
			end
		end
	end)

	local physDoor = ents.Create("prop_physics")
	if not IsValid(physDoor) then return end

	physDoor:SetModel(mdl)
	physDoor:SetPos(pos)
	physDoor:SetAngles(ang)
	physDoor:SetSkin(skin)
	physDoor:Spawn()
	physDoor:Activate()

	physDoor:SetCollisionBounds(mins, maxs)

	local phys = physDoor:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(35)
		phys:Wake()
	end
	
	timer.Simple(dur, function()
		if IsValid(physDoor) then
			physDoor:Dissolve()
		end
	end)
	
	timer.Simple(dur + 20, function()
		if IsValid(door) then
			
			local timerName = "door_back_fh_" .. door:EntIndex()
			
			timer.Create(timerName, 5, 0, function()
				if !IsValid(door) then
					timer.Remove(timerName)
					return
				end
				
				local playerFound = false
				
				for _, ent in ipairs(ents.FindInSphere( door:GetPos(), 300 )) do
					if ent:Alive() and ent:IsPlayer() then
						playerFound = true
						break
					end
				end
				
				if !playerFound then
					door:SetNoDraw(false)
					door:SetNotSolid(false)
					for _, child in pairs(door:GetChildren()) do
						child:SetNoDraw(false)
						child:SetNotSolid(false)
					end
					door:SetCollisionGroup(oldColl)
					timer.Remove(timerName)
				end
			end)
		end
	end)
	
	timer.Simple(1, function()
		if IsValid(phys) then
			phys:SetMass(200)
		end
	end)

	physDoor:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
	stats.Add(ply, "broke_doors", 1)

	if IsValid(phys) then
		local dir = ply:GetForward()
		phys:ApplyForceCenter(dir * 15000)
	end

	sound.Play("Wood_Crate.Break", pos, 90, math.random(90,110))
	util.ScreenShake(pos, 5, 5, 0.5, 200)
end

hook.Add("FuncDoorBust", "fh_charge_doorbust", function(ply, door)
	local puppet = pills.getMappedEnt(ply)
	if not IsValid(puppet) then return end
	local name = puppet.formTable.name

	if name == "pill_wfoxy" and ply:GetNWBool("isBlightRushing") then
		breakBustDoor(ply, door)
	end
end)

if SERVER then
	local function fnaf2pill_death_handle(victim, inflictor, attacker)
		if victim:IsJumpscared() then
			victim:SetJumpscared(false)
			if IsValid(attacker) and attacker:IsPlayer() then
				attacker.jumpscaring = nil
			end
		end
	end

	hook.Add( "PlayerDeath", "fh_pill_fnaf2_death", fnaf2pill_death_handle)
	hook.Add( "PlayerSilentDeath", "fh_pill_fnaf2_silentdeath", fnaf2pill_death_handle)
	
	hook.Add("FH_AnimatronicJumpscare", "fh_kill_voicelines", function(ply, ent, target, data)
		local voiceCharacter = data.char
		local vc_delay = data.delay
		
		if voiceCharacter ~= nil then
			playVoiceline(voiceCharacter, "kill", ply, vc_delay)
		end
	end)

	function landTripCheck(ply, ent, name)
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				local shouldPlay, forceVoiceline = hook.Run("FH_LandTripHandler", ply,ent,name)
				if shouldPlay == true or shouldPlay == nil then
					local vc = forceVoiceline or "trip"
					playVoiceline(name, vc, ply, 0.1)
				end
			end
		else
			ent.landTimes = 1
		end
		timer.Simple(3,function()
			if ent.landTimes == 0 or !IsValid(ent) then return end
			ent.landTimes = ent.landTimes - 1
		end)
	end
	
	hook.Add("OnPlayerPhysicsDrop", "fh_endo_prop_drop", function(ply, ent, thrown)
		local puppet = pills.getMappedEnt(ply)
		if !IsValid(puppet) then return end
		name = puppet.formTable.name
		
		if name ~= "pill_endo02" then return end
		
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then 
			if thrown then
				local dir = ply:GetAimVector()
				phys:ApplyForceCenter(dir * 20000 * math.min(70, phys:GetMass()))
			else
				ent._lastHoldTime = CurTime()
			end
		end
			
		ply:SetNW2Entity("HeldEnt", NULL)
	end)
	
	hook.Add("PlayerUse", "fh_endo_largeprop_pickup", function(ply, ent)
		local puppet = ply:GetPill()
		if not IsValid(puppet) or puppet.formTable.name ~= "pill_endo02" then return end
		if not IsValid(ent) then return end

		if ent._lastHoldTime and CurTime() < ent._lastHoldTime + 0.5 then return end

		local phys = ent:GetPhysicsObject()
		if not IsValid(phys) then return end

		if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return end
		if not phys:IsMoveable() then return end
		if ent:IsPlayerHolding() then return end
		if ent:GetParent():IsValid() then return end
		if constraint.HasConstraints(ent) then return end

		local mass = phys:GetMass()
		if mass < 35 or mass > 800 then return end

		phys:EnableMotion(true)
		phys:Wake()
		phys:ApplyForceCenter(VectorRand() * 5)

		timer.Simple(0, function()
			if IsValid(ply) and IsValid(ent) and not ent:IsPlayerHolding() then
				ply:PickupObject(ent)
			end
		end)
	end)

	hook.Add("OnPlayerPhysicsPickup", "fh_endo_pickup", function(ply, ent)
		local puppet = ply:GetPill()
		if not IsValid(puppet) or puppet.formTable.name ~= "pill_endo02" then return end
		if !IsValid(ent:GetPhysicsObject()) then return end
		ply:SetNW2Entity("HeldEnt", ent)
	end)
else
	local fh_voicelines = CreateClientConVar("fh_voicelines", "1", true, true, "Should play any animatronic voicelines?", 0, 1)
end
	
hook.Add("PlayerNoClip", "endo_targets_noclip_handle", function(ply, desiredState)
	if noClipBlockedPlayers[ply] then
		return false
	end
end)

function AnimatronicBreakProp(ply, ent, cooldown)
	local cooldown = cooldown or 1
	if ply._breakPropAsAnimTime and ply._breakPropAsAnimTime > CurTime() then
		return
	end

	local startPos = ply:GetShootPos()
	local endPos = startPos + ply:GetAimVector() * 130

	local tr = util.TraceLine( {
		start = startPos,
		endpos = endPos,
		filter = ply,
		mask = MASK_SHOT
	})
	
	debugoverlay.Line(ply:EyePos(), tr.HitPos, 5, Color(255, 0, 0), true)
	
	local target = tr.Entity
	
	if !IsValid(target) then
		return
	end
	
	local fh_animatronic_break_prop = hook.Run("fh_animatronic_break_prop", ply, ent, tr)
	
	if fh_animatronic_break_prop == false then
		return
	end
	
    local class = target:GetClass()
    if class == "func_breakable" or class == "func_breakable_surf" then
        target:Fire("Shatter", "0", 0)
    end
	
	if target:GetMoveType() == MOVETYPE_VPHYSICS then
		local owner = target:GetOwner()
		if !IsValid(owner) or IsValid(owner) and owner:IsPlayer() and !owner:IsAnimatronic() then
		
			local phys = target:GetPhysicsObject()
			if IsValid(phys) then
				local dir = ply:GetAimVector()
				phys:ApplyForceCenter(dir * 10000)
			end
		end
	end
	
	if !target:IsPlayer() then
		local wep = ply:GetActiveWeapon()
	
		ply:EmitSound("bonnie_punch.mp3")
		
		ent:PillGesture('melee', 2, 1, 0.1, 0.7)
		
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker( ply )
		dmginfo:SetInflictor( IsValid(wep) and wep or ply )
		dmginfo:SetDamage( 100 )
	
		SuppressHostEvents( NULL )
		target:TakeDamageInfo( dmginfo )
		SuppressHostEvents( ply )
		if IsValid(wep) then
			wep:HandleAnimation("attack", 1, true)
		end
		
		ply._breakPropAsAnimTime = CurTime() + cooldown
			
		local effectData = EffectData()
		effectData:SetOrigin(tr.HitPos)
		effectData:SetStart(ply:GetShootPos())
		effectData:SetEntity(tr.Entity or ply)
		effectData:SetNormal(tr.HitNormal)
		effectData:SetSurfaceProp(tr.SurfaceProps or 0)
		effectData:SetDamageType(DMG_CLUB)
		effectData:SetHitBox(tr.HitBox or 0)
		effectData:SetScale(1)
		
		util.Effect("Impact_GMOD", effectData, true, true)
	end
	
	hook.Run("fh_animatronic_post_break_prop", ply, ent, tr)
end

hook.Add("FH_ChaseVoicelineHandler", "killer_mask_animvc", function(ply,ent,name)
	if IsValid(target) and target:GetNW2Bool("KillerObsessed") then
		return true, "negative"
	end
end)

function chaseCheck(ply, name, ent)
	if timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
	
	if IsValid(ent) and ent.cloaked then return end
	
	if (ply:IsSprinting() or ply:GetWalkSpeed() == ply:GetRunSpeed()) and ply:GetVelocity():LengthSqr() > ply:GetRunSpeed() * 0.9 then
		local target = FindNearestPlayer(ply:GetPos(), 750, ply, 75)
		
		if !IsValid(target) or outworld_victims[target] then return end
		if target:IsNPC() then return end
		
		if target:IsSprinting() and target:GetVelocity():LengthSqr() > target:GetWalkSpeed() and !target:IsInvisible() then
			local shouldPlay, forceVoiceline, newCooldown = hook.Run("FH_ChaseVoicelineHandler",ply,ent,name)
			
			if shouldPlay == true or shouldPlay == nil then
				local vc = forceVoiceline or "chase"

				playVoiceline(name, vc, ply, 1)
			end
			
			local vc_cooldown = newCooldown or 15
			
			timer.Create("ChaseCheck"..ply:EntIndex(), vc_cooldown, 1, function() end) -- шобы войслайны не играли очень часто
		end
	end
end

hook.Add( "PostCleanupMap", "fh_pill_fnaf2_reset", function()
	table.Empty(takenPlayers)
end)