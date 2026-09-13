local Angle = Angle
local math = math
local render = render
local surface = surface
local cam = cam

local matScreen = Material( "models/weapons/vondaram/tablet/ekran" )

if matScreen:IsError() then
    ErrorNoHalt("Tablet's screen texture not found!")
end

local RES = 1024

local RtTexture = GetRenderTargetEx("CA_TabletScreen",
    RES, RES,
    RT_SIZE_NO_CHANGE,
    MATERIAL_RT_DEPTH_SEPARATE,
    bit.bor(2, 256, 512),
    0,
    IMAGE_FORMAT_BGRA8888
)

local RtView = GetRenderTargetEx("CA_XRayView",
    RES, RES,
    RT_SIZE_NO_CHANGE,
    MATERIAL_RT_DEPTH_SEPARATE,
    bit.bor(2, 256, 512),
    0,
    IMAGE_FORMAT_BGRA8888
)

local function drawTablet(alpha)
    render.DrawTextureToScreen(RtView)
    
    if alpha < 255 then
        surface.SetDrawColor(0, 0, 0, 255 - alpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
end

local isRenderingScreen = false
local isCapturingXRay = false -- Флаг: рендерится ли сцена ИМЕННО для планшета прямо сейчас
local screenAlpha = 0
local fadeSpeed = 1500

function SWEP:RenderScreen()
    if isRenderingScreen then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    isRenderingScreen = true
    
    local targetAlpha = (self:GetIsFullView() and not self:GetIsHolstering()) and 255 or 0
    screenAlpha = math.Approach(screenAlpha, targetAlpha, RealFrameTime() * fadeSpeed)
    
    if screenAlpha > 0 then 
        render.PushRenderTarget(RtView)
            render.Clear(0, 0, 0, 255, true, true)
            
            local viewData = {
                origin = ply:EyePos(),
                angles = ply:EyeAngles(),
                x = 0,
                y = 0,
                w = RES,
                h = RES,
                fov = ply:GetFOV() * 0.4,
                drawhud = false,
                drawviewmodel = false,
            }
            
                render.RenderView(viewData)
            
        render.PopRenderTarget()
        
        render.PushRenderTarget(RtTexture)
            cam.Start2D()
                drawTablet(screenAlpha)
            cam.End2D()
        render.PopRenderTarget()
    else
        render.PushRenderTarget(RtTexture)
            render.Clear(0, 0, 0, 255, true, true)
        render.PopRenderTarget()
    end
    
    isRenderingScreen = false
    
    matScreen:SetTexture("$basetexture", RtTexture)
end

local worldDarkness = 150
local matDarknessOverlay = Material("vgui/black")
hook.Add("PostDrawOpaqueRenderables", "CA_Tablet_WorldDarkness_Fix", function(bDrawingDepth, bDrawingSkybox)
    if bDrawingDepth or bDrawingSkybox then return end 
    if screenAlpha <= 0 then return end 

    if render.GetRenderTarget() ~= nil then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end 
	
	if wep:GetClass() ~= "weapon_tablet" then return end

    local currentDarkness = (worldDarkness * (screenAlpha / 255))

    cam.Start2D()
        surface.SetMaterial(matDarknessOverlay)
        surface.SetDrawColor(0, 0, 0, currentDarkness)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    cam.End2D()
end)

local TEAMMATE_COLOR = Color(0, 255, 0)
local function ResolveTeammateColor(lp, ent, storedColor)
    if IsColor(storedColor) then
        return storedColor
    end

    if !lp:IsAnimatronic() and killers and killers.getColor and ent.GetPillName then
        local pillName = ent:GetPillName()
        if pillName then
            local killerColor = killers.getColor(pillName)
            if IsColor(killerColor) then
                return killerColor
            end
        end
    end

    return TEAMMATE_COLOR
end

local forcetmdistance = 1100
local function getTeammates(lp, rule)
    if not istable(animatronics) or table.IsEmpty(animatronics) then return nil end

    if render.GetRenderTarget() == nil then return nil end

    local out = {}
    local viewOrigin = lp:EyePos()
    local maxDist = tonumber(rule.render_max_dist) or math.huge
    local maxDistSqr = maxDist > 0 and (maxDist * maxDist) or math.huge

    for ent, storedColor in pairs(animatronics) do
        if !IsValid(ent) then continue end
        if ent:IsPlayer() then 
            if ent:Team() ~= TEAM_PILLS then continue end
            if ent == lp then continue end 
            ent = ent:GetPillCostume() 
        end
        if not IsValid(ent) then continue end
        if not ent.DrawModel then continue end
        
        local pos = ent:GetPos() + ent:OBBCenter()
        
        local distance = pos:DistToSqr(viewOrigin)
        if distance > maxDistSqr then
            continue
        end
        
        local tr = util.TraceLine( {
            start = viewOrigin,
            endpos = pos,
            filter = function(ent)
                return not ent:IsPlayer()
            end,
            mask = MASK_VISIBLE_AND_NPCS,
        } )
        
        if not ent:IsInvisible() and not tr.Hit and distance < forcetmdistance*forcetmdistance then continue end
        
        if not pos:ToScreen().visible then
            continue
        end

        local resolvedColor = ResolveTeammateColor(lp, ent, storedColor)
        
        local entry = OUTLINE.NormalizeEntry(rule, {
            ent = ent,
            outline_color = resolvedColor,
            fill_color = resolvedColor
        })

        if entry then
            out[#out + 1] = entry
        end
    end

    return (#out > 0) and out or nil
end

OUTLINE.RegisterRule("tablet_anims", {
    priority = 27,
    render_max_dist = 9000,

    outline_color = TEAMMATE_COLOR,
    outline_width = 2,
    outline_min_dist = 600,
    outline_max_dist = 1600,
    
    fill_color = TEAMMATE_COLOR,
    fill_min_dist = 1000,
    fill_max_dist = 1800,

    mode = OUTLINE_MODE_CHEAP,
    collect = getTeammates
})