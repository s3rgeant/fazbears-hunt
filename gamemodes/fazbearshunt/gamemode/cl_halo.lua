-- звук для аниматронов
local visionSuccessSound = "vision_success.wav"
local visionUnsuccessSound = "vision_unsuccess.wav"

local affectedPlayers = {}
local affectedPlayers_force = {}
animatronics = {}
local teammates = {}

include("halo_module.lua")

local function ClearReusableEntryList(entryList)
	for entryIndex = #entryList, 1, -1 do
		entryList[entryIndex] = nil
	end
end

local function AcquireReusableEntry( entryPool, entryIndex)
	local entry = entryPool[entryIndex]

	if not entry then
		entry = {}
		entryPool[entryIndex] = entry
	end

	return entry
end

hook.Add("PillApply", "fh_joinpill", function(ply, ent)
	timer.Simple(1, function()
		if IsValid(ent) then
			pilluser = ent:GetPillUser()
			
			if IsValid(pilluser) then
				animatronics[pilluser] = true
			end
		end
	end)
end)

hook.Add("OnReloaded", "reloaded_clhalo", function()
	for _, ent in ents.Iterator() do
		if ent:GetClass() == "pill_costume" then
			pilluser = ent:GetPillUser()
			
			if IsValid(pilluser) then
				animatronics[pilluser] = true
			end
		end
	end
end)

hook.Add("OnEntityCreated", "fh_plushtrap_halo", function(ent)
	if ent:GetClass() == "plushtrap" then
		if IsValid(ent) then
			animatronics[ent] = true
		end
	end
end)

hook.Add("EntityRemoved", "fh_plushtrap_hao", function(ent)
	if ent:GetClass() == "plushtrap" then
		animatronics[ent] = nil
	end
end)

hook.Add("PillRestore", "fh_restorepill", function(ply, ent)
	animatronics[ply] = nil
end)

hook.Add( "NotifyShouldTransmit", "fh_animatronic_transmit", function( entity, started )
	if started and entity:IsPlayer() then
		local ply = entity
		if !animatronics[ply] and IsValid(ply:GetPill()) then
			animatronics[ply] = true
		end
	end
end)

local myself

local fh_halo_teammates = CreateClientConVar('fh_halo_teammates', 1, true, false, 'Highlight Teammates? (Animatronics Only) Turn Off for Performance.', 0, 1)

net.Receive("NotifySpectators", function()
	local players = net.ReadTable()
	local ply = net.ReadEntity()
	local player = IsValid(ply) and ply:Nick() or "UNKNOWN USER"
	
	chat:AddText(Color( 255, 0, 0 ), player, Color( 180, 20, 20 ), ' ', language.GetPhrase("fuppr.highlight_specs"), ': ', Color( 170, 55, 50 ), table.concat(players, ", "))
end)

function addAffected(ply, duration, color, force)
	local duration = duration or conVars.halo_time:GetFloat()
	
	if !affectedPlayers[ply] or force then
		affectedPlayers[ply] = color or Color(255,0,0)
	end
	
	if force then
		affectedPlayers_force[ply] = true
	end
end

function removeAffected(ply, force)
	if affectedPlayers[ply] and !affectedPlayers_force[ply] or force then
		affectedPlayers[ply] = nil
		affectedPlayers_force[ply] = nil
	end
end

net.Receive("AddAffectedPlayers", function()
	local numTargets = net.ReadUInt(8)
	local players = {}
	for i = 1, numTargets do
		local target = net.ReadEntity()
		if IsValid(target) then
			table.insert(players, target)
		end
	end
	
	duration = net.ReadFloat()
	color = net.ReadColor()
	
	if duration <= 0 then duration = nil end
	
	for _, target in ipairs(players) do
		addAffected(target, duration, color)
	end
end)

net.Receive("RemoveAffectedPlayer", function()
    targetPlayer = net.ReadEntity()
	removeAffected(targetPlayer)
end)

net.Receive("fh_hl_badkid", function()
	local player = net.ReadEntity()
	local lp = LocalPlayer()
	if lp ~= player and lp:Team() == 2701 then
		surface.PlaySound("vision_unbox_success.wav")
	end
	
	if lp == player then
		drawHighlightTimer(true)
		surface.PlaySound("vision_affected.wav")
	end
end)

net.Receive("PlayHighlightSounds", function()
    local isAffected = net.ReadBool()
	local sound = net.ReadString()
	
	surface.PlaySound(sound)
    if isAffected then
		drawHighlightTimer(true)
    end
end)

net.Receive("fh_draw_hl_overlay", function()
    local bool = net.ReadBool()
    drawHighlightTimer(bool)
end)

net.Receive("fh_draw_hl_overlay_timed", function()
    local bool = net.ReadBool()
    local dur = net.ReadFloat()
    drawHighlightTimer(bool, dur)
end)

net.Receive("fh_nodraw_hl_overlay", function()
	hook.Remove("HUDPaint", "fh_hl_overlay_draw")
end)
	
function drawHighlightTimer(bool, duration)
	duration = duration or conVars.halo_time:GetFloat()
	hook.Add("HUDPaint", "fh_hl_overlay_draw", drawHighlight)
	
	if timer.Exists('fh_hud_hl_overlay') then
		timer.Remove('fh_hud_hl_overlay')
	end
	
	if !bool then return end
	timer.Create( "fh_hud_hl_overlay", duration, 1, function()
		hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	end)
end

local highlight_mat = Material("vgui/highlight2.vtf")
function drawHighlight()
	if !GetConVar("cl_drawhud"):GetBool() then return end
	
	if highlight_mat:IsError() then return end
	
	-- 80 0 255 ШФ
    surface.SetDrawColor(255, 255, 255, 225)
    surface.SetMaterial(highlight_mat)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

local scale = ScrH() / 1080
local size = 128 * scale

local plushalert_y = -size
local plushalert_y_target = 0

local plushalert_alpha = 0
local plushalert_alpha_target = 20

net.Receive("fh_plushalert_inrange", function()
	hook.Add("HUDPaint", "fh_plushalert_draw", plushtrap_alert)
	plushalert_y_target = 10
	plushalert_alpha_target = 10
end)

net.Receive("fh_plushalert_outrange", function()
	plushalert_y_target = -size
	plushalert_alpha_target = 0
	hook.Add("Think", "fh_plushalert_removing", function()
		if math.floor(plushalert_y) == math.floor(plushalert_y_target) then
			hook.Remove("HUDPaint", "fh_plushalert_draw")
			hook.Remove("HUDPaint", "fh_plushalert_removing")
		end
	end)
end)

local plushtrap_overlay_mat = Material("vgui/plushtrap overlay.png")
local plushtrap_alert_mat = Material("vgui/plushtrap_alert.vtf")

function plushtrap_alert()
	if plushtrap_overlay_mat:IsError() then return end
	
    local speed = FrameTime() * 2
    plushalert_y = Lerp(speed, plushalert_y, plushalert_y_target)
    plushalert_alpha = Lerp(speed, plushalert_alpha, plushalert_alpha_target)
	
	if !GetConVar("cl_drawhud"):GetBool() then return end
	
    surface.SetDrawColor(255, 255, 255, plushalert_alpha)
    surface.SetMaterial(plushtrap_overlay_mat)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(plushtrap_alert_mat)
    surface.DrawTexturedRect(ScrW() / 2 - size / 2, (ScrH() - size) - plushalert_y, size, size)
end

net.Receive("ToggleHighlightSound", function()
    local success = net.ReadBool()
    if success then
		surface.PlaySound(visionSuccessSound)
    else
		surface.PlaySound(visionUnsuccessSound)
    end
end)

local SPECTATOR_COLOR = Color(155, 0, 255, 255)

local spectatorHighlightEntries = {}
local spectatorHighlightEntryPool = {}

local function collectSpects(lply)
	ClearReusableEntryList(spectatorHighlightEntries)
	
	if not IsValid(lply) then
		return nil
	end
	
	local observerMode = lply:GetObserverMode()
	
	if lply:Alive() or observerMode == OBS_MODE_NONE then
		return nil
	end
	
	local entryCount = 0
	
	for _, targetPlayer in player.Iterator() do
		if not targetPlayer:Alive() then continue end
	
		if lply:GetObserverTarget() == targetPlayer and observerMode == OBS_MODE_IN_EYE then continue end
	
		local pill = targetPlayer:GetPillCostume()
		local targetColor = SPECTATOR_COLOR
	
		if not IsValid(pill) then
			if not targetPlayer:IsInvisible() then continue end
		else
			if not pill:IsInvisible() then 
				continue 
			end
			targetColor = killers.GetColor(pill:Get("name"))
	
			targetPlayer = pill
		end
	
		entryCount = entryCount + 1
	
		local highlightEntry = AcquireReusableEntry(spectatorHighlightEntryPool, entryCount)
	
		highlightEntry.ent = targetPlayer
		highlightEntry.outline_color = targetColor
		highlightEntry.fill_color = targetColor
	
		spectatorHighlightEntries[ entryCount ] = highlightEntry
	end
	
	if entryCount == 0 then return nil end
	
	return spectatorHighlightEntries
end

OUTLINE.RegisterRule("spectators", {
	priority = 10,
	render_max_dist = 3000,
	
	outline_color = SPECTATOR_COLOR,
	outline_width = 3,
	outline_min_dist = 1000,
	outline_max_dist = 2200,
	
	fill_color = SPECTATOR_COLOR,
	fill_min_dist = 1500,
	fill_max_dist = 2600,
	
	mode = OUTLINE_MODE_VISIBLE,
	
	quality = {
		auto = {
			builtin = true,
			low_render_max_dist = 2400
		},
	
		low = {
			builtin = true,
			render_max_dist = 2000
		}
	},
	
	collect = collectSpects
})

local ORB_FADE_DISTANCE = 200

local AFFECTED_ORB_START_DISTANCE = 1650
local AFFECTED_ORB_FULL_DISTANCE = AFFECTED_ORB_START_DISTANCE + ORB_FADE_DISTANCE

local AFFECTED_ORB_FULL_DISTANCE_SQR = AFFECTED_ORB_FULL_DISTANCE * AFFECTED_ORB_FULL_DISTANCE

local affectedHighlightEntries = {}
local affectedHighlightEntryPool = {}

local function affectedDistanceCut(highlightEntry, qualityContext)
	local localPlayer = qualityContext.local_player
	local highlightedEntity = highlightEntry.ent
	
	if not IsValid(localPlayer) or not IsValid(highlightedEntity) then
		return false
	end
	
	local distanceSquared = localPlayer:GetPos():DistToSqr(highlightedEntity:GetPos())
	
	if distanceSquared >= AFFECTED_ORB_FULL_DISTANCE_SQR then
		return false
	end
end

local function getAffected(localPlayer, rule)
	if not istable(affectedPlayers) then return nil end
	
	ClearReusableEntryList(affectedHighlightEntries)
	
	local entryCount = 0
	
	for target, highlightColor in pairs(affectedPlayers) do
		if not IsValid(target) then continue end
		local isPlayer = target:IsPlayer()
		--if not isPlayer then continue end
		if target == localPlayer then continue end
		
		if isPlayer and not target:Alive() then continue end
		if isPlayer and target:Team() == TEAM_SPECTATOR then continue end
		if isPlayer and target:Health() <= 0 then continue end
	
		if isPlayer and target:IsSurvivor() and target:IsInvisible() then continue end
	
		if not target:GetPos():ToScreen().visible then continue end
		
		if hook.Run("ShouldCollectAffected", target, localPlayer) == false then continue end
	
		entryCount = entryCount + 1
	
		local highlightEntry = AcquireReusableEntry(
			affectedHighlightEntryPool,
			entryCount
		)
	
		local resolvedColor = highlightColor or color_white
		
		local pill = isPlayer and target:GetActualPillCostume()
		
		if IsValid(pill) then
			highlightEntry.ent = pill
		else
			highlightEntry.ent = target
		end
		highlightEntry.outline_color = resolvedColor
		highlightEntry.fill_color = resolvedColor
	
		affectedHighlightEntries[entryCount] = highlightEntry
	end
	
	if entryCount == 0 then
		return nil
	end
	
	return affectedHighlightEntries
end

OUTLINE.RegisterRule("affected_players", {
    priority = 100,
    render_max_dist = 9000,

    outline_color = Color(255, 0, 0, 255),
    outline_width = 3,
    outline_min_dist = 800,
    outline_max_dist = 2000,

    fill_color = Color(255, 0, 0, 255),
    fill_min_dist = 1000,
    fill_max_dist = 1800,

    mode = OUTLINE_MODE_BOTH,

    quality = {
        auto = true,
        low = true,

        always_apply = affectedDistanceCut
    },

    collect = getAffected
})

local CUPCAKE_COLOR   = Color(255, 155, 0, 255)
local cupcakeHighlightEntries = {}
local cupcakeHighlightEntryPool = {}

local function getCupcakes(lp)
	local ent = pills.getMappedEnt(lp)
	
	if not IsValid(ent) or not ent.formTable then return nil end
	
	ClearReusableEntryList( cupcakeHighlightEntries )
	
	local entryCount = 0
	
	for _, cupcake in ipairs( ents.FindByClass("cakemine") ) do
		if cupcake:GetOwner() ~= lp then continue end
		if not cupcake:GetPos():ToScreen().visible then continue end
	
		entryCount = entryCount + 1
	
		local highlightEntry =
			AcquireReusableEntry(
				cupcakeHighlightEntryPool,
				entryCount
			)
	
		highlightEntry.ent = cupcake
		highlightEntry.outline_color = CUPCAKE_COLOR
		highlightEntry.fill_color = CUPCAKE_COLOR
	
		cupcakeHighlightEntries[entryCount] = highlightEntry
	end
	
	if entryCount == 0 then
		return nil
	end
	
	return cupcakeHighlightEntries
end

OUTLINE.RegisterRule("cupcakes", {
    priority = 20,
    render_max_dist = 9000,

    outline_color = CUPCAKE_COLOR,
    outline_width = 4,
    outline_min_dist = 500,
    outline_max_dist = 2000,

    fill_color = CUPCAKE_COLOR,
    fill_min_dist = 400,
    fill_max_dist = 2000,

    mode = OUTLINE_MODE_BOTH,

    quality = {
        auto = {
            builtin = true,
            low_render_max_dist = 6000
        },

        low = {
            builtin = true,
            render_max_dist = 3500
        }
    },

    collect = getCupcakes
})

net.Receive("fh_hl_animatronics", function()
	surface.PlaySound("human_gift_vision.wav")
end)

local TEAMMATE_COLOR = Color(0, 255, 0, 255)

local function getPillPlayerColor(localPlayer, target, storedColor)
    if IsColor(storedColor) then
        return storedColor
    end

    if not localPlayer:IsAnimatronic() and target.GetPillName then
        local pillName = target:GetPillName()

        if pillName then
            local killerColor = killers.GetColor(pillName)

            if IsColor(killerColor) then
                return killerColor
            end
        end
    end

    return TEAMMATE_COLOR
end

local function canDrawTeammatesHalos(myself)
    if not fh_halo_teammates:GetBool() and myself:Team() == TEAM_PILLS then return false end

    if myself:Team() ~= TEAM_PILLS then return false end

    if table.IsEmpty(animatronics) then return false end

    return true
end

local function getBetterPill(myself, pill)
	if not IsValid(pill) then return NULL end
	
	if not pill:IsPlayer() then return pill end
	
	if pill:Team() ~= TEAM_PILLS then return NULL end
	
	if pill == myself then return NULL end
	
	return pill:GetPill()
end

local TeammateHighlightCache = {
    frameNumber = -1,
    localPlayer = NULL,

    regularEntries = {},
    regularEntryPool = {},
}

local function rebuildTeammateHaloCache( localPlayer )
    local cache = TeammateHighlightCache

    cache.frameNumber = FrameNumber()
    cache.localPlayer = localPlayer

    ClearReusableEntryList(cache.regularEntries)

    if not canDrawTeammatesHalos( localPlayer ) then return end

    local regularEntryCount = 0

    for animatronicReference, storedColor in pairs(animatronics) do
        local target = getBetterPill(localPlayer,animatronicReference)

        if not IsValid(target) then continue end
        if target:IsDormant() then continue end
		
		if not target:IsInvisible() then
			local owner = target.GetPillUser and target:GetPillUser() or nil
			local ownerValid = owner and owner:IsValid()
			local isPlayer = ownerValid and owner:IsPlayer() or false
			
			local filtr = {localPlayer}
			if owner then filtr[#filtr+1] = owner end
			
			local targetPos = (target:GetPos() + target:OBBCenter())
			if ownerValid then targetPos = isPlayer and owner:EyePos() or (owner:GetPos() + owner:OBBCenter()) end
			
			local tr = util.TraceLine({
				start = localPlayer:GetShootPos(),
				endpos = targetPos,
				filter = filtr
			})
			
			if not tr.Hit then continue end
		end

        local teammateColor = getPillPlayerColor( localPlayer,target,storedColor)
        
		regularEntryCount = regularEntryCount + 1

		local highlightEntry = AcquireReusableEntry(cache.regularEntryPool, regularEntryCount)

        if target:IsInvisible() then
			highlightEntry.outline_visible = true
			highlightEntry.outline_visible_width = 2
		else
			highlightEntry.outline_visible = false
			highlightEntry.outline_visible_width = 0
		end

		highlightEntry.ent = target
		highlightEntry.outline_color = teammateColor
		highlightEntry.fill_color = teammateColor

		cache.regularEntries[regularEntryCount] = highlightEntry
    end
end

local function getTeammateHaloCache(localPlayer)
    local cache = TeammateHighlightCache
    local currentFrameNumber = FrameNumber()

    if cache.frameNumber == currentFrameNumber and cache.localPlayer == localPlayer then return end

    rebuildTeammateHaloCache(localPlayer)
end

local function GetTeammatesForHighlight(localPlayer)
	getTeammateHaloCache(localPlayer)

	local highlightEntries = TeammateHighlightCache.regularEntries

	if #highlightEntries == 0 then return nil end

	return highlightEntries
end

OUTLINE.RegisterRule("animatronics", {
    priority = 30,
    render_max_dist = 9000,

    outline_color = TEAMMATE_COLOR,
    outline_visible = false,
    outline_occluded = true,
    outline_occluded_width = 2,
    outline_occluded_min_dist = 0,
    outline_occluded_max_dist = 1600,
    outline_visible_min_dist = 0,
    outline_visible_max_dist = 1600,

    fill_color = TEAMMATE_COLOR,
    fill_visible = true,
    fill_occluded = true,
    fill_visible_min_dist = 1000,
    fill_visible_max_dist = 2000,
    fill_occluded_min_dist = 1000,
    fill_occluded_max_dist = 2000,

    quality = {
        auto = true,
        low = true
    },

    collect = GetTeammatesForHighlight
})

hook.Add("HUDPaint", "fh_draw_affected", function()
	local affectedPlayersReal = {}
	
	for v, color in pairs(affectedPlayers) do
		if v ~= LocalPlayer() and v:IsValid() then
			local isPlayer = v:IsPlayer()
			if isPlayer and v:Health() < 0 then continue end
			if isPlayer and v:IsSurvivor() and v:IsInvisible() then continue end
			affectedPlayersReal[v] = color
		end
	end
	draw_orbs(
		affectedPlayersReal,
		nil,
		AFFECTED_ORB_START_DISTANCE
	)
	
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
	
    local haloTeammates = GetConVar("fh_halo_teammates")
    if haloTeammates and not haloTeammates:GetBool() and ply:IsAnimatronic() then return end
	
	if table.IsEmpty(animatronics) then return end
	
	local anims = {}
	for anim, color in pairs(animatronics) do
		if IsValid(anim) and anim:IsPlayer() and anim:Team() ~= TEAM_PILLS then continue end
		anims[anim] = IsColor(color) and color or true
	end
	
    if ply:Team() == TEAM_PILLS then
		draw_pill_avatars(anims, nil, GetGlobal2Float("FarZ", 8000))
	end
end)

hook.Add("HUDPaint", "fh_cupcake_count_draw", function()
	myself = myself or LocalPlayer()

	local ent = pills.getMappedEnt(myself)
	if not IsValid(ent) then return end
    local cakemines = ents.FindByClass("cakemine")

    for i, ent in ipairs(cakemines) do
        if not IsValid(ent) then continue end
		if ent:GetOwner() ~= myself then continue end

        local pos = ent:GetPos():ToScreen()

        if pos.visible then
            draw.SimpleTextOutlined(
                i, 
                "DermaLarge", 
                pos.x, pos.y - 25, 
                Color(255, 155, 0, 255), 
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 
                1, Color(0, 0, 0, 255)
            )
        end
    end
end)

local target_orb = Material("vgui/target_orb_color.png", "noclamp smooth")

local function IsOverlapping(x, y, size)
    for _, ico in ipairs(drawnIcons) do
        if math.abs(ico.x - x) < size * 2 and math.abs(ico.y - y) < size * 2 then
            return true
        end
    end
    return false
end

local nicknameColor = Color(0,255,0,255)
function draw_orbs(tbl, material, distance)
    local material = material or target_orb

    local ply = LocalPlayer()
    if !IsValid(ply) or !ply:Alive() then return end
    
    local screenW, screenH = ScrW(), ScrH()
    local halfW, halfH = screenW / 2, screenH / 2
    local textureSize = 32
    
    local maxDistance = distance or 1650

    for target, color in pairs(tbl) do
        if IsValid(target) then
            if target:IsPlayer() and (!target:Alive() or target:Team() == TEAM_SPECTATOR) then continue end

            local min, max = target:GetCollisionBounds()
            local targetPos = target:GetPos() + Vector(0, 0, (min.z + max.z) / 2)
            local screenPos = targetPos:ToScreen()
            local dist = ply:GetPos():Distance(target:GetPos())
            
            if dist > maxDistance then
                local alpha = math.Clamp(
                    (dist - maxDistance)
                    / ORB_FADE_DISTANCE,
                    0,
                    1
                ) * 255
                
                local clampedX = math.Clamp(screenPos.x, textureSize, screenW - textureSize)
                local clampedY = math.Clamp(screenPos.y, textureSize, screenH - textureSize)
                
                local ourColor = IsColor(color) and color:Copy() or Color(255,0,0,255)
				
				local ent = target:IsPlayer() and target:GetPill() or NULL

				surface.SetDrawColor(ourColor.r, ourColor.g, ourColor.b, alpha)
				surface.SetMaterial(material)
				surface.DrawTexturedRect(clampedX - textureSize, clampedY - textureSize, 64, 64)
            end
        end
    end
end

local speaker = Material("voice/icntlk_pl.vtf")
local function RegisterIcon(x, y)
    drawnIcons[#drawnIcons + 1] = { x = x, y = y }
end

function draw_pill_avatars(tbl, material, distance)
    local material = material or target_orb

    local ply = LocalPlayer()
    if !IsValid(ply) or !ply:Alive() then return end
    
    local screenW, screenH = ScrW(), ScrH()
    local halfW, halfH = screenW / 2, screenH / 2
    local textureSize = 32
    
    local maxDistance = distance or 1650

    local overlap = {}
	drawnIcons = {}

    for target, color in pairs(tbl) do
        if IsValid(target) then
            if target:IsPlayer() and (!target:Alive() or target:Team() == TEAM_SPECTATOR) then continue end

            local min, max = target:GetCollisionBounds()
            local targetPos = target:GetPos() + Vector(0, 0, (min.z + max.z) / 2)
            local screenPos = targetPos:ToScreen()
            local dist = ply:GetPos():Distance(target:GetPos())
            
            if dist > maxDistance then
                local alpha = math.Clamp(
                    (dist - maxDistance)
                    / ORB_FADE_DISTANCE,
                    0,
                    1
                ) * 255
                
                local clampedX = math.Clamp(screenPos.x, textureSize, screenW - textureSize)
                local clampedY = math.Clamp(screenPos.y, textureSize, screenH - textureSize)
                
                local ourColor = IsColor(color) and color:Copy() or Color(255,0,0,255)
				
				local ent = target:IsPlayer() and target:GetPill() or NULL
				
                if IsValid(ent) and killers.GetFullName(ent:GetPillName()) and ply:IsAnimatronic() then
					local owner = ent:GetPillUser()
                    
					local textureSize = 16

					local drawX = clampedX
					local drawY = clampedY

					local step = textureSize * 2
					local maxSteps = 6
					local placed = false

					for i = 0, maxSteps do
						local offset = i * step

						local tryRight = drawX + offset
						if not IsOverlapping(tryRight, drawY, textureSize/1.5) then
							drawX = tryRight
							placed = true
							break
						end

						local tryLeft = drawX - offset
						if not IsOverlapping(tryLeft, drawY, textureSize/1.5) then
							drawX = tryLeft
							placed = true
							break
						end
					end
					
					if terror_radius.imChasing() then
						alpha = 60
						if drawX > (ScrW()/2) - 65 and drawX < (ScrW()/2) + 65 then continue end
					end

					RegisterIcon(drawX, drawY)
					
                    local nickname = nil
                    local name = killers.GetFullName(ent:GetPillName())
                    if IsValid(owner) and owner:IsPlayer() then
                        nickname = owner:Nick()
                    end

                    local pillMaterial = killers.GetAvatar(ent:GetPillName())
                    if pillMaterial then
                        ourColor = color_white
                    end
                    surface.SetDrawColor(ourColor.r, ourColor.g, ourColor.b, alpha)
                    surface.SetMaterial(pillMaterial or material)
                    surface.DrawTexturedRect(drawX - textureSize, drawY - textureSize, textureSize*2, textureSize*2)

					if IsValid(owner) and owner:VoiceVolume() > 0.1 then
						local volume = owner:VoiceVolume()
						local aa = volume * 255
						local size = textureSize*2 * (volume + 1) 
						surface.SetDrawColor(aa, aa, aa, 255)
						surface.SetMaterial(speaker)
						surface.DrawTexturedRect(drawX - size*0.5, drawY - size, size, size)
					end

                    if nickname then
                        draw.SimpleText(nickname, "CreditsText",
                            drawX, drawY + 32, nicknameColor,
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                        )
                    end

                    continue
                end
				
                if IsValid(ent) and killers.GetFullName(ent:GetPillName()) and ply:IsSurvivor() then
					ourColor = IsColor(color) and color or killers.GetColor(ent:GetPillName())
				end

				surface.SetDrawColor(ourColor.r, ourColor.g, ourColor.b, alpha)
				surface.SetMaterial(material)
				surface.DrawTexturedRect(clampedX - textureSize, clampedY - textureSize, 64, 64)
            end
        end
    end
end

hook.Add("PostCleanupMap", "fh_cleanup_halo", function(ply)
	table.Empty(affectedPlayers)
	
	hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	hook.Remove("HUDPaint", "fh_pt_draw_affected")
	
	hook.Remove("HUDPaint", "fh_plushalert_draw")
	hook.Remove("HUDPaint", "fh_plushalert_removing")
	
	hook.Remove("RenderScreenspaceEffects", "fh_springtrap_fx")
	
	if IsValid(selector) then
		selector:Close()
	end
end)

hook.Add("HandlePillThirdperson", "no_thirdperson_yoursmine", function(ply, ent)
	if ply._yoursmine_target then
		return false
	end
end)

net.Receive("fh_start_yoursmine_view", function()
	myself = myself or LocalPlayer()

    local target = net.ReadEntity()
    myself._yoursmine_target = target
    myself._yoursmine_start_time = CurTime()
    myself._yoursmine_initial_phase_duration = 5
    myself._yoursmine_rotation_duration = 0.7
    myself._yoursmine_total_dur = LocalPlayer()._yoursmine_initial_phase_duration + LocalPlayer()._yoursmine_rotation_duration
	
	myself:DrawViewModel( false, 0 )
	
	myself:SetFOV(0, 0)
	
    local ent = net.ReadEntity()
	
	animatronics[ent] = TEAMMATE_COLOR
	
    hook.Add("RenderScreenspaceEffects", "fh_yoursmine_fx", function()
        if not IsValid(myself._yoursmine_target) then return end

        local t = CurTime() - myself._yoursmine_start_time
        local frac = 1 - math.Clamp((t / myself._yoursmine_total_dur), 0, 1)

        DrawMotionBlur(0.1, 0.8 * frac, 0.01)
        DrawToyTown(2, ScrH()/2)
		DrawBloom( 0.65, 1 * frac, 9, 9, 1, 1, 1, 1, 1 )
    end)

	hook.Add("PrePlayerDraw", "fh_yoursmine_ply", function(ply)
		if not IsValid(myself._yoursmine_target) then return end
		if ply == myself._yoursmine_target then
			return true
		end
	end)
	
	myself:ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 180 ), 2, 0 )
end)

net.Receive("fh_stop_yoursmine_view", function()
	myself = myself or LocalPlayer()
    hook.Remove("RenderScreenspaceEffects", "fh_yoursmine_fx")
    hook.Remove("PrePlayerDraw", "fh_yoursmine_ply")
    myself._yoursmine_target = nil
    myself._yoursmine_start_time = nil
    myself._yoursmine_initial_phase_duration = nil
    myself._yoursmine_rotation_duration = nil
    myself._yoursmine_total_dur = nil
	
	myself:DrawViewModel( true, 0 )
	
    local ent = net.ReadEntity()
	animatronics[ent] = nil
	
	myself:ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 180 ), 2, 0 )
end)

local useEntityEntry = {}
local function collectUseEntity(lply)
	
	if not IsValid(lply) then return nil end
	if not lply:Alive() then return nil end
	
	local useEnt = lply:GetUseEntity()
	
	if not useEnt.OutlineOnUse then return nil end
	if useEnt.OutlineOnUse(useEnt, lply) == false then return nil end
	
	if IsValid(useEnt) then
		useEntityEntry[1] = useEnt
		return useEntityEntry
	end
	
	ClearReusableEntryList(useEntityEntry)
end

OUTLINE.RegisterRule("use_entity", {
	priority = 4,
	render_max_dist = 1000,
	
	outline_color = color_white,
	outline_width = 3,
	outline_min_dist = 500,
	outline_max_dist = 600,
	
	fill_color = color_white,
	fill_min_dist = 580,
	fill_max_dist = 610,
	
	mode = OUTLINE_MODE_VISIBLE,
	
	quality = {
		auto = {
			builtin = true,
		},
	
		low = {
			builtin = true,
		}
	},
	
	collect = collectUseEntity
})