AddCSLuaFile()
-- Convars
pills.convars = {}
-- Admin vars

-- Client vars
if CLIENT then
    pills.convars.cl_thirdperson = CreateClientConVar("fh_thirdperson", 0)
end
