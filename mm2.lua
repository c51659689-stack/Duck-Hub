--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║   D U C K   H U B   |  M U R D E R   M Y S T E R Y   2    ║
    ║   v4.6.0  -  hrpOf/humOf polymorphes                      ║
    ╚═══════════════════════════════════════════════════════════╝
]]

--==================== SERVICES ====================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Stats             = game:GetService("Stats")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = Workspace.CurrentCamera

--==================== CONFIG ====================
local HUB_NAME       = "Duck Hub"
local HUB_VERSION    = "4.6.0"
local KEY_URL        = "https://c51659689-stack.github.io/Duck-Hub/key.txt"
local GET_KEY_URL    = "https://link-target.net/9911616/gcC3prcBBtKj"
local KEY_FILE       = "DuckHub_MM2.key"
local CONFIG_FILE    = "DuckHub_config.json"
local MAX_TRIES      = 5
local ALWAYS_ASK_KEY = true

--==================== THÈME ====================
local C = {
    BG = Color3.fromRGB(10, 10, 15), PANEL = Color3.fromRGB(17, 17, 24),
    CARD = Color3.fromRGB(23, 23, 31), CARD_HOV = Color3.fromRGB(31, 31, 42),
    STROKE = Color3.fromRGB(38, 38, 51), INPUT = Color3.fromRGB(20, 20, 28),
    TEXT = Color3.fromRGB(242, 242, 247), SUB = Color3.fromRGB(138, 138, 160),
    A1 = Color3.fromRGB(124, 92, 255), A2 = Color3.fromRGB(255, 79, 216),
    RED = Color3.fromRGB(255, 84, 100), GREEN = Color3.fromRGB(80, 230, 150),
    BLUE = Color3.fromRGB(90, 170, 255), YELLOW = Color3.fromRGB(255, 205, 90),
}

local FONT  = Enum.Font.Gotham
local FONTB = Enum.Font.GothamBold

--==================== ÉTAT ====================
local Connections = {}
local AccentGrads = {}
local Unloaded    = false
local UI          = { tabs = {}, current = nil }
local RoleCache   = {}

local notify, loop

local function addConn(c) table.insert(Connections, c); return c end
local function conn(signal, fn) return addConn(signal:Connect(fn)) end

--==================== HELPERS ====================
local function create(class, props, children)
    local inst = Instance.new(class)
    local parent = props and props.Parent
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then pcall(function() inst[k] = v end) end
    end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, r) return create("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = inst }) end

local function stroke(inst, color, thick, trans)
    return create("UIStroke", {
        Color = color or C.STROKE, Thickness = thick or 1,
        Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst,
    })
end

local function grad(inst, c1, c2, rot)
    local g = create("UIGradient", { Color = ColorSequence.new(c1 or C.A1, c2 or C.A2), Rotation = rot or 0, Parent = inst })
    table.insert(AccentGrads, { inst = g })
    return g
end

local function setAccent(a1, a2)
    C.A1, C.A2 = a1, a2
    for _, g in ipairs(AccentGrads) do
        if g.inst and g.inst.Parent then pcall(function() g.inst.Color = ColorSequence.new(a1, a2) end) end
    end
end

local function pad(inst, t, b, l, r)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), Parent = inst,
    })
end

local function tween(inst, time, props, style)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play(); return t
end

local function newGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.DisplayOrder = 999
    local cands = {}
    pcall(function() if gethui then table.insert(cands, gethui()) end end)
    pcall(function() table.insert(cands, game:GetService("CoreGui")) end)
    table.insert(cands, LP:WaitForChild("PlayerGui"))
    for _, p in ipairs(cands) do
        local ok = pcall(function() gui.Parent = p end)
        if ok and gui.Parent then return gui end
    end
    return gui
end

--==================== HTTP / CLÉ ====================
local function httpGet(url)
    local ok, res = pcall(function()
        if syn and syn.request then return syn.request({ Url = url, Method = "GET" }).Body
        elseif http and http.request then return http.request({ Url = url, Method = "GET" }).Body
        elseif request then return request({ Url = url, Method = "GET" }).Body
        elseif fluxus and fluxus.request then return fluxus.request({ Url = url, Method = "GET" }).Body
        elseif HttpGet then return HttpGet(url)
        elseif fetch then return fetch(url) end
    end)
    if ok and type(res) == "string" then return res end
    return nil
end

local function openLink(url)
    if setclipboard then pcall(setclipboard, url) end
    pcall(function() game:GetService("GuiService"):OpenBrowserWindow(url) end)
    pcall(function() if openbrowser then openbrowser(url) end end)
end

local function checkKey(key)
    if not key or #key < 3 then return false end
    local body = httpGet(KEY_URL)
    if not body then return nil end
    local clean = key:gsub("%s+", "")
    for line in body:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") == clean then return true end
    end
    return false
end

local function loadSavedKey()
    if isfile and readfile and isfile(KEY_FILE) then
        local ok, c = pcall(readfile, KEY_FILE)
        if ok and type(c) == "string" then return c:gsub("%s+", "") end
    end
    return nil
end

local function saveKey(k) if writefile then pcall(writefile, KEY_FILE, k:gsub("%s+", "")) end end
local function clearKey() if delfile and isfile and isfile(KEY_FILE) then pcall(delfile, KEY_FILE) end end

--==================== FEATURES ====================
local F = {
    Aimbot = false, AimbotKey = Enum.KeyCode.E, AimbotSmooth = 0.25, AimbotFOV = 150,
    SilentAim = false, AutoShoot = false, ShootRange = 250, ShootLOS = true, HeadPriority = true,
    LeadTime = 0, AutoStrafe = false, JumpDodge = false, TriggerBot = false, AutoKnife = false,
    KillAura = false, KillAuraRange = 10, KillAllDelay = 0.22, AutoEquip = false, FireDelay = 0.1,
    AntiFling = false, FlingForce = 1600, FlingMode = "impact", ClickFling = false,
    Hitbox = false, HitboxSize = 8, AutoWin = false, GodMode = false,
    AutoFarm = false, AutoCollect = false, CollectRange = 8, NearestOnly = false,
    CoinMagnet = false, CoinESP = false, FarmDelay = 0.4, FarmPaused = false,
    Fly = false, FlySpeed = 55, FlyVertical = false, Glide = false,
    AutoParkour = false, AntiRagdoll = false, StickGround = false,
    NoClip = false, WalkSpeed = 16, JumpPower = 50, InfJump = false,
    ESP = false, Boxes = true, Names = true, Roles = true, Distance = true, HealthBar = false,
    WeaponESP = false, Tracers = false, CornerStyle = false, BoxThick = 1, ESPMaxDist = 500,
    ESPTransparency = 1, FOVCircle = false, Crosshair = false, Hitmarker = false, Glow = false,
    FullBright = false, NoFog = false, Vignette = false, ColorCorrection = false,
    Bloom = false, SunRays = false, CustomSky = false,
    FPSMeter = false, PingMeter = false, Clock = false, PlayerListHUD = false,
    AntiAFK = false, UnlockFPS = false, FPSCap = 240, AutoRejoin = false, AntiKick = false,
    ServerScan = 100, Watermark = false, WMpos = 1,
    ClickTP = false, AutoDodge = false, DodgeRange = 25, Freeze = false,
    Rainbow = false, Spin = false, SpinSpeed = 12, Trail = false, MaxZoom = false,
    Aura = false, BigHead = false, SmallChar = false, InvisibleBody = false,
    HideKey = Enum.KeyCode.RightShift, Notifs = true, AutoHideSpawn = false,
    UIScale = 1, UIOpacity = 0, SavedPos = nil,
    LoopTokens = {}, ESPObjects = {}, LightBackup = {}, FlyBV = nil, FlyBG = nil,
    FX = {}, HUD = {},
}

--==================== ACCESSEURS POLYMORPHES ====================
local function charOf(x)
    if not x then return nil end
    if x:IsA("Player") then return x.Character end
    if x:IsA("Model") then return x end
    return nil
end

local function hrpOf(x)
    local ch = charOf(x)
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function humOf(x)
    local ch = charOf(x)
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

--==================== RÔLES ====================
local function detectRole(plr)
    for _, attr in ipairs({"Role", "MM2Role", "role"}) do
        local ok, v = pcall(function() return plr:GetAttribute(attr) end)
        if ok and type(v) == "string" then
            local lv = string.lower(v)
            if string.find(lv, "murder") then return "Murderer" end
            if string.find(lv, "sheriff") then return "Sheriff" end
            if string.find(lv, "innocent") then return "Innocent" end
        end
    end
    local char = plr.Character
    if char then
        if char:FindFirstChild("Knife") then return "Murderer" end
        if char:FindFirstChild("Gun") then return "Sheriff" end
    end
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        if bp:FindFirstChild("Knife") then return "Murderer" end
        if bp:FindFirstChild("Gun") then return "Sheriff" end
    end
    local pg = plr:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text and #d.Text < 40 then
                local t = string.lower(d.Text)
                if string.find(t, "murder") then return "Murderer" end
                if string.find(t, "sheriff") then return "Sheriff" end
            end
        end
    end
    return RoleCache[plr] or "Innocent"
end

local function getRole(plr) return RoleCache[plr] or "Innocent" end

local function roleColor(role)
    if role == "Murderer" then return C.RED end
    if role == "Sheriff" then return C.BLUE end
    return C.GREEN
end

local function refreshRoles()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local r = detectRole(p)
            if r ~= "Innocent" or not RoleCache[p] then RoleCache[p] = r end
        end
    end
end

local function alive(plr)
    local h = humOf(plr)
    return h and h.Health > 0
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p) and getRole(p) == "Murderer" then return p end
    end
end

local function getSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p) and getRole(p) == "Sheriff" then return p end
    end
end

local function teleportTo(cf)
    local hrp = hrpOf(LP)
    if hrp and cf then hrp.CFrame = cf + Vector3.new(0, 3, 0) end
end

local function getCoins()
    local list = {}
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o.Name == "Coin" and o:IsA("BasePart") then table.insert(list, o) end
    end
    return list
end

local function clickMouse()
    if mouse1click then mouse1click()
    elseif VirtualUser then pcall(function() VirtualUser:ClickButton1(Vector2.new()) end) end
end

local function targetPart(plr)
    local ch = charOf(plr)
    if not ch then return nil end
    if F.HeadPriority then
        return ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
    end
    return ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head")
end

local function tpPlayer(plr)
    local hrp = hrpOf(plr)
    if hrp then teleportTo(hrp.CFrame); return true end
    return false
end

local function hasLOS(part)
    if not F.ShootLOS then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character, Camera}
    local origin = Camera.CFrame.Position
    local res = Workspace:Raycast(origin, part.Position - origin, params)
    return res == nil or (res.Instance and res.Instance:IsDescendantOf(part.Parent))
end

local function nearestPlayer(range)
    local me = hrpOf(LP)
    if not me then return nil end
    local best, bd = nil, range or math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p) and hrpOf(p) then
            local d = (hrpOf(p).Position - me.Position).Magnitude
            if d < bd then best, bd = p, d end
        end
    end
    return best
end

--==================== ESP ====================
local function removeESPFor(plr)
    local d = F.ESPObjects[plr]
    if d then
        for _, k in ipairs({"box", "name", "dist", "tracer", "hp", "hpbg"}) do
            if d[k] then pcall(function() d[k]:Remove() end) end
        end
        if d.corners then for _, l in ipairs(d.corners) do pcall(function() l:Remove() end) end end
        F.ESPObjects[plr] = nil
    end
end

local function clearESP() for p in pairs(F.ESPObjects) do removeESPFor(p) end end

local function createESP(plr)
    if plr == LP or F.ESPObjects[plr] or not Drawing then return end
    local d = { corners = {} }
    d.box = Drawing.new("Square"); d.box.Thickness = 1; d.box.Filled = false; d.box.Visible = false
    d.name = Drawing.new("Text"); d.name.Size = 14; d.name.Center = true; d.name.Outline = true; d.name.Visible = false
    d.dist = Drawing.new("Text"); d.dist.Size = 12; d.dist.Center = true; d.dist.Outline = true; d.dist.Visible = false
    d.tracer = Drawing.new("Line"); d.tracer.Thickness = 1; d.tracer.Visible = false
    d.hpbg = Drawing.new("Square"); d.hpbg.Filled = true; d.hpbg.Visible = false
    d.hp = Drawing.new("Square"); d.hp.Filled = true; d.hp.Visible = false
    for _ = 1, 8 do
        local l = Drawing.new("Line"); l.Thickness = 2; l.Visible = false
        table.insert(d.corners, l)
    end
    F.ESPObjects[plr] = d
end

conn(Players.PlayerAdded, function(p) if F.ESP then createESP(p) end end)
conn(Players.PlayerRemoving, function(p) removeESPFor(p); RoleCache[p] = nil end)

conn(RunService.RenderStepped, function()
    if not F.ESP then return end
    Camera = Workspace.CurrentCamera
    local vp = Camera.ViewportSize
    for plr, d in pairs(F.ESPObjects) do
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local dist = hrp and (Camera.CFrame.Position - hrp.Position).Magnitude or 0
        if hrp and hum and hum.Health > 0 and dist <= F.ESPMaxDist then
            local head = char:FindFirstChild("Head") or hrp
            local tP, tV = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
            local bP, bV = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.8, 0))
            local col = roleColor(getRole(plr))
            if tV and bV then
                local h = math.abs(tP.Y - bP.Y)
                local w = h * 0.55
                local x, y = tP.X - w / 2, tP.Y
                local tr = F.ESPTransparency

                d.box.Visible = F.Boxes and not F.CornerStyle
                d.box.Color = col; d.box.Transparency = tr; d.box.Thickness = F.BoxThick
                d.box.Size = Vector2.new(w, h); d.box.Position = Vector2.new(x, y)

                local cl = math.min(w, h) * 0.22
                local pts = {
                    {x, y, x + cl, y}, {x, y, x, y + cl},
                    {x + w, y, x + w - cl, y}, {x + w, y, x + w, y + cl},
                    {x, y + h, x + cl, y + h}, {x, y + h, x, y + h - cl},
                    {x + w, y + h, x + w - cl, y + h}, {x + w, y + h, x + w, y + h - cl},
                }
                for i, l in ipairs(d.corners) do
                    l.Visible = F.CornerStyle; l.Color = col; l.Transparency = tr; l.Thickness = F.BoxThick
                    l.From = Vector2.new(pts[i][1], pts[i][2])
                    l.To = Vector2.new(pts[i][3], pts[i][4])
                end

                d.name.Visible = F.Names; d.name.Color = col; d.name.Transparency = tr
                d.name.Position = Vector2.new(tP.X, y - 30)
                d.name.Text = (F.Roles and ("[" .. getRole(plr) .. "] ") or "") .. plr.Name

                d.dist.Visible = F.Distance; d.dist.Color = C.YELLOW; d.dist.Transparency = tr
                d.dist.Position = Vector2.new(tP.X, y - 16); d.dist.Text = math.floor(dist) .. "m"

                d.tracer.Visible = F.Tracers; d.tracer.Color = col; d.tracer.Transparency = tr
                d.tracer.From = Vector2.new(vp.X / 2, vp.Y); d.tracer.To = Vector2.new(tP.X, y + h)

                local hpRatio = hum.Health / math.max(hum.MaxHealth, 1)
                d.hpbg.Visible = F.HealthBar; d.hpbg.Color = Color3.fromRGB(20, 20, 20)
                d.hpbg.Transparency = 0.35; d.hpbg.Size = Vector2.new(3, h); d.hpbg.Position = Vector2.new(x - 6, y)
                d.hp.Visible = F.HealthBar
                d.hp.Color = hpRatio > 0.5 and C.GREEN or (hpRatio > 0.25 and C.YELLOW or C.RED)
                d.hp.Transparency = 0.1; d.hp.Size = Vector2.new(3, h * hpRatio)
                d.hp.Position = Vector2.new(x - 6, y + h * (1 - hpRatio))
            else
                for _, k in ipairs({"box", "name", "dist", "tracer", "hp", "hpbg"}) do d[k].Visible = false end
                for _, l in ipairs(d.corners) do l.Visible = false end
            end
        else
            for _, k in ipairs({"box", "name", "dist", "tracer", "hp", "hpbg"}) do d[k].Visible = false end
            for _, l in ipairs(d.corners) do l.Visible = false end
        end
    end
end)

local function setGlow(state)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local old = p.Character:FindFirstChild("DuckGlow")
            if state then
                if not old then
                    local h = Instance.new("Highlight")
                    h.Name = "DuckGlow"
                    h.FillColor = roleColor(getRole(p)); h.FillTransparency = 0.55
                    h.OutlineColor = roleColor(getRole(p)); h.Parent = p.Character
                end
            elseif old then old:Destroy() end
        end
    end
end

--==================== AIM ====================
local function aimAt(part, smooth)
    local pos, on = Camera:WorldToViewportPoint(part.Position)
    if not on then return end
    local vp = Camera.ViewportSize
    local dx, dy = pos.X - vp.X / 2, pos.Y - vp.Y / 2
    if math.abs(dx) > F.AimbotFOV or math.abs(dy) > F.AimbotFOV then return end
    local s = smooth or F.AimbotSmooth
    if mousemoverel then mousemoverel(dx * s, dy * s)
    elseif mousemoveabs then mousemoveabs(vp.X / 2 + dx * s, vp.Y / 2 + dy * s) end
end

conn(RunService.RenderStepped, function()
    if Unloaded then return end
    local part = targetPart(getMurderer())
    if not part then return end
    if F.Aimbot and UserInputService:IsKeyDown(F.AimbotKey) then aimAt(part) end
    if F.SilentAim and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then aimAt(part, 1) end
end)

--==================== KILL ALL ====================
local function equipWeapon()
    local char = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    if not char then return nil end
    local weapon = char:FindFirstChild("Knife") or char:FindFirstChild("Gun")
        or (bp and (bp:FindFirstChild("Knife") or bp:FindFirstChild("Gun")))
    if weapon and weapon.Parent ~= char then
        pcall(function() weapon.Parent = char end)
        task.wait(0.2)
    end
    return weapon
end

local function strike(weapon, targetHrp)
    clickMouse()
    if weapon and weapon.Name == "Knife" then
        local blade = weapon:FindFirstChild("Blade") or weapon:FindFirstChild("Handle")
        if blade and blade:IsA("BasePart") then
            pcall(function()
                firetouchinterest(blade, targetHrp, 0)
                firetouchinterest(blade, targetHrp, 1)
            end)
        end
    end
end

local function killAll(passes)
    passes = passes or 2
    local me = hrpOf(LP)
    if not me then return end
    local weapon = equipWeapon()
    if not weapon then return notify("Duck Hub", "Aucune arme (couteau ou pistolet).", 4) end

    local killed = 0
    for _ = 1, passes do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and alive(p) and hrpOf(p) then
                local target = hrpOf(p)
                me.CFrame = target.CFrame * CFrame.new(0, 0, 0.4)
                RunService.Heartbeat:Wait()
                RunService.Heartbeat:Wait()
                strike(weapon, target)
                task.wait(F.KillAllDelay)
                if not alive(p) then killed += 1 end
            end
        end
        if killed >= #Players:GetPlayers() - 1 then break end
        task.wait(0.3)
    end
    notify("Duck Hub", "Kill All terminé (" .. killed .. " éliminé(s)).", 4)
end

--==================== FLING ====================
local function flingImpact(target)
    local me, t = hrpOf(LP), hrpOf(target)
    if not me or not t then return false end
    t.Anchored = false

    local dir = t.Position - me.Position
    if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
    dir = dir.Unit

    me.CFrame = CFrame.new(t.Position - dir * 3 + Vector3.new(0, 1, 0), t.Position)
    RunService.Heartbeat:Wait()

    for _ = 1, 7 do
        if not me.Parent then break end
        me.Velocity = dir * F.FlingForce + Vector3.new(0, F.FlingForce * 0.45, 0)
        RunService.Heartbeat:Wait()
    end
    return true
end

local function flingWeld(target)
    local me, t = hrpOf(LP), hrpOf(target)
    if not me or not t then return false end
    t.Anchored = false

    me.CFrame = t.CFrame * CFrame.new(0, 0, 2)
    RunService.Heartbeat:Wait()

    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1 = me, t
    weld.Parent = me

    task.spawn(function()
        for _ = 1, 28 do
            if not (me.Parent and t.Parent) then break end
            t.CFrame = t.CFrame * CFrame.Angles(math.rad(55), math.rad(30), math.rad(55))
            RunService.Heartbeat:Wait()
        end
    end)

    task.delay(0.7, function() pcall(function() weld:Destroy() end) end)
    return true
end

local function flingSpin(target)
    local t = hrpOf(target)
    if not t then return false end
    t.Anchored = false
    task.spawn(function()
        for _ = 1, 24 do
            if not t.Parent then break end
            t.CFrame = t.CFrame * CFrame.Angles(math.rad(50), math.rad(30), math.rad(50))
            RunService.Heartbeat:Wait()
        end
    end)
    return true
end

local function flingChar(target)
    if not target then return false end
    local mode = F.FlingMode or "impact"
    if mode == "weld" then return flingWeld(target) end
    if mode == "spin" then return flingSpin(target) end
    return flingImpact(target)
end

local function flingMurderer()
    local m = getMurderer()
    if m and m.Character and flingChar(m.Character) then
        notify("Duck Hub", "Murderer fling (" .. (F.FlingMode or "impact") .. ").", 3)
    else
        notify("Duck Hub", "Aucun murderer.", 3)
    end
end

local function flingAll()
    task.spawn(function()
        local n = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and flingChar(p.Character) then
                n += 1
                task.wait(0.15)
            end
        end
        notify("Duck Hub", n .. " joueur(s) fling.", 3)
    end)
end

--==================== BOUCLES ====================
loop = function(name, fn, delay)
    F.LoopTokens[name] = true
    task.spawn(function()
        while F.LoopTokens[name] and not Unloaded do
            pcall(fn)
            task.wait(delay or 0.1)
        end
    end)
end

loop("Roles", refreshRoles, 0.4)

loop("AutoShoot", function()
    if not F.AutoShoot then return end
    local m = getMurderer()
    if not m then return end
    local hrp, me = hrpOf(m), hrpOf(LP)
    if not hrp or not me then return end
    if (hrp.Position - me.Position).Magnitude > F.ShootRange then return end
    local part = targetPart(m)
    if not part then return end
    local _, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen or not hasLOS(part) then return end
    if F.LeadTime > 0 then
        local pred = part.Position + hrp.Velocity * F.LeadTime
        local p2, on2 = Camera:WorldToViewportPoint(pred)
        if on2 then
            local vp = Camera.ViewportSize
            if mousemoverel then mousemoverel(p2.X - vp.X / 2, p2.Y - vp.Y / 2) end
        end
    else
        aimAt(part, 1)
    end
    clickMouse()
end, F.FireDelay)

loop("TriggerBot", function()
    if not F.TriggerBot then return end
    local m = getMurderer()
    if m and m.Character and Mouse.Target and Mouse.Target:IsDescendantOf(m.Character) then clickMouse() end
end, 0.05)

loop("KillAura", function()
    if not F.KillAura then return end
    local target = nearestPlayer(F.KillAuraRange)
    if not target then return end
    local part = targetPart(target)
    if part then aimAt(part, 1) end
    local weapon = equipWeapon()
    if weapon and weapon.Name == "Knife" then
        local me, t = hrpOf(LP), hrpOf(target)
        if me and t then
            me.CFrame = t.CFrame * CFrame.new(0, 0, 0.4)
            strike(weapon, t)
            return
        end
    end
    clickMouse()
end, 0.18)

loop("AutoEquip", function()
    if not F.AutoEquip then return end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return end
    local tool = bp:FindFirstChild("Gun") or bp:FindFirstChild("Knife")
    if tool then pcall(function() tool.Parent = LP.Character end) end
end, 0.5)

loop("AutoKnife", function()
    if not F.AutoKnife or getRole(LP) ~= "Murderer" then return end
    local target = nearestPlayer(400)
    if not target then return end
    local me, t = hrpOf(LP), hrpOf(target)
    if not me or not t then return end
    local weapon = equipWeapon()
    me.CFrame = t.CFrame * CFrame.new(0, 0, 0.4)
    RunService.Heartbeat:Wait()
    strike(weapon, t)
end, 0.3)

loop("AutoWin", function()
    if not F.AutoWin then return end
    local m = getMurderer()
    if not m then return end
    if getRole(LP) == "Murderer" then
        local target = nearestPlayer(1000)
        if target and hrpOf(target) then teleportTo(hrpOf(target).CFrame) end
    elseif hrpOf(m) then
        teleportTo(hrpOf(m).CFrame)
    end
end, 0.35)

loop("Strafe", function()
    if not F.AutoStrafe then return end
    local me, m = hrpOf(LP), getMurderer()
    if not me or not m or not hrpOf(m) then return end
    local dir = (me.Position - hrpOf(m).Position).Unit
    local side = Vector3.new(-dir.Z, 0, dir.X)
    me.CFrame = me.CFrame * CFrame.new(side.X * 0.9, 0, side.Z * 0.9)
end, 0.05)

loop("JumpDodge", function()
    if not F.JumpDodge then return end
    local me, m = hrpOf(LP), getMurderer()
    if not me or not m or not hrpOf(m) then return end
    if (hrpOf(m).Position - me.Position).Magnitude < F.DodgeRange then
        me.Velocity = Vector3.new(me.Velocity.X, F.JumpPower, me.Velocity.Z)
    end
end, 0.6)

loop("AntiFling", function()
    if not F.AntiFling then return end
    local me = hrpOf(LP)
    if me and me.Velocity.Magnitude > 250 then me.Velocity = me.Velocity.Unit * 200 end
end, 0.1)

loop("AutoFarm", function()
    if not F.AutoFarm or F.FarmPaused then return end
    local coins, me = getCoins(), hrpOf(LP)
    if #coins == 0 or not me then return end
    table.sort(coins, function(a, b)
        return (a.Position - me.Position).Magnitude < (b.Position - me.Position).Magnitude
    end)
    for i = 1, math.min(F.NearestOnly and 1 or 3, #coins) do
        teleportTo(coins[i].CFrame)
        task.wait(0.04)
    end
end, F.FarmDelay)

loop("AutoCollect", function()
    if not F.AutoCollect then return end
    local me = hrpOf(LP)
    if not me then return end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and (o.Name == "Coin" or o.Name == "Gun" or o.Name == "Knife") then
            if (o.Position - me.Position).Magnitude < F.CollectRange then
                firetouchinterest(me, o, 0); firetouchinterest(me, o, 1)
            end
        end
    end
end, 0.2)

loop("CoinMagnet", function()
    if not F.CoinMagnet then return end
    local me = hrpOf(LP)
    if not me then return end
    for _, c in ipairs(getCoins()) do
        if (c.Position - me.Position).Magnitude < 120 then
            c.CFrame = me.CFrame * CFrame.new(math.random(-4, 4), 0, math.random(-4, 4))
        end
    end
end, 0.15)

loop("CoinESP", function()
    if not (F.CoinESP or F.WeaponESP) or not Drawing then return end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") then
            local isCoin = o.Name == "Coin"
            local isWeapon = o.Name == "Gun" or o.Name == "Knife"
            if (isCoin and F.CoinESP) or (isWeapon and F.WeaponESP) then
                local p, on = Camera:WorldToViewportPoint(o.Position)
                if on then
                    local d = Drawing.new("Text")
                    d.Text = isCoin and "$" or (o.Name == "Gun" and "GUN" or "KNIFE")
                    d.Size = 15; d.Center = true; d.Outline = true
                    d.Color = isCoin and C.YELLOW or C.BLUE
                    d.Position = Vector2.new(p.X, p.Y)
                    task.delay(0.2, function() pcall(function() d:Remove() end) end)
                end
            end
        end
    end
end, 0.2)

loop("NoClip", function()
    if not F.NoClip or not LP.Character then return end
    for _, o in ipairs(LP.Character:GetDescendants()) do
        if o:IsA("BasePart") and o.CanCollide then o.CanCollide = false end
    end
end, 0.2)

loop("Hitbox", function()
    if not F.Hitbox then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local hrp = hrpOf(p)
            if hrp and hrp.Size ~= Vector3.new(F.HitboxSize, F.HitboxSize, F.HitboxSize) then
                hrp.Size = Vector3.new(F.HitboxSize, F.HitboxSize, F.HitboxSize)
            end
        end
    end
end, 0.5)

loop("GodMode", function()
    if not F.GodMode then return end
    local hum = humOf(LP)
    if hum then hum.MaxHealth = 10000; hum.Health = 10000 end
end, 0.2)

loop("AntiRagdoll", function()
    if not F.AntiRagdoll then return end
    local hum = humOf(LP)
    if hum and hum.PlatformStand then hum.PlatformStand = false end
end, 0.2)

loop("Glide", function()
    if not F.Glide then return end
    local me = hrpOf(LP)
    if me and me.Velocity.Y < -8 and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        me.Velocity = Vector3.new(me.Velocity.X, -8, me.Velocity.Z)
    end
end, 0.05)

loop("StickGround", function()
    if not F.StickGround then return end
    local me, hum = hrpOf(LP), humOf(LP)
    if not me or not hum then return end
    if hum:GetState() == Enum.HumanoidStateType.Running and math.abs(me.Velocity.Y) < 2 then
        me.Velocity = Vector3.new(me.Velocity.X, -8, me.Velocity.Z)
    end
end, 0.1)

loop("AutoParkour", function()
    if not F.AutoParkour then return end
    local me, hum = hrpOf(LP), humOf(LP)
    if not me or not hum then return end
    if hum:GetState() ~= Enum.HumanoidStateType.Running then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LP.Character}
    if Workspace:Raycast(me.Position, me.CFrame.LookVector * 4, params) then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end, 0.3)

loop("AntiAFK", function()
    if not F.AntiAFK then return end
    pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
end, 25)

loop("AntiKick", function()
    if not F.AntiKick then return end
    pcall(function() VirtualUser:CaptureController() end)
end, 10)

loop("AutoRejoin", function()
    if not F.AutoRejoin then return end
    if game.PlaceId ~= 142823291 then pcall(function() TeleportService:Teleport(142823291, LP) end) end
end, 3)

loop("Freeze", function()
    if not F.Freeze then return end
    local me = hrpOf(LP)
    if me and not me.Anchored then me.Anchored = true end
end, 0.2)

loop("AutoDodge", function()
    if not F.AutoDodge then return end
    local me, m = hrpOf(LP), getMurderer()
    if not me or not m or not hrpOf(m) then return end
    if (hrpOf(m).Position - me.Position).Magnitude < F.DodgeRange then
        me.CFrame = me.CFrame * CFrame.new(math.random(-45, 45), 8, math.random(-45, 45))
    end
end, 0.4)

loop("Rainbow", function()
    if not F.Rainbow then return end
    local ch = LP.Character
    if not ch then return end
    local col = Color3.fromHSV((tick() % 6) / 6, 1, 1)
    for _, o in ipairs(ch:GetDescendants()) do
        if o:IsA("BasePart") then o.Color = col end
    end
end, 0.1)

loop("Spin", function()
    if not F.Spin then return end
    local me = hrpOf(LP)
    if me then me.CFrame = me.CFrame * CFrame.Angles(0, math.rad(F.SpinSpeed), 0) end
end, 0.03)

loop("Aura", function()
    if not F.Aura then return end
    local me = hrpOf(LP)
    if not me then return end
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(1, 1, 1)
    p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.Neon
    p.Color = Color3.fromHSV((tick() % 4) / 4, 1, 1)
    p.Parent = Workspace
    p.CFrame = me.CFrame * CFrame.new(math.random(-3, 3), math.random(-1, 3), math.random(-3, 3))
    task.delay(1.2, function() pcall(function() p:Destroy() end) end)
end, 0.12)

loop("BigHead", function()
    if not F.BigHead then return end
    local h = LP.Character and LP.Character:FindFirstChild("Head")
    if h then h.Size = Vector3.new(4, 4, 4) end
end, 0.5)

loop("SmallChar", function()
    if not F.SmallChar then return end
    local hum = humOf(LP)
    if hum and hum.BodyHeightScale ~= 0.5 then
        for _, s in ipairs({"BodyHeightScale","BodyWidthScale","BodyDepthScale","HeadScale"}) do
            if hum[s] then hum[s].Value = 0.5 end
        end
    end
end, 0.5)

loop("InvisibleBody", function()
    if not F.InvisibleBody then return end
    local ch = LP.Character
    if not ch then return end
    for _, o in ipairs(ch:GetDescendants()) do
        if o:IsA("BasePart") and o.Name ~= "HumanoidRootPart" then o.LocalTransparencyModifier = 1 end
    end
end, 0.3)

--==================== FLY ====================
local function clearFlyMovers()
    if F.FlyBV then pcall(function() F.FlyBV:Destroy() end); F.FlyBV = nil end
    if F.FlyBG then pcall(function() F.FlyBG:Destroy() end); F.FlyBG = nil end
end

local function ensureFlyMovers()
    local hrp = hrpOf(LP)
    if not hrp then return end
    if F.FlyBV and F.FlyBV.Parent == hrp then return end
    clearFlyMovers()
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DuckFly"
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "DuckFlyGyro"
    bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bg.P = 3000; bg.D = 500
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    F.FlyBV, F.FlyBG = bv, bg
end

conn(RunService.RenderStepped, function()
    if Unloaded or not F.Fly then return end
    ensureFlyMovers()
    local hrp = hrpOf(LP)
    if not hrp or not F.FlyBV then return end
    if F.Freeze and hrp.Anchored then hrp.Anchored = false end

    local dir = Vector3.zero
    local cam = Camera.CFrame
    if F.FlyVertical then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = Vector3.new(0, -1, 0) end
    else
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
    end
    F.FlyBV.Velocity = dir * F.FlySpeed
    if F.FlyBG then F.FlyBG.CFrame = cam end
end)

--==================== SAUT INFINI ====================
local function doJump()
    local hum, hrp = humOf(LP), hrpOf(LP)
    if not hum or not hrp then return end
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    hrp.Velocity = Vector3.new(hrp.Velocity.X, F.JumpPower, hrp.Velocity.Z)
end

conn(UserInputService.InputBegan, function(i, processed)
    if processed or not F.InfJump then return end
    if i.KeyCode == Enum.KeyCode.Space then doJump() end
end)

loop("InfJumpHold", function()
    if not F.InfJump then return end
    if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
    local hum = humOf(LP)
    if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then doJump() end
end, 0.12)

--==================== TRAIL / LIGHTING ====================
local function setTrail(state)
    local ch = LP.Character
    if not ch then return end
    local old = ch:FindFirstChild("DuckTrail")
    if state then
        if old then return end
        local hrp = hrpOf(LP)
        if not hrp then return end
        local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1, 0); a0.Parent = hrp
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1, 0); a1.Parent = hrp
        local tr = Instance.new("Trail")
        tr.Name = "DuckTrail"; tr.Attachment0 = a0; tr.Attachment1 = a1
        tr.Color = ColorSequence.new(C.A1, C.A2); tr.Lifetime = 0.7; tr.Parent = hrp
    elseif old then old:Destroy() end
end

local function setFullBright(state)
    if state then
        F.LightBackup.Brightness = Lighting.Brightness
        F.LightBackup.ClockTime = Lighting.ClockTime
        F.LightBackup.FogEnd = Lighting.FogEnd
        Lighting.Brightness = 3; Lighting.ClockTime = 12; Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = F.LightBackup.Brightness or 2
        Lighting.ClockTime = F.LightBackup.ClockTime or 14
        Lighting.FogEnd = F.LightBackup.FogEnd or 1e5
        Lighting.GlobalShadows = true
    end
end

local function fxToggle(name, class, props, state)
    local old = Lighting:FindFirstChild(name)
    if state then
        if old then return end
        local inst = Instance.new(class)
        inst.Name = name
        for k, v in pairs(props or {}) do pcall(function() inst[k] = v end) end
        inst.Parent = Lighting
    elseif old then old:Destroy() end
end

--==================== INPUTS ====================
conn(UserInputService.JumpRequest, function()
    if not F.InfJump then return end
    doJump()
end)

conn(Mouse.Button1Down, function()
    if F.ClickTP then
        local me = hrpOf(LP)
        if me and Mouse.Hit then me.CFrame = Mouse.Hit + Vector3.new(0, 3, 0) end
    end
    if F.ClickFling and Mouse.Target then
        local ch = Mouse.Target:FindFirstAncestorOfClass("Model")
        if ch and Players:GetPlayerFromCharacter(ch) and ch ~= LP.Character then flingChar(ch) end
    end
end)

--==================== NOTIFICATIONS ====================
local notifGui = newGui("DuckHubNotifs")
local notifHolder = create("Frame", {
    Parent = notifGui, BackgroundTransparency = 1,
    Size = UDim2.new(0, 280, 0, 420), Position = UDim2.new(1, -300, 0, 20),
})
create("UIListLayout", {
    Parent = notifHolder, Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top,
})

notify = function(title, content, duration)
    if not F.Notifs then return end
    duration = duration or 5
    local box = create("Frame", {
        Parent = notifHolder, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.PANEL, BackgroundTransparency = 1,
    })
    corner(box, 10); stroke(box, C.STROKE, 1, 1); pad(box, 10, 10, 14, 12)
    local bar = create("Frame", {
        Parent = box, Size = UDim2.new(0, 3, 1, -14), Position = UDim2.new(0, 6, 0, 7),
        BackgroundColor3 = C.A1, BackgroundTransparency = 1,
    })
    corner(bar, 2); grad(bar, C.A1, C.A2, 90)
    local t = create("TextLabel", {
        Parent = box, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 16),
        Position = UDim2.new(0, 18, 0, 0), Font = FONTB, TextSize = 13,
        TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = title, TextTransparency = 1,
    })
    local c = create("TextLabel", {
        Parent = box, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 18, 0, 18),
        Font = FONT, TextSize = 12, TextColor3 = C.SUB,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = content, TextTransparency = 1,
    })
    tween(box, 0.2, { BackgroundTransparency = 0 })
    tween(bar, 0.2, { BackgroundTransparency = 0 })
    tween(t, 0.2, { TextTransparency = 0 })
    tween(c, 0.2, { TextTransparency = 0 })
    task.delay(duration, function()
        tween(box, 0.25, { BackgroundTransparency = 1 })
        tween(bar, 0.25, { BackgroundTransparency = 1 })
        tween(t, 0.25, { TextTransparency = 1 })
        tween(c, 0.25, { TextTransparency = 1 })
        task.wait(0.3); box:Destroy()
    end)
end

--==================== COMPOSANTS ====================
local function card(parent, h)
    local row = create("Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = C.CARD })
    corner(row, 8); stroke(row, C.STROKE, 1)
    return row
end

local function section(parent, text)
    local holder = create("Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
    local bar = create("Frame", {
        Parent = holder, Size = UDim2.new(0, 3, 0, 13), Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = C.A1,
    })
    corner(bar, 2); grad(bar, C.A1, C.A2, 90)
    create("TextLabel", {
        Parent = holder, BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.new(0, 12, 0, 0), Font = FONTB, TextSize = 11,
        TextColor3 = C.SUB, TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(text),
    })
end

local function toggle(parent, name, default, callback)
    local state = default and true or false
    local row = card(parent, 34)
    create("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 12, 0, 0), Font = FONT, TextSize = 13,
        TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = name,
    })
    local sw = create("Frame", {
        Parent = row, Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -46, 0.5, -9),
        BackgroundColor3 = state and C.A1 or C.INPUT,
    })
    corner(sw, 9); stroke(sw, C.STROKE, 1)
    if state then grad(sw, C.A1, C.A2) end
    local knob = create("Frame", {
        Parent = sw, Size = UDim2.new(0, 14, 0, 14),
        Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
    })
    corner(knob, 7)

    local function set(v)
        state = v
        local g = sw:FindFirstChildOfClass("UIGradient")
        if v and not g then grad(sw, C.A1, C.A2) elseif not v and g then g:Destroy() end
        tween(sw, 0.15, { BackgroundColor3 = v and C.A1 or C.INPUT })
        tween(knob, 0.15, { Position = v and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) })
        if callback then pcall(callback, v) end
    end

    local click = create("TextButton", { Parent = row, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" })
    conn(click.MouseButton1Click, function() set(not state) end)
    conn(click.MouseEnter, function() tween(row, 0.12, { BackgroundColor3 = C.CARD_HOV }) end)
    conn(click.MouseLeave, function() tween(row, 0.12, { BackgroundColor3 = C.CARD }) end)
    return set
end

local function slider(parent, name, min, max, default, suffix, callback)
    local value = default
    local row = card(parent, 50)
    create("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -90, 0, 20), Position = UDim2.new(0, 12, 0, 6),
        Font = FONT, TextSize = 13, TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = name,
    })
    local valLbl = create("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0, 70, 0, 20), Position = UDim2.new(1, -82, 0, 6),
        Font = FONTB, TextSize = 12, TextColor3 = C.A2, TextXAlignment = Enum.TextXAlignment.Right,
        Text = tostring(value) .. (suffix or ""),
    })
    local track = create("Frame", {
        Parent = row, Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 34), BackgroundColor3 = C.INPUT,
    })
    corner(track, 3); stroke(track, C.STROKE, 1)
    local fill = create("Frame", {
        Parent = track, Size = UDim2.new((value - min) / (max - min), 0, 1, 0), BackgroundColor3 = C.A1,
    })
    corner(fill, 3); grad(fill, C.A1, C.A2)

    local dragging = false
    local function apply(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor((min + (max - min) * rel) + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valLbl.Text = tostring(value) .. (suffix or "")
        if callback then pcall(callback, value) end
    end
    conn(track.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; apply(i.Position.X) end
    end)
    conn(UserInputService.InputChanged, function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then apply(i.Position.X) end
    end)
    conn(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

local function button(parent, name, cb, primary)
    local row = card(parent, 32)
    if primary then row.BackgroundColor3 = C.A1; grad(row, C.A1, C.A2) end
    local txt = create("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = FONTB,
        TextSize = 13, TextColor3 = C.TEXT, Text = name,
    })
    local click = create("TextButton", { Parent = row, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" })
    conn(click.MouseEnter, function()
        if primary then tween(row, 0.12, { BackgroundColor3 = C.A2 })
        else tween(row, 0.12, { BackgroundColor3 = C.CARD_HOV }); tween(txt, 0.12, { TextColor3 = C.A2 }) end
    end)
    conn(click.MouseLeave, function()
        if primary then tween(row, 0.12, { BackgroundColor3 = C.A1 })
        else tween(row, 0.12, { BackgroundColor3 = C.CARD }); tween(txt, 0.12, { TextColor3 = C.TEXT }) end
    end)
    conn(click.MouseButton1Click, function() if cb then pcall(cb) end end)
end

local function keybind(parent, name, defaultKey, cb)
    local row = card(parent, 34)
    create("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        Font = FONT, TextSize = 13, TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = name,
    })
    local btn = create("TextButton", {
        Parent = row, Size = UDim2.new(0, 62, 0, 22), Position = UDim2.new(1, -72, 0.5, -11),
        BackgroundColor3 = C.INPUT, Font = FONTB, TextSize = 11, TextColor3 = C.A2, Text = defaultKey,
    })
    corner(btn, 6); stroke(btn, C.STROKE, 1)
    local listening = false
    conn(btn.MouseButton1Click, function() listening = true; btn.Text = "..."; btn.TextColor3 = C.SUB end)
    conn(UserInputService.InputBegan, function(i)
        if not listening or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        listening = false; btn.Text = i.KeyCode.Name; btn.TextColor3 = C.A2
        if cb then pcall(cb, i.KeyCode) end
    end)
end

local function label(parent, text, color)
    return create("TextLabel", {
        Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        Font = FONT, TextSize = 12, TextColor3 = color or C.SUB,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text,
    })
end

--==================== HUD ====================
local hudGui = newGui("DuckHubHUD")
local wm = create("Frame", {
    Parent = hudGui, Size = UDim2.new(0, 220, 0, 26), Position = UDim2.new(0, 16, 1, -42),
    BackgroundColor3 = C.PANEL, Visible = false,
})
corner(wm, 7); stroke(wm, C.STROKE, 1)
local wmText = create("TextLabel", {
    Parent = wm, BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 10, 0, 0),
    Font = FONTB, TextSize = 11, TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Duck Hub v" .. HUB_VERSION,
})
grad(wmText, C.A1, C.A2, 0)

local hudBox = create("Frame", {
    Parent = hudGui, Size = UDim2.new(0, 180, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    Position = UDim2.new(0, 16, 0, 16), BackgroundColor3 = C.PANEL, BackgroundTransparency = 0.15,
})
corner(hudBox, 8); stroke(hudBox, C.STROKE, 1); pad(hudBox, 8, 8, 10, 10)
create("UIListLayout", { Parent = hudBox, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

local function hudLine()
    return create("TextLabel", {
        Parent = hudBox, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
        Font = FONT, TextSize = 11, TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    })
end

local fpsLbl, pingLbl, clockLbl = hudLine(), hudLine(), hudLine()
local playerHud = create("Frame", { Parent = hudBox, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
create("UIListLayout", { Parent = playerHud, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

task.spawn(function()
    local frames, last = 0, tick()
    while not Unloaded do
        frames += 1
        if tick() - last >= 1 then F.HUD.fps = frames; frames = 0; last = tick() end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while not Unloaded do
        pcall(function()
            wm.Visible = F.Watermark
            wm.Position = UDim2.new(0, 16, 1, F.WMpos == 1 and -42 or -70)
            wmText.Text = string.format("Duck Hub v%s | %d fps", HUB_VERSION, F.HUD.fps or 0)

            hudBox.Visible = F.FPSMeter or F.PingMeter or F.Clock or F.PlayerListHUD
            fpsLbl.Visible = F.FPSMeter
            fpsLbl.Text = "FPS : " .. (F.HUD.fps or 0)
            pingLbl.Visible = F.PingMeter
            local ping = 0
            pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
            pingLbl.Text = "Ping : " .. ping .. " ms"
            clockLbl.Visible = F.Clock
            clockLbl.Text = "Heure : " .. os.date("%H:%M:%S")

            playerHud.Visible = F.PlayerListHUD
            if F.PlayerListHUD then
                for _, c in ipairs(playerHud:GetChildren()) do
                    if c:IsA("TextLabel") then c:Destroy() end
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and alive(p) then
                        create("TextLabel", {
                            Parent = playerHud, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 13),
                            Font = FONT, TextSize = 10, TextColor3 = roleColor(getRole(p)),
                            TextXAlignment = Enum.TextXAlignment.Left, Text = "• " .. p.Name,
                        })
                    end
                end
            end
        end)
        task.wait(1)
    end
end)

local drawGui = newGui("DuckHubDraw")
local fovCircle, crossX, crossY, hitLines
if Drawing then
    fovCircle = Drawing.new("Circle"); fovCircle.Thickness = 1; fovCircle.Filled = false; fovCircle.Visible = false
    crossX = Drawing.new("Line"); crossY = Drawing.new("Line")
    hitLines = {}
    for i = 1, 4 do local l = Drawing.new("Line"); l.Thickness = 1; l.Visible = false; hitLines[i] = l end
end

conn(RunService.RenderStepped, function()
    if not Drawing then return end
    local vp = Camera.ViewportSize
    if fovCircle then
        fovCircle.Visible = F.FOVCircle
        fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        fovCircle.Radius = F.AimbotFOV
        fovCircle.Color = C.A2
    end
    if crossX then
        crossX.Visible = F.Crosshair; crossY.Visible = F.Crosshair
        crossX.From = Vector2.new(vp.X / 2 - 7, vp.Y / 2); crossX.To = Vector2.new(vp.X / 2 + 7, vp.Y / 2)
        crossY.From = Vector2.new(vp.X / 2, vp.Y / 2 - 7); crossY.To = Vector2.new(vp.X / 2, vp.Y / 2 + 7)
        crossX.Color = C.TEXT; crossY.Color = C.TEXT
    end
end)

conn(Mouse.Button1Down, function()
    if not F.Hitmarker or not hitLines then return end
    local vp = Camera.ViewportSize
    local cx, cy, off = vp.X / 2, vp.Y / 2, 6
    local pts = {
        {cx - off, cy - off, cx - off - 5, cy - off - 5},
        {cx + off, cy - off, cx + off + 5, cy - off - 5},
        {cx - off, cy + off, cx - off - 5, cy + off + 5},
        {cx + off, cy + off, cx + off + 5, cy + off + 5},
    }
    for i, l in ipairs(hitLines) do
        l.Visible = true; l.Color = C.TEXT
        l.From = Vector2.new(pts[i][1], pts[i][2])
        l.To = Vector2.new(pts[i][3], pts[i][4])
    end
    task.delay(0.15, function() for _, l in ipairs(hitLines) do l.Visible = false end end)
end)

--==================== CONFIG ====================
local function saveConfig()
    if not writefile then return notify("Duck Hub", "Filesystem indisponible.", 4) end
    local data = {}
    for k, v in pairs(F) do
        if type(v) == "boolean" or type(v) == "number" then data[k] = v end
    end
    pcall(writefile, CONFIG_FILE, HttpService:JSONEncode(data))
    notify("Duck Hub", "Configuration sauvegardée.", 4)
end

local function loadConfig()
    if not (isfile and readfile and isfile(CONFIG_FILE)) then return notify("Duck Hub", "Aucune config.", 4) end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if not ok then return notify("Duck Hub", "Config illisible.", 4) end
    for k, v in pairs(data) do
        if F[k] ~= nil and type(F[k]) == type(v) then F[k] = v end
    end
    notify("Duck Hub", "Config chargée (les toggles s'appliquent au prochain clic).", 5)
end

--==================== UI PRINCIPALE ====================
local function buildHub()
    local gui = newGui("DuckHub")

    local glowFrame = create("Frame", {
        Parent = gui, Size = UDim2.new(0, 680, 0, 490), Position = UDim2.new(0.5, -340, 0.5, -245),
        BackgroundColor3 = C.A1, BackgroundTransparency = 0.85,
    })
    corner(glowFrame, 16)

    local main = create("Frame", {
        Parent = gui, Size = UDim2.new(0, 680, 0, 490), Position = UDim2.new(0.5, -340, 0.5, -245),
        BackgroundColor3 = C.BG, ClipsDescendants = true,
    })
    corner(main, 14); stroke(main, C.STROKE, 1)
    local scale = create("UIScale", { Parent = main, Scale = F.UIScale })

    local bar = create("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.PANEL })
    local topLine = create("Frame", {
        Parent = bar, Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = C.A1,
    })
    grad(topLine, C.A1, C.A2, 0)

    local logo = create("Frame", {
        Parent = bar, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 16, 0.5, -14), BackgroundColor3 = C.A1,
    })
    corner(logo, 9); grad(logo, C.A1, C.A2, 45)
    create("TextLabel", {
        Parent = logo, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = FONTB, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Text = "D",
    })
    local titleLbl = create("TextLabel", {
        Parent = bar, BackgroundTransparency = 1, Size = UDim2.new(0, 200, 0, 18),
        Position = UDim2.new(0, 52, 0, 9), Font = FONTB, TextSize = 15,
        TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "DUCK HUB",
    })
    grad(titleLbl, C.TEXT, C.A2, 0)
    create("TextLabel", {
        Parent = bar, BackgroundTransparency = 1, Size = UDim2.new(0, 220, 0, 14),
        Position = UDim2.new(0, 52, 0, 26), Font = FONT, TextSize = 10,
        TextColor3 = C.SUB, TextXAlignment = Enum.TextXAlignment.Left, Text = "v" .. HUB_VERSION .. "  •  Murder Mystery 2",
    })

    local function topBtn(x, txt, cb, hoverColor)
        local b = create("TextButton", {
            Parent = bar, Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, x, 0.5, -13),
            BackgroundColor3 = C.CARD, Font = FONTB, TextSize = 13, TextColor3 = C.SUB, Text = txt,
        })
        corner(b, 7); stroke(b, C.STROKE, 1)
        conn(b.MouseEnter, function() tween(b, 0.1, { BackgroundColor3 = hoverColor or C.CARD_HOV, TextColor3 = C.TEXT }) end)
        conn(b.MouseLeave, function() tween(b, 0.1, { BackgroundColor3 = C.CARD, TextColor3 = C.SUB }) end)
        conn(b.MouseButton1Click, cb)
    end

    local minimized = false
    topBtn(-40, "—", function()
        minimized = not minimized
        local s = minimized and UDim2.new(0, 680, 0, 52) or UDim2.new(0, 680, 0, 490)
        tween(main, 0.2, { Size = s }); tween(glowFrame, 0.2, { Size = s })
    end)
    topBtn(-72, "×", function()
        Unloaded = true
        clearESP(); setGlow(false); clearFlyMovers()
        for k in pairs(F.LoopTokens) do F.LoopTokens[k] = false end
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        setFullBright(false)
        pcall(function() gui:Destroy(); glowFrame:Destroy() end)
        pcall(function() notifGui:Destroy(); hudGui:Destroy(); drawGui:Destroy() end)
    end, C.RED)

    local dragging, dragStart, startPos = false, nil, nil
    conn(bar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = main.Position
        end
    end)
    conn(UserInputService.InputChanged, function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            local np = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            main.Position = np; glowFrame.Position = np
        end
    end)
    conn(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    local side = create("Frame", {
        Parent = main, Size = UDim2.new(0, 168, 1, -52), Position = UDim2.new(0, 0, 0, 52), BackgroundColor3 = C.PANEL,
    })
    create("Frame", {
        Parent = side, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = C.STROKE,
    })

    local profile = create("Frame", {
        Parent = side, Size = UDim2.new(1, -20, 0, 56), Position = UDim2.new(0, 10, 0, 10), BackgroundColor3 = C.CARD,
    })
    corner(profile, 10); stroke(profile, C.STROKE, 1)
    create("ImageLabel", {
        Parent = profile, Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 10, 0.5, -18),
        BackgroundColor3 = C.INPUT, Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=48&h=48",
    })
    local profName = create("TextLabel", {
        Parent = profile, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 15), Position = UDim2.new(0, 54, 0, 11),
        Font = FONTB, TextSize = 12, TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = LP.DisplayName,
    })
    local profRole = create("TextLabel", {
        Parent = profile, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 54, 0, 27),
        Font = FONT, TextSize = 11, TextColor3 = C.GREEN, TextXAlignment = Enum.TextXAlignment.Left, Text = "Innocent",
    })
    task.spawn(function()
        while not Unloaded do
            pcall(function()
                local r = getRole(LP)
                profRole.Text = r; profRole.TextColor3 = roleColor(r)
                profName.Text = LP.DisplayName
            end)
            task.wait(1)
        end
    end)

    local sideList = create("Frame", {
        Parent = side, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -76), Position = UDim2.new(0, 0, 0, 76),
    })
    create("UIListLayout", { Parent = sideList, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
    pad(sideList, 4, 4, 10, 10)

    local content = create("Frame", {
        Parent = main, Size = UDim2.new(1, -168, 1, -52), Position = UDim2.new(0, 168, 0, 52), BackgroundColor3 = C.BG,
    })

    local function createTab(name)
        local btn = create("TextButton", {
            Parent = sideList, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.PANEL,
            BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = C.SUB,
            TextXAlignment = Enum.TextXAlignment.Left, Text = "  " .. name,
        })
        corner(btn, 8)
        local ind = create("Frame", {
            Parent = btn, Size = UDim2.new(0, 3, 0, 15), Position = UDim2.new(0, 0, 0.5, -7.5),
            BackgroundColor3 = C.A1, Visible = false,
        })
        corner(ind, 2); grad(ind, C.A1, C.A2, 90)

        local page = create("ScrollingFrame", {
            Parent = content, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.STROKE,
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
        })
        create("UIListLayout", { Parent = page, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
        pad(page, 10, 14, 12, 12)

        table.insert(UI.tabs, { btn = btn, page = page, name = name, ind = ind })

        conn(btn.MouseEnter, function()
            if UI.current ~= name then tween(btn, 0.12, { TextColor3 = C.TEXT, BackgroundTransparency = 0.6, BackgroundColor3 = C.CARD }) end
        end)
        conn(btn.MouseLeave, function()
            if UI.current ~= name then tween(btn, 0.12, { TextColor3 = C.SUB, BackgroundTransparency = 1 }) end
        end)
        conn(btn.MouseButton1Click, function()
            UI.current = name
            for _, t in ipairs(UI.tabs) do
                local a = t.name == name
                t.page.Visible = a; t.ind.Visible = a
                tween(t.btn, 0.12, {
                    BackgroundTransparency = a and 0 or 1,
                    BackgroundColor3 = a and C.CARD or C.PANEL,
                    TextColor3 = a and C.TEXT or C.SUB,
                })
            end
        end)
        return page
    end

    -- COMBAT
    local pC = createTab("Combat")
    section(pC, "Auto Shoot Murderer")
    toggle(pC, "Auto Shoot Murderer", false, function(v) F.AutoShoot = v end)
    slider(pC, "Portée de tir", 20, 600, 250, "m", function(v) F.ShootRange = v end)
    toggle(pC, "Vérifier la ligne de vue", true, function(v) F.ShootLOS = v end)
    slider(pC, "Délai de tir", 0.03, 0.5, 0.1, "s", function(v) F.FireDelay = v end)
    slider(pC, "Prédiction", 0, 0.4, 0, "s", function(v) F.LeadTime = v end)
    section(pC, "Viseur")
    toggle(pC, "Aimbot (maintenir)", false, function(v) F.Aimbot = v end)
    keybind(pC, "Touche aimbot", "E", function(k) F.AimbotKey = k end)
    toggle(pC, "Priorité tête", true, function(v) F.HeadPriority = v end)
    slider(pC, "Fluidité", 0.05, 1, 0.25, "", function(v) F.AimbotSmooth = v end)
    slider(pC, "FOV", 50, 700, 150, "px", function(v) F.AimbotFOV = v end)
    toggle(pC, "Silent Aim", false, function(v) F.SilentAim = v end)
    section(pC, "Corps à corps")
    toggle(pC, "Kill Aura", false, function(v) F.KillAura = v end)
    slider(pC, "Rayon kill aura", 4, 30, 10, "m", function(v) F.KillAuraRange = v end)
    toggle(pC, "Auto Couteau", false, function(v) F.AutoKnife = v end)
    toggle(pC, "Auto équiper arme", false, function(v) F.AutoEquip = v end)
    toggle(pC, "Trigger Bot", false, function(v) F.TriggerBot = v end)
    toggle(pC, "Auto Win", false, function(v) F.AutoWin = v end)
    section(pC, "Fling")
    button(pC, "Fling le Murderer", flingMurderer)
    button(pC, "Fling tout le monde", flingAll)
    button(pC, "Mode : Impact (fiable)", function()
        F.FlingMode = "impact"
        notify("Duck Hub", "Mode impact : tu percuteras la cible.", 3)
    end)
    button(pC, "Mode : Weld (violent)", function()
        F.FlingMode = "weld"
        notify("Duck Hub", "Mode weld : soudure + rotation.", 3)
    end)
    button(pC, "Mode : Spin (visuel)", function()
        F.FlingMode = "spin"
        notify("Duck Hub", "Mode spin : rotation locale seulement.", 3)
    end)
    toggle(pC, "Fling au clic", false, function(v) F.ClickFling = v end)
    slider(pC, "Force de fling", 400, 4000, 1600, "", function(v) F.FlingForce = v end)
    section(pC, "Dégâts")
    toggle(pC, "Hitbox Expander", false, function(v)
        F.Hitbox = v
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                local hrp = hrpOf(p)
                if hrp then hrp.Size = Vector3.new(2, 2, 1) end
            end
        end
    end)
    slider(pC, "Taille hitbox", 3, 20, 8, "", function(v) F.HitboxSize = v end)
    toggle(pC, "God Mode", false, function(v) F.GodMode = v end)
    toggle(pC, "Anti-fling", false, function(v) F.AntiFling = v end)
    button(pC, "Kill All", function()
        if getRole(LP) ~= "Murderer" then
            notify("Duck Hub", "Kill All est efficace en Murderer.", 4)
        end
        task.spawn(killAll)
    end, true)
    slider(pC, "Délai Kill All", 0.1, 0.8, 0.22, "s", function(v) F.KillAllDelay = v end)
    button(pC, "Soigner", function()
        local hum = humOf(LP)
        if hum then hum.Health = hum.MaxHealth end
    end)

    -- FARM
    local pF = createTab("Farm")
    section(pF, "Pièces")
    toggle(pF, "Auto Farm Coins", false, function(v) F.AutoFarm = v end)
    toggle(pF, "Pause farm", false, function(v) F.FarmPaused = v end)
    toggle(pF, "Pièce la plus proche uniquement", false, function(v) F.NearestOnly = v end)
    toggle(pF, "Auto Collect", false, function(v) F.AutoCollect = v end)
    slider(pF, "Rayon de collecte", 4, 40, 8, "m", function(v) F.CollectRange = v end)
    toggle(pF, "Coin Magnet", false, function(v) F.CoinMagnet = v end)
    toggle(pF, "Coin ESP", false, function(v) F.CoinESP = v end)
    slider(pF, "Délai de farm", 0.1, 2, 0.4, "s", function(v) F.FarmDelay = v end)
    section(pF, "Actions")
    button(pF, "Téléport toutes les pièces", function()
        task.spawn(function()
            for _, c in ipairs(getCoins()) do teleportTo(c.CFrame); task.wait(0.05) end
        end)
    end)
    button(pF, "Attirer toutes les pièces", function()
        local me = hrpOf(LP)
        if not me then return end
        for _, c in ipairs(getCoins()) do
            c.CFrame = me.CFrame * CFrame.new(math.random(-5, 5), 0, math.random(-5, 5))
        end
        notify("Duck Hub", "Pièces attirées.", 3)
    end)

    -- MOUVEMENT
    local pM = createTab("Mouvement")
    section(pM, "Vol")
    toggle(pM, "Fly", false, function(v) F.Fly = v; if v then ensureFlyMovers() else clearFlyMovers() end end)
    toggle(pM, "Vol vertical uniquement", false, function(v) F.FlyVertical = v end)
    slider(pM, "Vitesse de vol", 10, 200, 55, "", function(v) F.FlySpeed = v end)
    toggle(pM, "Noclip", false, function(v)
        F.NoClip = v
        if not v and LP.Character then
            for _, o in ipairs(LP.Character:GetDescendants()) do
                if o:IsA("BasePart") then o.CanCollide = true end
            end
        end
    end)
    toggle(pM, "Freeze", false, function(v)
        F.Freeze = v
        local me = hrpOf(LP)
        if me and not v then me.Anchored = false end
    end)
    toggle(pM, "Glide", false, function(v) F.Glide = v end)
    section(pM, "Vitesse")
    slider(pM, "WalkSpeed", 16, 300, 16, "", function(v)
        F.WalkSpeed = v
        local h = humOf(LP)
        if h then h.WalkSpeed = v end
    end)
    slider(pM, "JumpPower", 50, 300, 50, "", function(v)
        F.JumpPower = v
        local h = humOf(LP)
        if h then h.JumpPower = v; h.UseJumpPower = true end
    end)
    toggle(pM, "Saut infini", false, function(v) F.InfJump = v end)
    toggle(pM, "Auto Parkour", false, function(v) F.AutoParkour = v end)
    toggle(pM, "Coller au sol", false, function(v) F.StickGround = v end)
    toggle(pM, "Anti ragdoll", false, function(v) F.AntiRagdoll = v end)

    -- TÉLÉPORTATION
    local pT = createTab("Téléportation")
    section(pT, "Cibles rapides")
    button(pT, "Vers le Murderer", function()
        local m = getMurderer()
        if not (m and tpPlayer(m)) then notify("Duck Hub", "Aucun murderer.", 3) end
    end)
    button(pT, "Vers le Sheriff", function()
        local s = getSheriff()
        if not (s and tpPlayer(s)) then notify("Duck Hub", "Aucun sheriff.", 3) end
    end)
    button(pT, "Vers une pièce", function()
        local c = getCoins()
        if c[1] then teleportTo(c[1].CFrame) else notify("Duck Hub", "Aucune pièce.", 3) end
    end)
    button(pT, "Vers le spawn", function()
        local sp = Workspace:FindFirstChild("SpawnLocation")
        if sp then teleportTo(sp.CFrame) end
    end)
    button(pT, "Position aléatoire", function()
        local me = hrpOf(LP)
        if me then me.CFrame = me.CFrame * CFrame.new(math.random(-70, 70), 6, math.random(-70, 70)) end
    end)
    button(pT, "S'éloigner du murderer", function()
        local me, m = hrpOf(LP), getMurderer()
        if not me or not m or not hrpOf(m) then return end
        local dir = (me.Position - hrpOf(m).Position).Unit
        me.CFrame = CFrame.new(me.Position + dir * 60 + Vector3.new(0, 6, 0))
    end)
    button(pT, "Derrière le murderer", function()
        local m = getMurderer()
        if m and hrpOf(m) then teleportTo(hrpOf(m).CFrame * CFrame.new(0, 0, 4)) end
    end)
    button(pT, "Au-dessus du murderer", function()
        local m = getMurderer()
        if m and hrpOf(m) then teleportTo(hrpOf(m).CFrame * CFrame.new(0, 12, 0)) end
    end)
    button(pT, "Au centre de la map", function()
        local me = hrpOf(LP)
        if me then me.CFrame = CFrame.new(0, 60, 0) end
    end)
    button(pT, "500 studs en l'air", function()
        local me = hrpOf(LP)
        if me then me.CFrame = me.CFrame + Vector3.new(0, 500, 0) end
    end)
    section(pT, "Sur un joueur")
    local listBox = create("Frame", { Parent = pT, Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.CARD })
    corner(listBox, 8); stroke(listBox, C.STROKE, 1)
    local listScroll = create("ScrollingFrame", {
        Parent = listBox, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.STROKE, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    create("UIListLayout", { Parent = listScroll, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

    local function refreshList()
        for _, c in ipairs(listScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        local count = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and alive(p) then
                count += 1
                local r = getRole(p)
                local b = create("TextButton", { Parent = listScroll, Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.INPUT, Text = "" })
                corner(b, 6); stroke(b, C.STROKE, 1)
                create("TextLabel", {
                    Parent = b, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0), Font = FONT, TextSize = 12,
                    TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left,
                    Text = p.Name .. "  •  " .. r,
                })
                create("Frame", {
                    Parent = b, Size = UDim2.new(0, 3, 0, 14), Position = UDim2.new(1, -10, 0.5, -7),
                    BackgroundColor3 = roleColor(r),
                })
                conn(b.MouseEnter, function() tween(b, 0.1, { BackgroundColor3 = C.CARD_HOV }) end)
                conn(b.MouseLeave, function() tween(b, 0.1, { BackgroundColor3 = C.INPUT }) end)
                conn(b.MouseButton1Click, function()
                    if tpPlayer(p) then notify("Duck Hub", "TP vers " .. p.Name, 2) end
                end)
            end
        end
        if count == 0 then
            create("TextLabel", {
                Parent = listScroll, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
                Font = FONT, TextSize = 11, TextColor3 = C.SUB, TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  Aucun joueur vivant.",
            })
        end
    end
    refreshList()
    task.spawn(function() while not Unloaded do refreshList(); task.wait(2) end end)

    section(pT, "Autres")
    button(pT, "TP tout le monde vers moi", function()
        local me = hrpOf(LP)
        if not me then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and alive(p) and hrpOf(p) then
                hrpOf(p).CFrame = me.CFrame + Vector3.new(math.random(-6, 6), 3, math.random(-6, 6))
            end
        end
    end)
    button(pT, "Amener le murderer", function()
        local m, me = getMurderer(), hrpOf(LP)
        if m and me and hrpOf(m) then hrpOf(m).CFrame = me.CFrame + Vector3.new(0, 3, 4) end
    end)
    button(pT, "Amener les pièces", function()
        local me = hrpOf(LP)
        if not me then return end
        for _, c in ipairs(getCoins()) do c.CFrame = me.CFrame * CFrame.new(math.random(-5, 5), 0, math.random(-5, 5)) end
    end)
    toggle(pT, "Click TP", false, function(v) F.ClickTP = v end)
    toggle(pT, "Auto Dodge", false, function(v) F.AutoDodge = v end)
    slider(pT, "Distance d'esquive", 10, 80, 25, "m", function(v) F.DodgeRange = v end)
    section(pT, "Positions")
    button(pT, "Sauvegarder ma position", function()
        local me = hrpOf(LP)
        if me then F.SavedPos = me.CFrame; notify("Duck Hub", "Position sauvegardée.", 3) end
    end)
    button(pT, "Charger ma position", function()
        if F.SavedPos then teleportTo(F.SavedPos) else notify("Duck Hub", "Aucune position.", 3) end
    end)

    -- ESP
    local pE = createTab("ESP")
    section(pE, "Général")
    toggle(pE, "ESP", false, function(v)
        F.ESP = v
        if v then for _, p in ipairs(Players:GetPlayers()) do createESP(p) end else clearESP() end
    end)
    slider(pE, "Distance max", 50, 2000, 500, "m", function(v) F.ESPMaxDist = v end)
    slider(pE, "Opacité", 0.3, 1, 1, "", function(v) F.ESPTransparency = v end)
    section(pE, "Éléments")
    toggle(pE, "Boîtes", true, function(v) F.Boxes = v end)
    toggle(pE, "Coins", false, function(v) F.CornerStyle = v end)
    slider(pE, "Épaisseur", 1, 4, 1, "px", function(v) F.BoxThick = v end)
    toggle(pE, "Barre de vie", false, function(v) F.HealthBar = v end)
    toggle(pE, "Noms", true, function(v) F.Names = v end)
    toggle(pE, "Rôles", true, function(v) F.Roles = v end)
    toggle(pE, "Distance", true, function(v) F.Distance = v end)
    toggle(pE, "Tracers", false, function(v) F.Tracers = v end)
    toggle(pE, "Glow (Highlight)", false, setGlow)
    toggle(pE, "Armes ESP", false, function(v) F.WeaponESP = v end)
    section(pE, "Rôles")
    button(pE, "Forcer un re-scan des rôles", function()
        RoleCache = {}
        refreshRoles()
        notify("Duck Hub", "Rôles rescannés.", 4)
    end)

    -- VISUELS
    local pV = createTab("Visuels")
    section(pV, "Ambiance")
    toggle(pV, "Full Bright", false, setFullBright)
    toggle(pV, "No Fog", false, function(v)
        if v then Lighting.FogEnd = 1e6 else Lighting.FogEnd = F.LightBackup.FogEnd or 1e5 end
    end)
    toggle(pV, "Vignette", false, function(v)
        F.Vignette = v
        local old = gui:FindFirstChild("DuckVignette")
        if v then
            if old then return end
            local f = create("Frame", { Parent = gui, Name = "DuckVignette", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 1 })
            local g = create("UIGradient", { Parent = f, Rotation = 90 })
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.5, 1),
                NumberSequenceKeypoint.new(1, 0.35),
            })
        elseif old then old:Destroy() end
    end)
    toggle(pV, "Color Correction", false, function(v)
        F.ColorCorrection = v
        fxToggle("DuckCC", "ColorCorrectionEffect", { Brightness = 0.05, Contrast = 0.15, Saturation = 0.25 }, v)
    end)
    toggle(pV, "Bloom", false, function(v)
        F.Bloom = v
        fxToggle("DuckBloom", "BloomEffect", { Intensity = 0.6, Size = 24, Threshold = 0.9 }, v)
    end)
    toggle(pV, "Sun Rays", false, function(v)
        F.SunRays = v
        fxToggle("DuckRays", "SunRaysEffect", { Intensity = 0.15, Spread = 0.6 }, v)
    end)
    toggle(pV, "Ciel personnalisé", false, function(v)
        F.CustomSky = v
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if v then
            if sky then sky:Destroy() end
            local s = Instance.new("Sky")
            s.SkyboxBk = "rbxassetid://159454299"; s.SkyboxDn = "rbxassetid://159454296"
            s.SkyboxFt = "rbxassetid://159454293"; s.SkyboxLf = "rbxassetid://159454286"
            s.SkyboxRt = "rbxassetid://159454300"; s.SkyboxUp = "rbxassetid://159454288"
            s.Name = "DuckSky"; s.Parent = Lighting
        elseif sky and sky.Name == "DuckSky" then
            sky:Destroy()
        end
    end)
    slider(pV, "FOV caméra", 40, 120, 70, "", function(v) Camera.FieldOfView = v end)
    toggle(pV, "Zoom max", false, function(v)
        F.MaxZoom = v
        LP.CameraMaxZoomDistance = v and 400 or 128
    end)
    section(pV, "Réticule")
    toggle(pV, "Cercle FOV", false, function(v) F.FOVCircle = v end)
    toggle(pV, "Crosshair", false, function(v) F.Crosshair = v end)
    toggle(pV, "Hitmarker", false, function(v) F.Hitmarker = v end)
    section(pV, "HUD")
    toggle(pV, "Watermark", false, function(v) F.Watermark = v end)
    toggle(pV, "Watermark en haut", false, function(v) F.WMpos = v and 2 or 1 end)
    toggle(pV, "Compteur FPS", false, function(v) F.FPSMeter = v end)
    toggle(pV, "Compteur ping", false, function(v) F.PingMeter = v end)
    toggle(pV, "Horloge", false, function(v) F.Clock = v end)
    toggle(pV, "Liste des joueurs à l'écran", false, function(v) F.PlayerListHUD = v end)

    -- FUN
    local pFu = createTab("Fun")
    section(pFu, "Apparence")
    toggle(pFu, "Arc-en-ciel", false, function(v) F.Rainbow = v end)
    toggle(pFu, "Aura de particules", false, function(v) F.Aura = v end)
    toggle(pFu, "Tourner sur soi", false, function(v) F.Spin = v end)
    slider(pFu, "Vitesse de rotation", 1, 60, 12, "", function(v) F.SpinSpeed = v end)
    toggle(pFu, "Traînée", false, setTrail)
    toggle(pFu, "Grosse tête", false, function(v)
        F.BigHead = v
        local h = LP.Character and LP.Character:FindFirstChild("Head")
        if h and not v then h.Size = Vector3.new(2, 1, 1) end
    end)
    toggle(pFu, "Petit personnage", false, function(v)
        F.SmallChar = v
        local hum = humOf(LP)
        if hum and not v then
            for _, s in ipairs({"BodyHeightScale","BodyWidthScale","BodyDepthScale","HeadScale"}) do
                if hum[s] then hum[s].Value = 1 end
            end
        end
    end)
    toggle(pFu, "Corps invisible", false, function(v)
        F.InvisibleBody = v
        if not v and LP.Character then
            for _, o in ipairs(LP.Character:GetDescendants()) do
                if o:IsA("BasePart") then o.LocalTransparencyModifier = 0 end
            end
        end
    end)
    section(pFu, "Actions")
    button(pFu, "Sauter haut", function()
        local me = hrpOf(LP)
        if me then me.Velocity = Vector3.new(me.Velocity.X, 250, me.Velocity.Z) end
    end)
    button(pFu, "Random TP", function()
        local me = hrpOf(LP)
        if me then me.CFrame = me.CFrame * CFrame.new(math.random(-120, 120), 20, math.random(-120, 120)) end
    end)
    button(pFu, "Flip caméra", function()
        Camera.CFrame = Camera.CFrame * CFrame.Angles(0, math.rad(180), 0)
    end)
    button(pFu, "Reset personnage", function()
        local h = humOf(LP)
        if h then h.Health = 0 end
    end)

    -- SERVEUR
    local pS = createTab("Serveur")
    section(pS, "Navigation")
    button(pS, "Rejoindre ce serveur", function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end)
    button(pS, "Serveur aléatoire", function()
        pcall(function()
            local data = HttpService:JSONDecode(
                game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=" .. F.ServerScan)
            )
            for _, s in ipairs(data.data or {}) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP); return
                end
            end
            notify("Duck Hub", "Aucun serveur libre.", 4)
        end)
    end)
    slider(pS, "Serveurs à scanner", 10, 100, 100, "", function(v) F.ServerScan = v end)
    button(pS, "Copier le JobId", function()
        if setclipboard then pcall(setclipboard, game.JobId) end
        notify("Duck Hub", "JobId copié.", 4)
    end)
    toggle(pS, "Auto Rejoin", false, function(v) F.AutoRejoin = v end)
    section(pS, "Client")
    toggle(pS, "Anti-AFK", false, function(v) F.AntiAFK = v end)
    toggle(pS, "Anti-Kick", false, function(v) F.AntiKick = v end)
    toggle(pS, "Unlock FPS", false, function(v)
        F.UnlockFPS = v
        if setfpscap then pcall(setfpscap, v and F.FPSCap or 60) end
    end)
    slider(pS, "Limite FPS", 30, 360, 240, "", function(v)
        F.FPSCap = v
        if F.UnlockFPS and setfpscap then pcall(setfpscap, v) end
    end)
    keybind(pS, "Touche cacher l'UI", "RightShift", function(k) F.HideKey = k end)

    -- INTERFACE
    local pI = createTab("Interface")
    section(pI, "Échelle & opacité")
    slider(pI, "Échelle de l'UI", 70, 130, 100, "%", function(v)
        F.UIScale = v / 100
        scale.Scale = F.UIScale
    end)
    slider(pI, "Opacité de l'UI", 0, 70, 0, "%", function(v)
        F.UIOpacity = v / 100
        main.BackgroundTransparency = F.UIOpacity
        bar.BackgroundTransparency = F.UIOpacity
        side.BackgroundTransparency = F.UIOpacity
    end)
    section(pI, "Accent")
    button(pI, "Violet / rose", function() setAccent(Color3.fromRGB(124, 92, 255), Color3.fromRGB(255, 79, 216)) end)
    button(pI, "Cyan / bleu", function() setAccent(Color3.fromRGB(0, 200, 255), Color3.fromRGB(60, 110, 255)) end)
    button(pI, "Vert / lime", function() setAccent(Color3.fromRGB(60, 220, 130), Color3.fromRGB(180, 240, 60)) end)
    button(pI, "Rouge / orange", function() setAccent(Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 150, 60)) end)
    section(pI, "Comportement")
    toggle(pI, "Notifications", true, function(v) F.Notifs = v end)
    toggle(pI, "Cacher l'UI au respawn", false, function(v) F.AutoHideSpawn = v end)
    button(pI, "Recharger l'interface", function()
        Unloaded = true
        clearESP(); setGlow(false); clearFlyMovers()
        for k in pairs(F.LoopTokens) do F.LoopTokens[k] = false end
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        pcall(function() gui:Destroy(); glowFrame:Destroy() end)
        Unloaded = false; UI = { tabs = {}, current = nil }; Connections = {}
        task.wait(0.3)
        buildHub()
    end)
    section(pI, "Configuration")
    button(pI, "Sauvegarder la config", saveConfig)
    button(pI, "Charger la config", loadConfig)

    -- DIVERS
    local pD = createTab("Divers")
    section(pD, "Clé")
    button(pD, "Obtenir une nouvelle clé", function()
        openLink(GET_KEY_URL); notify("Duck Hub", "Lien ouvert et copié.", 5)
    end)
    button(pD, "Réinitialiser la clé", function()
        clearKey(); notify("Duck Hub", "Clé supprimée. Réexécute le script.", 5)
    end)
    section(pD, "Statistiques")
    local st1 = label(pD, "Rôle : ...")
    local st2 = label(pD, "Joueurs : ...")
    local st3 = label(pD, "Pièces : ...")
    task.spawn(function()
        while not Unloaded do
            pcall(function()
                local r = getRole(LP)
                st1.Text = "Rôle : " .. r; st1.TextColor3 = roleColor(r)
                st2.Text = "Joueurs : " .. #Players:GetPlayers()
                st3.Text = "Pièces au sol : " .. #getCoins()
            end)
            task.wait(1)
        end
    end)
    section(pD, "Hub")
    button(pD, "Décharger Duck Hub", function()
        Unloaded = true
        clearESP(); setGlow(false); clearFlyMovers()
        for k in pairs(F.LoopTokens) do F.LoopTokens[k] = false end
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        setFullBright(false)
        pcall(function() gui:Destroy(); glowFrame:Destroy() end)
        pcall(function() notifHolder:Destroy(); hudGui:Destroy(); drawGui:Destroy() end)
    end, true)

    local pCr = createTab("Crédits")
    section(pCr, HUB_NAME .. " v" .. HUB_VERSION)
    label(pCr, "Hub : Duck Hub")
    label(pCr, "Jeu : Murder Mystery 2")
    button(pCr, "Copier le lien de la clé", function()
        if setclipboard then pcall(setclipboard, GET_KEY_URL) end
        notify("Duck Hub", "Lien copié.", 4)
    end)

    UI.current = UI.tabs[1].name
    UI.tabs[1].page.Visible = true
    UI.tabs[1].ind.Visible = true
    UI.tabs[1].btn.BackgroundTransparency = 0
    UI.tabs[1].btn.BackgroundColor3 = C.CARD
    UI.tabs[1].btn.TextColor3 = C.TEXT

    conn(UserInputService.InputBegan, function(i, processed)
        if processed then return end
        if i.KeyCode == F.HideKey then
            main.Visible = not main.Visible
            glowFrame.Visible = main.Visible
        end
    end)

    conn(LP.CharacterAdded, function()
        if F.AutoHideSpawn then main.Visible = false; glowFrame.Visible = false end
        RoleCache[LP] = nil
        clearFlyMovers()
        task.wait(1)
        local hum = humOf(LP)
        if hum then
            hum.WalkSpeed = F.WalkSpeed
            hum.JumpPower = F.JumpPower
            hum.UseJumpPower = true
        end
        if F.Fly then ensureFlyMovers() end
        if F.Trail then setTrail(true) end
    end)

    notify("Duck Hub", "Prêt. " .. #UI.tabs .. " onglets, cache avec " .. F.HideKey.Name, 6)
end

--==================== ÉCRAN DE CLÉ ====================
local function showKeyScreen(prefill)
    local gui = newGui("DuckHubKey")
    local tries = 0

    local glow = create("Frame", {
        Parent = gui, Size = UDim2.new(0, 410, 0, 320), Position = UDim2.new(0.5, -205, 0.5, -160),
        BackgroundColor3 = C.A1, BackgroundTransparency = 0.85,
    })
    corner(glow, 16)
    local main = create("Frame", {
        Parent = gui, Size = UDim2.new(0, 410, 0, 320), Position = UDim2.new(0.5, -205, 0.5, -160),
        BackgroundColor3 = C.BG,
    })
    corner(main, 14); stroke(main, C.STROKE, 1)

    local bar = create("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.PANEL })
    local tl = create("Frame", {
        Parent = bar, Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = C.A1,
    })
    grad(tl, C.A1, C.A2, 0)
    local logo = create("Frame", {
        Parent = bar, Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 14, 0.5, -13), BackgroundColor3 = C.A1,
    })
    corner(logo, 8); grad(logo, C.A1, C.A2, 45)
    create("TextLabel", {
        Parent = logo, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = FONTB, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Text = "D",
    })
    create("TextLabel", {
        Parent = bar, BackgroundTransparency = 1, Size = UDim2.new(0, 240, 1, 0), Position = UDim2.new(0, 50, 0, 0),
        Font = FONTB, TextSize = 14, TextColor3 = C.TEXT, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "DUCK HUB  |  CLÉ",
    })

    local dragging, dStart, sPos = false, nil, nil
    conn(bar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dStart = i.Position; sPos = main.Position end
    end)
    conn(UserInputService.InputChanged, function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dStart
            local np = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
            main.Position = np; glow.Position = np
        end
    end)
    conn(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    local body = create("Frame", {
        Parent = main, Size = UDim2.new(1, -32, 1, -66), Position = UDim2.new(0, 16, 0, 60),
        BackgroundTransparency = 1,
    })
    create("UIListLayout", { Parent = body, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    create("TextLabel", {
        Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = FONT,
        TextSize = 12, TextColor3 = C.SUB, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Entre ta clé pour accéder au hub.",
    })

    local inputFrame = create("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.INPUT })
    corner(inputFrame, 8); stroke(inputFrame, C.STROKE, 1)
    local box = create("TextBox", {
        Parent = inputFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        Font = FONT, TextSize = 13, TextColor3 = C.TEXT, PlaceholderText = "Duck-Hub-XXXXXXX",
        PlaceholderColor3 = C.SUB, TextXAlignment = Enum.TextXAlignment.Left, Text = prefill or "",
        ClearTextOnFocus = false,
    })
    conn(box.Focused, function() tween(inputFrame, 0.12, { BackgroundColor3 = C.CARD_HOV }) end)
    conn(box.FocusLost, function() tween(inputFrame, 0.12, { BackgroundColor3 = C.INPUT }) end)

    local status = create("TextLabel", {
        Parent = body, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = FONT,
        TextSize = 11, TextColor3 = C.SUB, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    })

    local function makeBtn(text, primary, cb)
        local b = create("TextButton", {
            Parent = body, Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = primary and C.A1 or C.CARD, Font = FONTB, TextSize = 13,
            TextColor3 = C.TEXT, Text = text,
        })
        corner(b, 8); stroke(b, C.STROKE, 1)
        if primary then grad(b, C.A1, C.A2) end
        conn(b.MouseEnter, function() tween(b, 0.12, { BackgroundColor3 = primary and C.A2 or C.CARD_HOV }) end)
        conn(b.MouseLeave, function() tween(b, 0.12, { BackgroundColor3 = primary and C.A1 or C.CARD }) end)
        conn(b.MouseButton1Click, function() if cb then cb() end end)
    end

    makeBtn("Obtenir une clé", false, function()
        openLink(GET_KEY_URL)
        status.Text = "Lien ouvert et copié dans le presse-papier."
        status.TextColor3 = C.YELLOW
    end)

    local function submit()
        local key = box.Text
        if tries >= MAX_TRIES then
            status.Text = "Trop de tentatives, réexécute le script."; status.TextColor3 = C.RED; return
        end
        if #key < 3 then
            status.Text = "Entre une clé valide."; status.TextColor3 = C.RED; return
        end
        status.Text = "Vérification..."; status.TextColor3 = C.SUB
        local res = checkKey(key)
        if res == nil then
            status.Text = "Erreur réseau, réessaie."; status.TextColor3 = C.RED
        elseif res == true then
            saveKey(key)
            status.Text = "Clé valide, chargement..."; status.TextColor3 = C.GREEN
            task.wait(0.4)
            gui:Destroy(); glow:Destroy()
            local ok, err = pcall(buildHub)
            if not ok then
                warn("[Duck Hub] buildHub : " .. tostring(err))
                notify("Duck Hub", "Erreur UI : " .. tostring(err), 10)
            end
        else
            tries = tries + 1
            status.Text = "Clé invalide (" .. tries .. "/" .. MAX_TRIES .. ")"; status.TextColor3 = C.RED
        end
    end

    makeBtn("Vérifier la clé", true, submit)
    conn(box.FocusLost, function(enter) if enter then submit() end end)

    if prefill and #prefill > 2 then
        task.spawn(function()
            local res = checkKey(prefill)
            if res == true then
                status.Text = "Clé enregistrée valide. Clique sur Vérifier."; status.TextColor3 = C.GREEN
            elseif res == false then
                status.Text = "Clé enregistrée invalide, ressaisis-en une."; status.TextColor3 = C.RED
            end
        end)
    end
end

--==================== DÉMARRAGE ====================
task.spawn(function()
    if not ReplicatedStorage:FindFirstChild("Remotes") then
        notify("Duck Hub", "Ce serveur ne semble pas être MM2.", 6)
    end
    local saved = loadSavedKey()
    if not ALWAYS_ASK_KEY and saved then
        local res = checkKey(saved)
        if res == true or res == nil then
            if pcall(buildHub) then return end
        end
    end
    showKeyScreen(saved)
end)
