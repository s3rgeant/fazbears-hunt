AddCSLuaFile()
-- Convars
pills.convars = {}
-- Admin vars

-- Client vars
if CLIENT then
    pills.convars.cl_thirdperson = CreateClientConVar("fh_thirdperson", 0)
    pills.convars.cl_hidehud = CreateClientConVar("pk_pill_cl_hidehud", 0)
end
