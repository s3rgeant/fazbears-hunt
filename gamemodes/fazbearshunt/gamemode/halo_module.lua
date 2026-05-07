-- made by Zemen (heartcore mentioned)

OUTLINE = OUTLINE or {}
local H = {}

local MAT_FLAT = Material("models/debug/debugwhite")

local TEAMMATE_COLOR  = Color(0, 255, 0, 255)

H.State = H.State or {
}

H.Rules = H.Rules or {}

OUTLINE_MODE_BOTH = 0
OUTLINE_MODE_VISIBLE = 1

local function SmoothStep01(x)
    x = math.Clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

function H.NormalizeEntry(rule, raw)
    local ent = raw
    if istable(raw) then
        ent = raw.ent
    end

    if not IsValid(ent) then return nil end

    local outlineColor = nil
    local fillColor = nil
    local priority = nil
    local mode = nil
    local outlineWidth = nil

    if istable(raw) then
        outlineColor = raw.outline_color or raw.color
        fillColor = raw.fill_color or raw.color
        priority = raw.priority
        mode = raw.mode
        outlineWidth = raw.outline_width
    end

    outlineColor = outlineColor or rule.outline_color or color_white
    fillColor = fillColor or rule.fill_color or outlineColor
    priority = priority or rule.priority or 0
    mode = mode or rule.mode or OUTLINE_MODE_BOTH
    outlineWidth = tonumber(outlineWidth) or tonumber(rule.outline_width) or 0

    return {
        ent = ent,
        outline_color = outlineColor,
        fill_color = fillColor,
        priority = priority,
        mode = mode,
        outline_width = outlineWidth,
        rule = rule
    }
end

local function NormalizeEntry(rule, raw)
	return H.NormalizeEntry(rule, raw)
end

local function GetOutlineThicknessForDistance(entry, lp, ent)
    local rule = entry.rule
    local maxThickness = math.max(0, tonumber(entry.outline_width) or tonumber(rule.outline_width) or 0)
    if maxThickness <= 0 then return 0 end

    local minDist = math.max(0, tonumber(rule.outline_min_dist) or 0)
    local maxDist = math.max(0, tonumber(rule.outline_max_dist) or 0)
    local dist = ent:GetPos():Distance(lp:GetPos())

    local roundedMax = math.max(0, math.floor(maxThickness + 0.5))

    if dist <= minDist then
        return roundedMax
    end

    if maxDist <= minDist then
        return roundedMax
    end

    if dist >= maxDist then
        return 0
    end

    local frac = (dist - minDist) / (maxDist - minDist)
    local thickness = maxThickness * (1 - frac)

    return math.max(0, math.floor(thickness + 0.5))
end

local function GetFillAmountForDistance(rule, lp, ent)
    local minDist = math.max(0, tonumber(rule.fill_min_dist) or 0)
    local maxDist = math.max(0, tonumber(rule.fill_max_dist) or 0)
	
	local vEnt = lp:GetViewEntity()
	local eyePos = IsValid(vEnt) and (vEnt:IsPlayer() and vEnt:EyePos() or vEnt:GetPos()) or lp:EyePos()
	
    local dist = ent:GetPos():Distance(eyePos)

    if maxDist <= minDist then
        return 0
    end

    if dist <= minDist then
        return 0
    end

    if dist >= maxDist then
        return 1
    end

    local frac = (dist - minDist) / (maxDist - minDist)
    frac = math.Clamp(frac, 0, 1)

    return SmoothStep01(frac)
end

function H.RegisterRule(id, data)
    H.Rules[id] = {
        id = id,
        priority = tonumber(data.priority) or 0,
        mode = tonumber(data.mode) or OUTLINE_MODE_BOTH,

        render_max_dist = tonumber(data.render_max_dist) or 9000,

        outline_color = data.outline_color or color_white,
        outline_width = math.max(0, math.floor((tonumber(data.outline_width) or 0) + 0.5)),
        outline_min_dist = tonumber(data.outline_min_dist) or 0,
        outline_max_dist = tonumber(data.outline_max_dist) or 0,

        fill_color = data.fill_color or data.outline_color or color_white,
        fill_min_dist = tonumber(data.fill_min_dist) or 0,
        fill_max_dist = tonumber(data.fill_max_dist) or 0,

        collect = data.collect
    }
end

function H.ClearRules()
    H.Rules = {}
end

local O = H.Outline or {}
H.Outline = O

O.List = O.List or {}
O.ListSize = 0
O.RenderEnt = NULL

O.StoreTexture = O.StoreTexture or render.GetScreenEffectTexture(0)
O.DrawTexture  = O.DrawTexture  or render.GetScreenEffectTexture(1)
O.CopyMat      = O.CopyMat      or Material("pp/copy")
O.OutlineMat   = O.OutlineMat   or CreateMaterial(
    "fh_highlight_outline_mat",
    "UnlitGeneric",
    {
        ["$basetexture"] = render.GetScreenEffectTexture(1):GetName(),
        ["$ignorez"]     = 1,
        ["$translucent"] = 1
    }
)

local Q_ENTS  = 1
local Q_COLOR = 2
local Q_MODE  = 3
local Q_THICK = 4

local function Outline_ResetQueue()
    O.List = {}
    O.ListSize = 0
end

local function Outline_Add(ents, color, mode, thickness)
    if O.ListSize >= 255 then return end

    if not istable(ents) then
        ents = { ents }
    end

    if ents[1] == nil then return end
    if (thickness or 0) <= 0 then return end

    O.ListSize = O.ListSize + 1
    O.List[O.ListSize] = {
        [Q_ENTS]  = ents,
        [Q_COLOR] = color or color_white,
        [Q_MODE]  = mode or OUTLINE_MODE_BOTH,
        [Q_THICK] = thickness or 0
    }
end

local function Outline_AddEntries(entries, lp)
    for i = 1, #entries do
        local item = entries[i]
        local ent = item.ent
        if not IsValid(ent) then continue end

        local thickness = GetOutlineThicknessForDistance(item, lp, ent)

        if thickness <= 0 then
            continue
        end

        Outline_Add(
            ent,
            item.outline_color or color_white,
            item.mode,
            thickness
        )
    end
end

local function Outline_RenderQueue()
    if O.ListSize == 0 then return end

    local scene = render.GetRenderTarget()
    local w, h = ScrW(), ScrH()

    render.CopyRenderTargetToTexture(O.StoreTexture)
    render.ClearStencil()

    render.SetStencilEnable(true)
    render.SuppressEngineLighting(true)

    render.SetStencilWriteMask(0xFF)
    render.SetStencilTestMask(0xFF)
    render.SetStencilCompareFunction(STENCIL_GREATER)
    render.SetStencilFailOperation(STENCIL_KEEP)

    cam.Start3D()
        render.SetBlend(1)

        for i = 1, O.ListSize do
            local reference = 0xFF - (i - 1)
            local data = O.List[i]
            local ents = data[Q_ENTS]
            local mode = data[Q_MODE] or OUTLINE_MODE_BOTH

            render.SetStencilReferenceValue(reference)

            if mode == OUTLINE_MODE_VISIBLE then
                render.SetStencilZFailOperation(STENCIL_KEEP)
                render.SetStencilPassOperation(STENCIL_REPLACE)
            else
                render.SetStencilZFailOperation(STENCIL_REPLACE)
                render.SetStencilPassOperation(STENCIL_REPLACE)
            end

            for j = 1, #ents do
                local ent = ents[j]
                if not IsValid(ent) then continue end

                O.RenderEnt = ent
				if mode ~= OUTLINE_MODE_VISIBLE then ent:SetLOD(1) end
                ent:DrawModel()
				ent:SetLOD(-1)
            end
        end

        O.RenderEnt = NULL
        render.SetBlend(1)
    cam.End3D()

    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilPassOperation(STENCIL_KEEP)

    render.Clear(0, 0, 0, 0, false, false)

    cam.Start2D()
        for i = 1, O.ListSize do
            local reference = 0xFF - (i - 1)
            local data = O.List[i]

            render.SetStencilReferenceValue(reference)
            surface.SetDrawColor(data[Q_COLOR])
            surface.DrawRect(0, 0, w, h)
        end
    cam.End2D()

    render.SuppressEngineLighting(false)
    render.SetStencilEnable(false)

    render.CopyRenderTargetToTexture(O.DrawTexture)

    render.SetRenderTarget(scene)
    O.CopyMat:SetTexture("$basetexture", O.StoreTexture)
    render.SetMaterial(O.CopyMat)
    render.DrawScreenQuad()

    render.SetStencilEnable(true)
        render.SetStencilReferenceValue(0)
        render.SetStencilCompareFunction(STENCIL_EQUAL)

        O.OutlineMat:SetTexture("$basetexture", O.DrawTexture)
        render.SetMaterial(O.OutlineMat)

        for i = 1, O.ListSize do
            local data = O.List[i]
            local t = math.max(0, math.floor((tonumber(data[Q_THICK]) or 0) + 0.5))

            if t <= 0 then
                continue
            end

            render.SetBlend(1)

            render.DrawScreenQuadEx(-t,  0, w, h)
            render.DrawScreenQuadEx( t,  0, w, h)
            render.DrawScreenQuadEx( 0, -t, w, h)
            render.DrawScreenQuadEx( 0,  t, w, h)
        end
    render.SetStencilEnable(false)

    Outline_ResetQueue()
end

local function DrawFillEntries(lp, entries)
    if not entries or #entries == 0 then return end
	
	local curItem = 1

    local oldFogMode = render.GetFogMode and render.GetFogMode() or 0

    cam.Start3D()
		local item = entries[curItem]
			
		if item.mode ~= OUTLINE_MODE_VISIBLE then
			cam.IgnoreZ(true)
		end
		
        render.FogMode(0)
        render.SuppressEngineLighting(true)
        render.MaterialOverride(MAT_FLAT)

        if render.ResetModelLighting then
            render.ResetModelLighting(1, 1, 1)
        end

        for i = 1, #entries do
            local item = entries[i]
            local ent = item.ent

            if not IsValid(ent) then continue end

            local fill = GetFillAmountForDistance(item.rule, lp, ent)
            if fill <= 0 then continue end

            local clr = item.fill_color or color_white

            render.SetBlend(fill * ((clr.a or 255) / 255))
            render.SetColorModulation(clr.r / 255, clr.g / 255, clr.b / 255)

			ent:SetLOD(8)
            ent:DrawModel()
			ent:SetLOD(-1)
			curItem = curItem+1
        end

        render.MaterialOverride(nil)
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)
        render.SuppressEngineLighting(false)
        render.FogMode(oldFogMode)
        cam.IgnoreZ(false)
    cam.End3D()
end

local function BuildPriorityBuckets(lp)
    local priorities = {}
    local buckets = {}

    for _, rule in pairs(H.Rules) do
        if not isfunction(rule.collect) then continue end

        local rawEntries = rule.collect(lp, rule)
        if not rawEntries or #rawEntries == 0 then continue end

        for i = 1, #rawEntries do
            local entry = NormalizeEntry(rule, rawEntries[i])
            if not entry then continue end

            local priority = tonumber(entry.priority) or tonumber(rule.priority) or 0

            if not buckets[priority] then
                buckets[priority] = {}
                priorities[#priorities + 1] = priority
            end

            buckets[priority][#buckets[priority] + 1] = entry
        end
    end

    table.sort(priorities)

    return priorities, buckets
end

H.ClearRules()

-- Базовые правила твоей системы

-- Замены halo.Add из режима

hook.Add("PostDrawEffects", "FHPlus.Highlight.Draw", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local priorities, buckets = BuildPriorityBuckets(lp)

    for i = 1, #priorities do
        local priority = priorities[i]
        local entries = buckets[priority]

        if entries and #entries > 0 then
            DrawFillEntries(lp, entries)
            Outline_AddEntries(entries, lp)
            Outline_RenderQueue()
        end
    end
end)

OUTLINE = H