local PRESETS = {
    concrete = {
        flecks = { "effects/fleck_cement1", "effects/fleck_cement2" },
        fleckCol = Color(170, 170, 170), smokeCol = Color(165, 165, 160),
        fleckN = 18, smokeN = 10, sparkN = 4,
    },
    brick = {
        flecks = { "effects/fleck_cement1", "effects/fleck_cement2" },
        fleckCol = Color(160, 85, 65), smokeCol = Color(150, 125, 115),
        fleckN = 18, smokeN = 10, sparkN = 3,
    },
    wood = {
        flecks = { "effects/fleck_wood1", "effects/fleck_wood2" },
        fleckCol = Color(165, 115, 70), smokeCol = Color(140, 120, 95),
        fleckN = 16, smokeN = 5, sparkN = 0,
    },
    metal = {
        flecks = { "effects/fleck_tile1", "effects/fleck_tile2" },
        fleckCol = Color(110, 110, 115), smokeCol = Color(120, 120, 120),
        fleckN = 6, smokeN = 4, sparkN = 24,
    },
    dirt = {
        flecks = { "effects/fleck_cement1", "effects/fleck_cement2" },
        fleckCol = Color(100, 70, 45), smokeCol = Color(125, 100, 75),
        fleckN = 14, smokeN = 14, sparkN = 0,
    },
    grass = {
        flecks = { "effects/fleck_cement1", "effects/fleck_cement2" },
        fleckCol = Color(85, 95, 50), smokeCol = Color(115, 115, 85),
        fleckN = 14, smokeN = 10, sparkN = 0,
    },
    sand = {
        flecks = { "effects/fleck_cement1", "effects/fleck_cement2" },
        fleckCol = Color(215, 195, 145), smokeCol = Color(215, 200, 165),
        fleckN = 12, smokeN = 16, sparkN = 0,
    },
    snow = {
        flecks = { "effects/fleck_cement1", "effects/fleck_cement2" },
        fleckCol = Color(240, 245, 255), smokeCol = Color(240, 245, 255),
        fleckN = 12, smokeN = 12, sparkN = 0,
    },
    glass = {
        flecks = { "effects/fleck_glass1", "effects/fleck_glass2", "effects/fleck_glass3" },
        fleckCol = Color(215, 235, 245), smokeCol = Color(200, 210, 215),
        fleckN = 26, smokeN = 2, sparkN = 0,
    },
    tile = {
        flecks = { "effects/fleck_tile1", "effects/fleck_tile2" },
        fleckCol = Color(225, 225, 220), smokeCol = Color(190, 190, 185),
        fleckN = 22, smokeN = 6, sparkN = 2,
    },
}

local RULES = {
    { "glass",  { "glass", "window" } },
    { "metal",  { "metal", "grate", "vent", "chain", "canister", "popcan", "weapon", "computer" } },
    { "wood",   { "wood", "cardboard", "paper", "furniture" } },
    { "tile",   { "tile", "ceramic", "porcelain" } },
    { "brick",  { "brick", "plaster", "boulder" } },
    { "snow",   { "snow", "ice" } },
    { "sand",   { "sand" } },
    { "grass",  { "grass", "foliage" } },
    { "dirt",   { "dirt", "mud", "gravel", "slime" } },
    { "concrete", { "concrete", "rock", "stone", "asphalt", "road" } },
}

local MAT_FALLBACK = {
    [MAT_CONCRETE] = "concrete", [MAT_METAL] = "metal",  [MAT_DIRT]  = "dirt",
    [MAT_SAND]     = "sand",     [MAT_WOOD]  = "wood",   [MAT_GLASS] = "glass",
    [MAT_TILE]     = "tile",     [MAT_GRASS] = "grass",  [MAT_SNOW]  = "snow",
    [MAT_VENT]     = "metal",    [MAT_GRATE] = "metal",  [MAT_COMPUTER] = "metal",
}

local function Classify(propName, matType)
    propName = string.lower(propName or "")

    for _, rule in ipairs(RULES) do
        for _, pat in ipairs(rule[2]) do
            if string.find(propName, pat, 1, true) then
                return rule[1]
            end
        end
    end

    return MAT_FALLBACK[matType] or "concrete"
end

local function BlendColor(base, surf, t)
    local r = Lerp(t, base.r, surf.r)
    local g = Lerp(t, base.g, surf.g)
    local b = Lerp(t, base.b, surf.b)

    local m = math.max(r, g, b, 1)
    if m < 70 then
        local k = 70 / m
        r, g, b = r * k, g * k, b * k
    end

    return Color(math.min(r, 255), math.min(g, 255), math.min(b, 255))
end

local function AddSmoke(em, pos, vel, col, sizeMul, alpha)
    local p = em:Add(string.format("particle/smokesprites_%04d", math.random(1, 9)), pos)
    if not p then return end

    p:SetVelocity(vel)
    p:SetAirResistance(150)
    p:SetGravity(Vector(0, 0, 20))
    p:SetDieTime(math.Rand(0.9, 1.7))
    p:SetStartAlpha(alpha)
    p:SetEndAlpha(0)
    p:SetStartSize(math.Rand(10, 18) * sizeMul)
    p:SetEndSize(math.Rand(50, 85) * sizeMul)
    p:SetRoll(math.Rand(0, 360))
    p:SetRollDelta(math.Rand(-1.2, 1.2))
    p:SetColor(col.r, col.g, col.b)
    p:SetLighting(true)
end

local function AddFleck(em, mat, pos, vel, col)
    local p = em:Add(mat, pos)
    if not p then return end

    local k = math.Rand(0.75, 1.15)
    local s = math.Rand(3, 8)

    p:SetVelocity(vel)
    p:SetAirResistance(5)
    p:SetGravity(Vector(0, 0, -700))
    p:SetDieTime(math.Rand(1.2, 2.5))
    p:SetStartAlpha(255)
    p:SetEndAlpha(0)
    p:SetStartSize(s)
    p:SetEndSize(s)
    p:SetRoll(math.Rand(0, 360))
    p:SetRollDelta(math.Rand(-12, 12))
    p:SetColor(math.min(col.r * k, 255), math.min(col.g * k, 255), math.min(col.b * k, 255))
    p:SetCollide(true)
    p:SetBounce(0.35)
    p:SetLighting(true)
end

local function AddSpark(em, pos, vel)
    local p = em:Add("effects/spark", pos)
    if not p then return end

    p:SetVelocity(vel)
    p:SetGravity(Vector(0, 0, -600))
    p:SetDieTime(math.Rand(0.25, 0.6))
    p:SetStartAlpha(255)
    p:SetEndAlpha(0)
    p:SetStartSize(math.Rand(1.5, 3))
    p:SetEndSize(0)
    p:SetStartLength(math.Rand(6, 14))
    p:SetEndLength(0)
    p:SetColor(255, 200, 120)
    p:SetCollide(true)
    p:SetBounce(0.5)
end

function EFFECT:Init(data)
    local pos    = data:GetOrigin()
    local normal = data:GetNormal()
    local scale  = data:GetScale()

    if normal:LengthSqr() < 0.01 then normal = Vector(0, 0, 1) end
    normal:Normalize()
    if scale <= 0 then scale = 1 end
    scale = math.Clamp(scale, 0.3, 2.5)

    local surfIdx = data:GetSurfaceProp()
    local class   = Classify(util.GetSurfacePropName(surfIdx), data:GetMaterialIndex())
    local P       = PRESETS[class] or PRESETS.concrete

    local surfCol = Color(255, 255, 255)
    local sc = render.GetSurfaceColor(pos + normal * 4, pos - normal * 4)
    if sc then
        surfCol = Color(sc.x * 255, sc.y * 255, sc.z * 255)
    end

    local smokeCol = BlendColor(P.smokeCol, surfCol, 0.45)
    local fleckCol = BlendColor(P.fleckCol, surfCol, 0.35)

    local spawn = pos + normal * 2
    local ang   = normal:Angle()
    local right, up = ang:Right(), ang:Up()

    local em = ParticleEmitter(pos, false)
    if not em then return end

    local ringN = 10
    for i = 1, ringN do
        local a   = ((i + math.Rand(-0.3, 0.3)) / ringN) * math.pi * 2
        local dir = right * math.cos(a) + up * math.sin(a) + normal * 0.15
        AddSmoke(em, spawn, dir * math.Rand(140, 260) * scale, smokeCol, scale * 0.8, 140)
    end

    for i = 1, math.floor(P.smokeN * scale) do
        local vel = (normal * math.Rand(80, 220) + VectorRand() * 70) * scale
        AddSmoke(em, spawn + VectorRand() * 6, vel, smokeCol, scale, math.Rand(110, 170))
    end

    for i = 1, math.floor(P.fleckN * scale) do
        local dir = normal + VectorRand() * 0.9
        dir:Normalize()
        AddFleck(em, P.flecks[math.random(#P.flecks)], spawn + VectorRand() * 4, dir * math.Rand(180, 520) * scale, fleckCol)
    end

    for i = 1, math.floor(P.sparkN * scale) do
        local dir = normal + VectorRand() * 0.8
        dir:Normalize()
        AddSpark(em, spawn, dir * math.Rand(250, 650) * scale)
    end

    if P.sparkN >= 10 then
        local f = em:Add("sprites/light_glow02_add", spawn + normal * 3)
        if f then
            f:SetDieTime(0.08)
            f:SetStartAlpha(255)
            f:SetEndAlpha(0)
            f:SetStartSize(40 * scale)
            f:SetEndSize(10)
            f:SetColor(255, 200, 120)
        end
    end

    em:Finish()

    local sd = util.GetSurfaceData(surfIdx)
    local snd = sd and sd.impactHardSound
    if snd and snd ~= "" then
        sound.Play(snd, pos, 85, math.random(85, 100), 1)
    end
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end