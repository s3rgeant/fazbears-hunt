AddCSLuaFile()

if SERVER then
	util.AddNetworkString("bear5_bell")
	
	util.AddNetworkString("fox_request")
	util.AddNetworkString("fox_request_start")
	util.AddNetworkString("fox_request_get")
	util.AddNetworkString("fox_request_complete")

	util.PrecacheModel("models/fh/animatronics/bear5.mdl")
	util.PrecacheModel("models/fh/animatronics/fox4.mdl")
end

sound.Add({
	name = 			"bearling.foot",
	channel = 		CHAN_STATIC,
	level = 		75,
	volume = 		1.0,
	sound = 			{")bear/bearling_softstep.wav"}
})

function bearScream(ply, ent)
	if !ply._BearScreamSound or !IsValid(ply._BearScreamSound) then
		ply._BearScreamSound = CreateSound(ply, ")bear/bear5_jumpscare.wav")
	elseif ply._BearScreamSound:IsPlaying() then
		ply._BearScreamSound:Stop()
	end
	
	ply._BearScreamSound:Play()
			
	ent:PillGesture('scream', 5, 1, 0.1, 0.1)
	
	local timerName = ply:EntIndex() .. "_Bear5Scream"
	
	if timer.Exists(timerName) then
		timer.Remove(timerName)
	end
	
	timer.Create(timerName, math.random(2,34)/ 10, 1, function()
		if IsValid(ply) and IsValid(ent) then
			ply._BearScreamSound:Stop()
			ent:PillStopGesture('scream')
		end
	end)
end

local bearRequester
local foxPlayerReq
pills.clone("bear5_main", "pill_wfreddy2", {
	printName="Bear 5",
	
	model="models/speps/pill/oldfreddy.mdl",
	
	anims={
		default={
			idle="bear5_idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="bear5_run",
			scare="scare",
			jump="jump",
			glide="air",
			land="land",
			stalk="stalk",
			stun="stun",
			
			pumpit="pumpit",
		},
		gestures={
			melee="melee",
			
			swing="preattack",
			attack="attack",
			scream="scream",
		},
	},
	option="default",
	
	moveSpeed={
		walk=150,
		run=500,
		ducked=75,
	},
	sounds={
		jump="bear/bear_jump.mp3",
		land="bear/bear_land.mp3",
	},
	
	options=function() return {
		["default"] = {
			bodyGroups = {
				[0] = 1, 
				["Microphone"] = 1},
			skin=1,
		}
	} end,
	option="default",
	
	viewmodel={
		weapon="v_bear",
		skin=5,
		bodyGroup="Microphone",
	},
	
	killCondition=function(ply,ent)
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
		end
    },
	
	attack2={
		mode="trigger",
		func=function(ply,ent)
			if cooldown.Exists(ply, "death") or IsValid(bearRequester) then return end
			
			local rf = RecipientFilter()
			rf:AddRecipientsByTeam(TEAM_PILLS)
			
			rf:RemovePlayer(ply)
			
			if rf:GetCount() > 0 then
				net.Start("fox_request_start")
				net.Send(rf)
				
				bearRequester = ply
			
				cooldown.Set(ply, "death", 666)
				cooldown.Send(ply, "death")
				return
			end
			
			ply:ChatPrint("No players found")
		end
    },
	
	boneMorphs={
		["bip_eye_R"] = {scale = Vector(0.5,0.5,0.5)},
		["bip_eye_L"] = {scale = Vector(0.5,0.5,0.5)},
		["bip_EyeLid_0_R"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_1_R"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_0_L"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_1_L"] = {scale = Vector(0,0,0)},
	},
	
	initialize=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "freddy")
		cooldown.Set(ply, "death", 60 * 7) -- 6 минут раунда
		timer.Simple(3, function()
			cooldown.Send(ply, "death")
		end)
	end,
	
	restore=function(ply,ent)
		if CLIENT then return end
		
		cooldown.Set(ply, "death", 0)
		
		if IsValid(bearRequester) then
			bearRequester = nil
		end
	end,
})

net.Receive("fox_request", function(len, ply)
	if !IsValid(bearRequester) then
		if !IsValid(foxPlayerReq) then
			ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.bear5.foxerror') )" )
		else
			ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.bear5.foxchoosed') )" )
		end
		return
	end
	
	net.Start("fox_request_get")
	net.WritePlayer(ply)
	net.Send(bearRequester)
end)

net.Receive("fox_request_complete", function(len, ply)
	if not bearRequester == ply then return end
	
	local foxPly = net.ReadPlayer()
	
	if IsValid(foxPly) and !IsValid(foxPlayerReq) then
		giveKiller(foxPly, "fox4", true)
		foxPlayerReq = foxPly
	end
	
	bearRequester = nil
end)

hook.Add( "PillCostumeEmitSound", "bear5_footsteps", function( t )
	if t.Entity.formTable and t.Entity.formTable.name == "bear5_main" and t.OriginalSoundName == "freddy.foot1" then
		t.OriginalSoundName = "bear.foot1"
		local bear_feet = sound.GetProperties("bear.foot1")
		
		t.SoundName = bear_feet.sound[math.random(1,#bear_feet.sound)]
		
		return true, t
	end
end)

pills.register("bear5_clone",{
	printName="Bear 5 Clone",
	
	model="models/fh/animatronics/bear5.mdl",
	modelScale="0.7",
	
	health=2000,
	type="ply",
	
    camera = {
        offset = Vector(0, 0, 50),
		dist = 100
    },
	hull=Vector(32,32,50),
	
	duckBy=30,
	stepSize=24,
    jumpPower=240,
	
	bloodType=BLOOD_COLOR_MECH,
	muteSteps = true,
	noFallDamage=true,
	movePoseMode="xy",
	
	anims={
		default={
			idle="idle",
			walk="run",
			run="run",
			jump="jump",
			glide="glide",
		},
		gestures={
			attack="attack",
		},
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
	},
	
	moveSpeed={
		walk=475,
		ducked=150,
	},
	
	viewmodel={
		weapon="v_bearling",
	},
	
	boneMorphs={
		["bip_eye_R"] = {scale = Vector(0.5,0.5,0.5)},
		["bip_eye_L"] = {scale = Vector(0.5,0.5,0.5)},
		["bip_EyeLid_0_R"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_1_R"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_0_L"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_1_L"] = {scale = Vector(0,0,0)},
	},
	
	startFunction=function(ply,ent)
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		ply:CollisionRulesChanged()
	end,
	
	restore=function(ply,ent, formtable)
		ply:SetCollisionGroup(COLLISION_GROUP_NONE)
	end,
})

local fox4_victims = {}
pills.register("fox4",{
	printName="Fox 4",
	
	model="models/fh/animatronics/fox4.mdl",
	modelScale="1.1",
	
	health=5000,
	type="ply",
	
    camera = {
        offset = Vector(0, 0, 76),
		dist = 100
    },
	hull=Vector(32,32,82),
	
	duckBy=55,
	stepSize=24,
    jumpPower=300,
	
	bloodType=BLOOD_COLOR_MECH,
	muteSteps = true,
	noFallDamage=true,
	movePoseMode="xy",
	
	anims={
		default={
			idle="idle",
			scare="scare",
		},
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee="bear/fox4_jumpscare.wav",
	},
	
	moveSpeed={
		walk=700,
		ducked=150,
	},
	
	viewmodel={
		weapon="v_fox4",
	},
	
	startFunction=function(ply,ent)
		ply:SetJumpBoost(0)
	end,
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() and !target:IsJumpscared() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 125, ply, 36)
			
			if fox4_victims[ply] and fox4_victims[ply][target] then
				AnimatronicBreakProp(ply, ent)
				return
			end
			
			local jumpscare = performJumpscare(ply, ent, target, 3, "fox4", 60, "v_foxy")
			
			if !IsValid(target) or target:HasGodMode() or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
			
			if !fox4_victims[ply] then fox4_victims[ply] = {} end
			fox4_victims[ply][target] = true
		end
    },
	
	onRemove=function(ply, ent)
		if CLIENT then return end
		net.Start("player_renderer_clear_e")
		net.Send(ply)
		
		fox4_victims[ply] = nil
		
		if foxPlayerReq == ply then
			foxPlayerReq = nil
		end
		
		ply:SetJumpBoost( getScaledJumpBoost() )
	end,
})

hook.Add( "PlayerSpawn", "fox4_notarget", function( ply )
	for fox4,v in pairs(fox4_victims) do
		if IsValid(fox4) and fox4_victims[fox4][ply] then
			fox4_victims[fox4][ply] = nil
					
			net.Start("player_renderer_draw")
			net.WriteEntity(ply)
			net.Send(fox4)
		end
	end
end)

hook.Add( "PostCleanupMap", "bear5_cleanup", function( )
	foxPlayerReq = nil
end)

hook.Add( "EntityTakeDamage", "fox4_screamer", function( target, dmginfo )
    if target:IsPlayer() and target:IsSurvivor() then
		local attacker = dmginfo:GetAttacker()
		local damage = dmginfo:GetDamage()
		
        if IsValid(attacker) and attacker:IsPlayer() and IsValid(attacker:GetPillCostume()) and (attacker:GetPillCostume():GetPillName():match("fox4") == "fox4")  then
			if target:Health() > 1 and !target:GetNW2Bool("KillerObsessed") then
				target:SetArmor(0)
				dmginfo:SetDamage(target:Health() - 1)
				
				net.Start("player_renderer_nodraw")
				net.WriteEntity(target)
				net.Send(attacker)
			end
        end
    end
end )

killers.Register("bear5_main", "bear5", "Bear 5", Color(0,120,255), "Freaks")
killers.Register("bear5_clone", "bearling5", "Bearling 5", Color(0,120,255), "Freaks")
killers.Register("fox4", "fox4", "Fox 4", Color(0,255,20), "Freaks")

killers.SetAbilities("bear5", {
	{ name = 'highlight', key = 'R' },
	{ name = 'death', key = 'RMB' },
})

hook.Add("FuncDoorBust", "fh_fox4_doorbust", function(ply, door)
	local puppet = pills.getMappedEnt(ply)
	if not IsValid(puppet) then return end
	local name = puppet.formTable.name

	if name == "fox4" and ply:GetVelocity():Length() > 400 then
		breakBustDoor(ply, door)
	end
end)

hook.Add( "PlayerHurt", "fh_bear_damage_bell", function( ply, attacker, healthRemaining, damageDealt )
	if IsValid(attacker) then
		if ply:IsPlayer() and attacker:IsPlayer() and IsValid(attacker:GetPill()) and (attacker:GetPill():GetPillName():match("bear5_main") == "bear5_main") then
			if healthRemaining > 0 then
				net.Start("bear5_bell")
				net.Send(ply)
			end
		end
	end
end )

hook.Add("FH_ChaseVoicelineHandler", "bear5_chasevc", function(ply,ent,name)
	if IsValid(ent) and ent.formTable.name == "bear5_main" then
		bearScream(ply,ent)
		return false, nil, 3
	end
end)

hook.Add("FH_LandTripHandler", "bear5_chasevc", function(ply,ent,name)
	if ent.formTable.name == "bear5_main" then
		bearScream(ply,ent)
		return false, nil
	end
end)

if SERVER then return end -- дальше бога нет

local bearimages = {
	Material("bear5/bear1.png"),
	Material("bear5/bear2.png"),
	Material("bear5/bear3.png"),
	Material("bear5/bear4.png"),
	Material("bear5/bear5.png"),
	Material("bear5/bear6.png"),
	Material("bear5/bear7.png"),
}

local bearalpha = 255
local randomImage
local function bearbell()
	if randomImage:IsError() then return end
	
    surface.SetDrawColor(255, 255, 255, bearalpha)
    surface.SetMaterial(randomImage)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	
	bearalpha = bearalpha - (100 * FrameTime())
end

net.Receive("bear5_bell", function()
	randomImage = bearimages[math.random(1,5)]
	bearalpha = 180
	hook.Add("HUDPaint", "bear5_bell", bearbell)
	
	surface.PlaySound("bear/bear_hallucinations.wav")
	
	local repeattimes = math.random(1,2)
	
	for i = 1, repeattimes do
		timer.Simple(i * 1.2, function()
			randomImage = bearimages[math.random(1,7)]
			bearalpha = 180
			hook.Add("HUDPaint", "bear5_bell", bearbell)
	
			surface.PlaySound("bear/bear_hallucinations.wav")
		end)
	end
end)

-- Дистанция, на которой видно эффект
local AURA_MIN_DISTANCE, AURA_MAX_DISTANCE = 40, 2000

-- Общее число "пикселей" по всей модели
local GLITCH_BLACK_COUNT, GLITCH_WHITE_COUNT = 150, 5

-- Насколько "за" костью по лучу от камеры "пиксели" уводит
local BONE_BACK_OFFSET_MIN, BONE_BACK_OFFSET_MAX = 3.0, 9.0

-- Базовый разброс вокруг кости (в плоскости экрана) для "пикселей"
local BONE_JITTER_RADIUS_NEAR, BONE_JITTER_RADIUS_FAR = 1.0, 3.0

-- Усиление вертикального разброса (по оси вверх экрана)
local VERTICAL_JITTER_MULT = 1.7

-- Размеры обычных квадратиков
local SQUARE_SIZE_MIN, SQUARE_SIZE_MAX  = 2.0, 5.0

local BLACK_SQUARE_ALPHA = 255
local WHITE_SQUARE_ALPHA = 255

-- Скорость смены
local NOISE_FPS_MIN, NOISE_FPS_MAX = 4, 8

-- Сколько "пикселей" держать один FPS, перед сменой (рандомно)
-- Фактически используется для расчёта времени в секундах: holdFrames / fps
local NOISE_HOLD_MIN_FRAMES, NOISE_HOLD_MAX_FRAMES = 6, 18

-- "Залипающие пиксели" (оставшиеся в мире и не двигающиеся с костями)
local DETACHED_SQUARE_MIN_LIFETIME, DETACHED_SQUARE_MAX_LIFETIME = 1.0, 5.0
local DETACHED_SQUARE_CHANCE       = 0.03  -- шанс на одного кандидата-"пиксель"
local DETACHED_SQUARE_MAX_COUNT    = 45    -- максимум залипших "пикселей" на одного Bear5

local GLITCH_MATERIAL = GLITCH_MATERIAL or CreateMaterial(
    "fh_bear5_glitch_square_material",
    "UnlitGeneric",
    {
        ["$basetexture"] = "color/white",
        ["$ignorez"]     = "0", -- <- эта мразь решила однажды сквозь карту херачить, я хз как и почему
        ["$vertexalpha"] = "1",
        ["$vertexcolor"] = "1"
    }
)

local bears = {}

-- [entIndex] = { fps = number, nextFpsChangeTime = number }
local auraNoiseState = {}

-- [entIndex] = {
--   { pos = Vector, size = number, colorR, colorG, colorB, alpha, dieTime = number },
--   ...
--   lastSeen = CurTime()
-- }

local function IsPillBear5(ent)
    if not IsValid(ent) then return false end

    if ent:GetPillName() == "bear5_main" then
        return true
    end

    return false
end

local function GetBear5(ply)
    if not IsValid(ply) then return nil end

    local mapped = pills.getMappedEnt(ply)
    if not IsValid(mapped) then return nil end
    if not IsPillBear5(mapped) then return nil end

    return mapped
end

local function ShouldSkipAuraOnPlayer(ply)
    local lp = LocalPlayer()
    if not IsValid(lp) then return false end

    if ply == lp:GetObserverTarget()
        and lp:GetViewEntity() == lp
        and lp:GetObserverMode() == OBS_MODE_IN_EYE then
        return true
    end

    return false
end

local function GetNoiseFrameForEnt(pillEnt)
    local state    = auraNoiseState[pillEnt]
    local now      = CurTime()

    -- Инициализация
    if not state then
        local fps        = math.random(NOISE_FPS_MIN, NOISE_FPS_MAX)
        local holdFrames = math.random(NOISE_HOLD_MIN_FRAMES, NOISE_HOLD_MAX_FRAMES)

        state = {
            fps = fps,
            nextFpsChangeTime = now + (holdFrames / fps)
        }

        auraNoiseState[pillEnt] = state
    else
        -- Пора сменить FPS?
        if now >= state.nextFpsChangeTime then
            local fps        = math.random(NOISE_FPS_MIN, NOISE_FPS_MAX)
            local holdFrames = math.random(NOISE_HOLD_MIN_FRAMES, NOISE_HOLD_MAX_FRAMES)

            state.fps = fps
            state.nextFpsChangeTime = now + (holdFrames / fps)
        end
    end

    -- Текущий кадр
    return math.floor(now * state.fps)
end

local function DrawAura(pillEnt) -- <- на всякий проверь ещё, тут нейронка насрала + я насрал, мб что-нибудь не так и я это тупо не увидел
	if not IsValid(pillEnt) then return end
	if pillEnt:IsInvisible() then return end
	
	local eyePos    = EyePos()
	local eyeAngles = EyeAngles()
	if not eyePos or not eyeAngles then return end
	
	local pillCenter     = pillEnt:LocalToWorld(pillEnt:OBBCenter())
	local vectorToCenter = pillCenter - eyePos
	local distanceToPill = vectorToCenter:Length()
	
	if distanceToPill < AURA_MIN_DISTANCE or distanceToPill > AURA_MAX_DISTANCE then
		return
	end
	
	local distanceFraction = math.Clamp(
		(distanceToPill - AURA_MIN_DISTANCE) / (AURA_MAX_DISTANCE - AURA_MIN_DISTANCE),
		0, 1
	)
	
	-- Направление взгляда камеры
	local viewForward = eyeAngles:Forward()
	
	-- Базис для мелких "пикселей" (в плоскости экрана)
	local worldUp = Vector(0, 0, 1)
	if math.abs(viewForward:Dot(worldUp)) > 0.95 then
		worldUp = Vector(0, 1, 0)
	end
	
	local screenRight = viewForward:Cross(worldUp)
	screenRight:Normalize()
	
	local screenUp = screenRight:Cross(viewForward)
	screenUp:Normalize()
	
	local boneCount = pillEnt:GetBoneCount() or 0
	if boneCount <= 0 then return end
	
	local radius = pillEnt:BoundingRadius()
	if radius <= 0 then radius = 40 end
	
	-- Кадр с учётом рандомного FPS + "перерывов" между сменами FPS
	local noiseFrame = GetNoiseFrameForEnt(pillEnt)
	
	-- "Кадр" шума -> эффект статики
	local baseRandomSeed = pillEnt:EntIndex() * 7919 + noiseFrame * 104729 -- <- не думаю, что это нормально, но ИИ предложило так, как бы, да
	
	local entIndex = pillEnt:EntIndex()
	local now      = CurTime()
	
	render.SetMaterial(GLITCH_MATERIAL)
	
	-- Пачка пикселей по костям (белые и чёрные)
	local function DrawSquareSet(squareCount, colorR, colorG, colorB, alpha, seedOffset, keySuffix)
		if squareCount <= 0 then return end
	
		for i = 1, squareCount do
			local squareSeed = baseRandomSeed + seedOffset + i * 37
	
			-- 1) Случайная кость
			local boneIndexFloat = util.SharedRandom(
				"fh_bear5_glitch_bone_" .. keySuffix,
				0, boneCount - 0.0001,
				squareSeed
			)
			local boneIndex = math.floor(boneIndexFloat)
			if boneIndex < 0 or boneIndex >= boneCount then
				continue
			end
	
			local bonePos = select(1, pillEnt:GetBonePosition(boneIndex))
			if not bonePos then
				continue
			end
	
			local parentIndex = pillEnt:GetBoneParent(boneIndex)
			local parentPos
			if parentIndex and parentIndex >= 0 then
				parentPos = select(1, pillEnt:GetBonePosition(parentIndex))
			end
	
			local segmentStart = parentPos or bonePos
			local segmentEnd   = bonePos
	
			local segmentDir = segmentEnd - segmentStart
			local segmentLen = segmentDir:Length()
			if segmentLen < 1 then
				segmentDir = viewForward
				segmentLen = 8
			else
				segmentDir:Mul(1 / segmentLen)
			end
	
			-- 2) Позиция вдоль кости
			local alongFraction = util.SharedRandom(
				"fh_bear5_glitch_along_" .. keySuffix,
				0, 1,
				squareSeed + 1
			)
			local pointOnBone = segmentStart + segmentDir * (segmentLen * alongFraction)
	
			-- 3) Смещение ЗА кость по рэю от камеры
			local backOffset = util.SharedRandom(
				"fh_bear5_glitch_back_" .. keySuffix,
				BONE_BACK_OFFSET_MIN,
				BONE_BACK_OFFSET_MAX,
				squareSeed + 2
			)
			local worldPos = pointOnBone + viewForward * backOffset
	
			-- 4) Разброс в плоскости экрана + усиление по высоте (для головы и ног, иначе всё возле пуза)
			local baseJitterRadius = Lerp(
				distanceFraction,
				BONE_JITTER_RADIUS_NEAR,
				BONE_JITTER_RADIUS_FAR
			)
	
			local heightOffset   = pointOnBone.z - pillCenter.z
			local heightFraction = math.Clamp(math.abs(heightOffset) / (radius * 0.7), 0, 1) -- <- оооооо пиздец бляяяяяяять
	
			local jitterRadius = baseJitterRadius + radius * 0.25 * heightFraction
	
			local jitterAngle = util.SharedRandom(
				"fh_bear5_glitch_angle_" .. keySuffix,
				0, math.pi * 2,
				squareSeed + 3
			)
			local jitterLen = util.SharedRandom(
				"fh_bear5_glitch_radius_" .. keySuffix,
				jitterRadius * 0.3,
				jitterRadius,
				squareSeed + 4
			)
	
			local offsetRight = math.cos(jitterAngle) * jitterLen
			local offsetUp    = math.sin(jitterAngle) * jitterLen * VERTICAL_JITTER_MULT
	
			worldPos = worldPos
				+ screenRight * offsetRight
				+ screenUp    * offsetUp
	
			-- 5) Размер "пикселя"
			local size = util.SharedRandom(
				"fh_bear5_glitch_size_" .. keySuffix,
				SQUARE_SIZE_MIN,
				SQUARE_SIZE_MAX,
				squareSeed + 5
			)
			if size <= 0.5 then
				continue
			end
	
			-- 6) Нормаль к камере
			local normal = eyePos - worldPos
			if normal:LengthSqr() < 1 then
				continue
			end
			normal:Normalize()
	
			-- Рисуем обычный (привязанный) "пиксель"
			render.DrawQuadEasy(
				worldPos,
				normal,
				size,
				size,
				Color(colorR, colorG, colorB, alpha),
				0
			)
		end
	end
	
	DrawSquareSet(
		GLITCH_BLACK_COUNT,
		0, 0, 0,
		BLACK_SQUARE_ALPHA,
		0,
		"black"
	)
	
	DrawSquareSet(
		GLITCH_WHITE_COUNT,
		255, 255, 255,
		WHITE_SQUARE_ALPHA,
		9999,
		"white"
	)
end

-- Это для зеркал и т.д.

hook.Add("PostDrawTranslucentRenderables", "FH_Bear5_GlitchAura_Draw", function(isDepthPass, isSkybox)
	if isSkybox or isDepthPass then return end
	
	local viewer = LocalPlayer()
	if not IsValid(viewer) then return end
	
	for ply, _ in pairs(bears) do
		if not IsValid(ply) or not ply:Alive() then
			continue
		end
	
		local pillEnt = GetBear5(ply)
		if not IsValid(pillEnt) then
			continue
		end
	
		if ShouldSkipAuraOnPlayer(ply) then
			continue
		end
	
		if pillEnt.IsDrawn == false
			or pillEnt:GetNoDraw()
			or (isstring(pillEnt:GetMaterial()) and string.lower(pillEnt:GetMaterial()) == "models/null") then
			continue
		end
	
		DrawAura(pillEnt)
	end
end)

hook.Add("PrePlayerDraw", "FH_Bear5_GlitchAura_Mirrors", function(ply)
    local lp = LocalPlayer()
    if ply ~= lp then return end

    local pillEnt = GetBear5(ply)
    if not IsValid(pillEnt) then return end

    if pillEnt.IsDrawn
        or pillEnt:GetNoDraw()
        or (isstring(pillEnt:GetMaterial()) and string.lower(pillEnt:GetMaterial()) == "models/null") then
        return
    end

    if ShouldSkipAuraOnPlayer(ply) then return end

    DrawAura(pillEnt)
end)

-- ЭМБИЕНС
local bear5Ambience = {}

local function StopAmbience(ent, fadeOut)
    local snd = bear5Ambience[ent]
	
    if snd then
        if fadeOut then
            snd:FadeOut(0.5)
        else
            snd:Stop()
        end
    end

    bear5Ambience[ent] = nil
end

local GLOBAL_VOLUME = 0.45
local LOCAL_BEAR_VOLUME_FACTOR = 0.15
local SOUND_LEVEL_DB = 70
local function StartAmbienceForPill(ent, ownerPly)
    if bear5Ambience[ent] then return end

    local snd = CreateSound(ent, ")bear/bear_aura_ambience.wav")
    if not snd then return end

    snd:SetSoundLevel(SOUND_LEVEL_DB)

    local volume = GLOBAL_VOLUME
    local lp = LocalPlayer()

    if IsValid(lp) and ownerPly == lp then
        volume = volume * LOCAL_BEAR_VOLUME_FACTOR
    end

    if volume < 0 then volume = 0 end
    if volume > 1 then volume = 1 end

    snd:PlayEx(volume, 100)

    bear5Ambience[ent] = snd
end

hook.Add("PillApply", "bear5_ambience_apply", function(ply, ent)
    if IsValid(ply) and ent:GetPillName() == "bear5_main" then
		bears[ply] = true
        StartAmbienceForPill(ent, ply)
    end
end)

hook.Add("PillRestore", "bear5_ambience_restore", function(ply, ent)
    if IsValid(ply) and ent:GetPillName() == "bear5_main" then
		bears[ply] = nil
		StopAmbience(ent)
		if auraNoiseState[pillEnt] then
			auraNoiseState[pillEnt] = nil
		end
    end
end)