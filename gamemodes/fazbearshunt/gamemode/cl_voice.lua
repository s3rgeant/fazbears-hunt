local PANEL = {}
AccessorFunc(PANEL, "m_Player", "Player")

function PANEL:Init()
    self:SetTall(36)
    self:SetMouseInputEnabled(false)

    -- аватарка
    self.Avatar = vgui.Create("AvatarImage", self)
    self.Avatar:SetSize(32, 32)
    self.Avatar:Dock(LEFT)
    self.Avatar:DockMargin(6, 2, 6, 2)

    -- имя
    self.NameLabel = vgui.Create("DLabel", self)
    self.NameLabel:SetFont("DermaDefaultBold")
    self.NameLabel:SetTextColor(Color(255,255,255))
    self.NameLabel:Dock(LEFT)
    self.NameLabel:DockMargin(0, 6, 8, 0)
    self.NameLabel:SetWide(120)

    -- история и анимация
    self.History = {}
    for i=1,15 do self.History[i] = 0 end
    self.Anim = 0                -- текущее анимированное значение для первой полоски
    self.NextShift = CurTime() + 0.5
end

function PANEL:Setup(ply)
    self.Player = ply
    if IsValid(ply) then
        self.Avatar:SetPlayer(ply)
        self.NameLabel:SetText(ply:Nick())
    end
end

function PANEL:Think()
    if not IsValid(self.Player) then
        self:Remove()
        return
    end
end

function PANEL:Paint(w, h)
    -- фон панели (полупрозрачный)
    draw.RoundedBox(6, 0, 0, w, h, Color(20, 20, 20, 200))

    -- целевое значение громкости (0..1)
    local target = 0
    if IsValid(self.Player) then
        target = self.Player:VoiceVolume() or 0
    end

    -- плавное приближение anim к текущему target (визуальная "регулировка" в течение периода)
    local ft = FrameTime()
    local speed = 10 -- скорость интерполяции (увеличь для более резкого отклика)
    self.Anim = Lerp(math.Clamp(ft * speed, 0, 1), self.Anim, target)

    -- каждые 0.5 секунд фиксируем текущее anim и сдвигаем историю вправо
    if CurTime() >= self.NextShift then
        self.NextShift = CurTime() + 0.5
        table.insert(self.History, 1, self.Anim)   -- вставляем в начало
        if #self.History > 15 then
            table.remove(self.History, 16)
        end
    end

    -- отрисовка полосок справа от аватарки
    local startX = self.Avatar:GetWide() + 14
    local areaW = w - startX - 8
    if areaW < 1 then return end
    local barW = areaW / 15
    local maxBarH = h - 8

    for i = 1, 15 do
        local val
        if i == 1 then
            -- первая полоска — живая, показывает self.Anim
            val = self.Anim
        else
            -- остальные — из истории (предыдущие значения)
            val = self.History[i] or 0
        end
        val = math.Clamp(val, 0, 1)
        local bw = math.max(1, barW - 2)
        local bh = math.Round(val * maxBarH)
        local x = startX + (i - 1) * barW
        local y = h - bh - 4

        -- зелёная тонкая полоска (чем тише — тем ниже высота)
        surface.SetDrawColor(0, 200, 0, 210)
        surface.DrawRect(x, y, bw, bh)
    end
end

vgui.Register("VoiceNotifyCustom", PANEL, "DPanel")

-- контейнер для всех панелей голосов (создаём один раз)
if not IsValid(g_VoicePanelList) then
    g_VoicePanelList = vgui.Create("DPanelList")
    g_VoicePanelList:SetSize(280, 600)
    g_VoicePanelList:SetPos(ScrW() - 290, 80) -- справа сверху, подбери под свой HUD
    g_VoicePanelList:SetSpacing(6)
    g_VoicePanelList:EnableHorizontal(false)
    g_VoicePanelList:EnableVerticalScrollbar(false)
    g_VoicePanelList.Paint = function() end
end

-- когда игрок начал говорить — создаём панель (если ещё нет)
hook.Add("PlayerStartVoice", "Fazbears_Voice_Start", function(ply)
    if not IsValid(ply) then return end
    if IsValid(ply.VoicePanel) then return end

    local pnl = vgui.Create("VoiceNotifyCustom")
    pnl:Setup(ply)
    pnl:SetWide(g_VoicePanelList:GetWide() - 4)
    g_VoicePanelList:AddItem(pnl)
    ply.VoicePanel = pnl
end)

-- когда игрок перестал говорить — удаляем панель
hook.Add("PlayerEndVoice", "Fazbears_Voice_End", function(ply)
    if not IsValid(ply) then return end
    if IsValid(ply.VoicePanel) then
        g_VoicePanelList:RemoveItem(ply.VoicePanel)
        ply.VoicePanel:Remove()
        ply.VoicePanel = nil
    end
end)

-- подчистка при выходе игрока (на всякий случай)
hook.Add("PlayerDisconnected", "Fazbears_Voice_Disconnect", function(ply)
    if IsValid(ply) and IsValid(ply.VoicePanel) then
        g_VoicePanelList:RemoveItem(ply.VoicePanel)
        ply.VoicePanel:Remove()
        ply.VoicePanel = nil
    end
end)