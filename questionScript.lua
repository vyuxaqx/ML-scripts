local services = {
    players = game:GetService("Players"),
    replicatedstorage = game:GetService("ReplicatedStorage"),
    runservice = game:GetService("RunService"),
    tws = game:GetService("TweenService"),
    userinputservice = game:GetService("UserInputService"),
    httpservice = game:GetService("HttpService"),
    virtualuser = game:GetService("VirtualUser"),
    virtualinputmanager = game:GetService("VirtualInputManager"),
    lighting = game:GetService("Lighting"),
    startergui = game:GetService("StarterGui"),
    stats = game:GetService("Stats")
}

local lp = {
    player = services.players.LocalPlayer,
    userid = services.players.LocalPlayer.UserId,
    username = services.players.LocalPlayer.Name,
    displayname = services.players.LocalPlayer.DisplayName
}

-- Zarządzanie połączeniami (Janitor / Cleaning pattern)
local Connections = {}
local function cleanConnections()
    for _, conn in ipairs(Connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)
end

-- Anti-AFK
table.insert(Connections, lp.player.Idled:Connect(function()
    services.virtualinputmanager:SendKeyEvent(true, Enum.KeyCode.Y, false, game)
    task.wait(0.05)
    services.virtualinputmanager:SendKeyEvent(false, Enum.KeyCode.Y, false, game)
end))

-- Usuwanie reklam
function deleteAds()
    for _, portal in ipairs(workspace:GetDescendants()) do
        if portal.Name == "RobloxForwardPortals" then
            portal:Destroy()
        end
    end
    if _G.adsConnection then
        _G.adsConnection:Disconnect()
    end

    _G.adsConnection = workspace.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "RobloxForwardPortals" then
            descendant:Destroy()
        end
    end)
end
deleteAds()

function deleteBodyMovementScript()
    if lp.player.Character and lp.player.Character:FindFirstChild("bodyMovementScript") then
        lp.player.Character.bodyMovementScript:Destroy()
    end
end
deleteBodyMovementScript()

services.muscleEvent = lp.player:WaitForChild("muscleEvent", 10)
local library = loadstring(game:HttpGet("https://gist.githubusercontent.com/vyuxaqx/e041d7f5912c4dd2f65fe2d4f63f1641/raw/b362068b6c3ec3862b7c31bfce073500b44b99ed/eleriumLibraryMod.luau", true))()
local silence, silenceWindow = library:AddWindow("bialy's hub", {
    main_color = Color3.fromRGB(50, 50, 50),
    min_size = Vector2.new(500, 400),
    can_resize = false
})

local tabs = {
    rebirths = silence:AddTab("Rebirths"),
    strength2 = silence:AddTab("Fast Farm"),
    halloween = silence:AddTab("Halloween"),
    petshop = silence:AddTab("Pet Shop"),
    other = silence:AddTab("Other"),
}

tabs.other:Show()

function formatNumber(num)
    if not num then return "0" end
    if num >= 1e18 then return string.format("%.2fQi", num/1e18) end
    if num >= 1e15 then return string.format("%.2fQa", num/1e15) end
    if num >= 1e12 then return string.format("%.2fT", num/1e12) end
    if num >= 1e9 then return string.format("%.2fB", num/1e9) end
    if num >= 1e6 then return string.format("%.2fM", num/1e6) end
    if num >= 1e3 then return string.format("%.2fK", num/1e3) end
    return string.format("%.0f", num)
end

function formatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%dd %dh %dm %ds",
        math.floor(seconds / 86400),
        math.floor((seconds % 86400) / 3600),
        math.floor((seconds % 3600) / 60),
        seconds % 60
    )
end

-- ==================== REBIRTH TAB ====================
local rb = tabs.rebirths
rb.leaderstats = lp.player:WaitForChild("leaderstats")
rb.rebirths = rb.leaderstats:WaitForChild("Rebirths")
rb.strength = rb.leaderstats:WaitForChild("Strength")

rb.target = nil
rb.autoTarget = false
rb.infinite = false
rb.running = false
rb.workerActive = false
rb.samples = {}
rb.lastGainAt = tick()
rb.lastValue = rb.rebirths.Value
rb.startValue = rb.rebirths.Value

rb.Status = rb:AddLabel("Status: Inactive")
rb.Count = rb:AddLabel("Rebirths: " .. formatNumber(rb.rebirths.Value))
rb.Objective = rb:AddLabel("Target: --")
rb.Remaining = rb:AddLabel("Remaining: --")
rb.Eta = rb:AddLabel("Time: --")
rb.Cycle = rb:AddLabel("Cycle: --")
rb.Status.TextColor3 = Color3.fromRGB(255, 80, 80)

local function parseNumber(text)
    local cleaned = (tostring(text or ""):gsub("[%s,%.]", ""))
    return tonumber(cleaned)
end

local function setStatus(text, color)
    rb.Status.Text = "Status: " .. text
    rb.Status.TextColor3 = color
end

local function getRate()
    if #rb.samples < 2 then return nil end
    local totalTime, totalGain = 0, 0
    for _, s in ipairs(rb.samples) do
        totalTime = totalTime + s.time
        totalGain = totalGain + s.gain
    end
    if totalTime <= 0 or totalGain <= 0 then return nil end
    return totalGain / totalTime, totalTime / #rb.samples, totalGain / #rb.samples
end

local function resetEstimator()
    rb.samples = {}
    rb.lastGainAt = tick()
    rb.lastValue = rb.rebirths.Value
    rb.startValue = rb.rebirths.Value
end

table.insert(Connections, rb.rebirths:GetPropertyChangedSignal("Value"):Connect(function()
    local value = rb.rebirths.Value
    if rb.running and value > rb.lastValue then
        local now = tick()
        table.insert(rb.samples, { time = now - rb.lastGainAt, gain = value - rb.lastValue })
        if #rb.samples > 5 then
            table.remove(rb.samples, 1)
        end
        rb.lastGainAt = now
    end
    rb.lastValue = value
end))

rb.updateLabels = function()
    local current = rb.rebirths.Value
    rb.Count.Text = "Rebirths: " .. formatNumber(current) .. " | Gained: " .. formatNumber(current - rb.startValue)

    if rb.target and not rb.infinite then
        rb.Objective.Text = "Target: " .. formatNumber(rb.target)
    else
        rb.Objective.Text = "Target: --"
    end

    if rb.autoTarget and rb.target then
        local remaining = math.max(0, rb.target - current)
        local rate, cycleTime, cycleGain = getRate()
        rb.Remaining.Text = "Remaining: " .. formatNumber(remaining)

        if remaining <= 0 then
            rb.Eta.Text = "Time: Target reached"
        elseif rate then
            rb.Eta.Text = "Time: " .. formatDuration(remaining / rate)
        else
            rb.Eta.Text = "Time: Calculating..."
        end

        if cycleTime then
            rb.Cycle.Text = string.format("Cycle: %.2fs | +%s | Samples: %d", cycleTime, formatNumber(math.floor(cycleGain + 0.5)), #rb.samples)
        else
            rb.Cycle.Text = "Measuring cycles: " .. #rb.samples .. "/2"
        end
    else
        rb.Remaining.Text = "Remaining: --"
        rb.Eta.Text = "Time: --"
        rb.Cycle.Text = "Cycle: --"
    end
end

rb.performRebirth = function()
    local strengthTarget = 5000 + rb.rebirths.Value * 2550

    if rb.running and rb.strength.Value >= strengthTarget then
        local before = rb.rebirths.Value
        repeat
            services.replicatedstorage.rEvents.rebirthRemote:InvokeServer("rebirthRequest")
            task.wait(0.05)
        until rb.rebirths.Value > before or not rb.running
    end
end

rb.stopAll = function()
    rb.autoTarget = false
    rb.infinite = false
    rb.running = false
end

rb.startWorker = function()
    if rb.workerActive then return end
    rb.workerActive = true

    task.spawn(function()
        while rb.running do
            if rb.autoTarget and rb.target and rb.rebirths.Value >= rb.target then
                rb.stopAll()
                rb.switching = true
                rb.targetSwitch:Set(false)
                rb.switching = false
                setStatus("Target reached", Color3.fromRGB(80, 200, 255))
                break
            end

            rb.performRebirth()
            task.wait(0.1)
        end
        rb.workerActive = false
    end)
end

rb.begin = function(statusText)
    resetEstimator()
    rb.running = true
    setStatus(statusText, Color3.fromRGB(80, 255, 120))
    rb.startWorker()
end

rb.finish = function()
    rb.running = false
    setStatus("Paused", Color3.fromRGB(255, 180, 70))
end

rb:AddTextBox("Rebirth target (e.g. 18980)", function(text)
    local parsed = parseNumber(text)
    rb.target = (parsed and parsed > 0) and parsed or nil
    rb.updateLabels()
end)

rb.targetSwitch = rb:AddSwitch("Rebirth until target", function(state)
    if rb.switching then return end
    if state then
        if not rb.target then
            setStatus("Set a target first!", Color3.fromRGB(255, 80, 80))
            rb.switching = true
            rb.targetSwitch:Set(false)
            rb.switching = false
            return
        end
        rb.infinite = false
        rb.autoTarget = true
        rb.switching = true
        rb.infiniteSwitch:Set(false)
        rb.switching = false
        rb.begin("Rebirthing to target")
    else
        rb.autoTarget = false
        if not rb.infinite then rb.finish() end
    end
end)

rb.infiniteSwitch = rb:AddSwitch("Infinite Rebirths", function(state)
    if rb.switching then return end
    if state then
        rb.autoTarget = false
        rb.infinite = true
        rb.switching = true
        rb.targetSwitch:Set(false)
        rb.switching = false
        rb.begin("Rebirthing (infinite)")
    else
        rb.infinite = false
        if not rb.autoTarget then rb.finish() end
    end
end)

rb.targetSwitch:Set(false)
rb.infiniteSwitch:Set(false)

task.spawn(function()
    while silenceWindow do
        rb.updateLabels()
        task.wait(0.5)
    end
end)

-- ==================== STRENGTH TAB ====================
local str = tabs.strength2
str.running = false
str.workerActive = false
str.startedAt = 0
str.totalElapsed = 0
str.timerStarted = false
str.repSpeed = 40
str.pingControl = true
str.currentPing = 0
str.Status = str:AddLabel("Status: Inactive")
str.Runtime = str:AddLabel("Runtime: 0d 0h 0m 0s")
str.Status.TextColor3 = Color3.fromRGB(255, 80, 80)
str.leaderstats = lp.player:WaitForChild("leaderstats")
str.strength = str.leaderstats:WaitForChild("Strength")
str.startStrength = str.strength.Value
str.StrengthStats = str:AddLabel("Strength: " .. formatNumber(str.strength.Value) .. " | Gained: 0")

str.updateStats = function()
    str.StrengthStats.Text = "Strength: " .. formatNumber(str.strength.Value)
        .. " | Gained: " .. formatNumber(str.strength.Value - str.startStrength)
end

table.insert(Connections, str.strength:GetPropertyChangedSignal("Value"):Connect(function()
    str.updateStats()
end))

str.updateRuntime = function()
    local elapsed = str.totalElapsed
    if str.running and str.timerStarted then
        elapsed = elapsed + tick() - str.startedAt
    end
    str.Runtime.Text = string.format("Runtime: %dd %dh %dm %ds",
        math.floor(elapsed / 86400),
        math.floor((elapsed % 86400) / 3600),
        math.floor((elapsed % 3600) / 60),
        math.floor(elapsed % 60)
    )
end

str.networkStats = services.stats.Network.ServerStatsItem["Data Ping"]

str.getCurrentPing = function()
    return str.networkStats:GetValue()
end

str.getAdaptiveSpeed = function(ping)
    if ping < 80 then return 500
    elseif ping < 150 then return 300
    elseif ping < 250 then return 100
    end
    return 50
end

str.workerLoop = function()
    str.lastPingUpdate = time()
    str.currentPing = str.getCurrentPing()

    while str.running do
        if time() - str.lastPingUpdate > 0.5 then
            str.currentPing = str.getCurrentPing()
            str.lastPingUpdate = time()
        end

        local repsToFire = str.pingControl and str.getAdaptiveSpeed(str.currentPing) or str.repSpeed
        repsToFire = math.min(repsToFire, str.repSpeed)
        local delayBetweenBatches = math.clamp(str.currentPing / 2500, 0.001, 0.1)

        str.Status.Text = "Status: Farming | " .. formatNumber(repsToFire) .. " reps/batch | " .. formatNumber(str.currentPing) .. " ms"
        str.Status.TextColor3 = Color3.fromRGB(80, 255, 120)

        for repCount = 1, repsToFire do
            if not str.running then break end
            if services.muscleEvent then
                services.muscleEvent:FireServer("rep")
            end
            if repCount % 500 == 0 then
                task.wait()
            end
        end
        task.wait(delayBetweenBatches)
    end

    str.workerActive = false
end

str.startWorker = function()
    if str.workerActive then return end
    str.workerActive = true
    task.spawn(str.workerLoop)
end

str.repSpeedSlider = str:AddSlider("Reps/s", function(value)
    str.repSpeed = math.clamp(math.floor(value), 1, 200)
end, {min = 1, max = 200})
str.repSpeedSlider:Set(80)

str:AddSwitch("Controlled Speed", function(state)
    str.pingControl = state
end):Set(true)

str.FastRepToggle = str:AddSwitch("Fast Rep", function(state)
    str.running = state
    if state then
        str.timerStarted = true
        str.startedAt = tick()
        str.Status.Text = "Status: Starting..."
        str.Status.TextColor3 = Color3.fromRGB(80, 255, 120)
        str.startWorker()
    else
        if str.timerStarted and str.startedAt > 0 then
            str.totalElapsed = str.totalElapsed + tick() - str.startedAt
            str.startedAt = 0
            str.timerStarted = false
        end
        str.Status.Text = str.totalElapsed > 0 and "Status: Paused" or "Status: Inactive"
        str.Status.TextColor3 = str.totalElapsed > 0 and Color3.fromRGB(255, 180, 70) or Color3.fromRGB(255, 80, 80)
        str.updateRuntime()
    end
end)
str.FastRepToggle:Set(false)

task.spawn(function()
    while true do
        str.updateRuntime()
        task.wait(1)
    end
end)
str:AddLabel("20-50 rep speed is recommended, higher might cause lags.")

-- ==================== HALLOWEEN TAB ====================
local hwTab = tabs.halloween
local hw = {}

-- Nazwy bossów w workspace (wielkość liter nie ma znaczenia)
hw.bossNames = {
    ["grim reaper"] = true,
    ["frankenbrute"] = true,
    ["scarecrow colossus"] = true,
    ["pumpkin titan"] = true,
}
hw.color = Color3.fromRGB(255, 120, 0)
hw.enabled = false
hw.tracked = {}      -- [model] = { highlight, billboard, nameLabel, hpLabel, maxHp }
hw.connections = {}

hw.statusLabel = hwTab:AddLabel("Bosses found: 0")

hw.isBoss = function(inst)
    return inst:IsA("Model") and hw.bossNames[string.lower(inst.Name)] == true
end

-- Część, do której przyczepiamy napis HP
hw.findPart = function(model)
    local part = model:FindFirstChild("RootPart") or model:FindFirstChild("HumanoidRootPart")
    if part and part:IsA("BasePart") then return part end
    if model.PrimaryPart then return model.PrimaryPart end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

-- Przyrostki liczb używane w tekście HP (np. "7.60K / 8K")
hw.suffixes = {
    k = 1e3, m = 1e6, b = 1e9, t = 1e12,
    qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33,
}

hw.parseAmount = function(num, suffix)
    local n = tonumber((num:gsub(",", "")))
    if not n then return nil end
    if suffix and suffix ~= "" then
        local mult = hw.suffixes[string.lower(suffix)]
        if not mult then return nil end
        n = n * mult
    end
    return n
end

-- HP bossa = tekst w halloweenBossHealth > Bar > Health (np. "7.60K / 8K")
-- Zwraca: aktualne HP, max HP, oryginalny tekst
hw.getHealth = function(model)
    local gui = model:FindFirstChild("halloweenBossHealth")
    local label = gui and gui:FindFirstChild("Health", true)

    if label and label:IsA("TextLabel") then
        local text = label.Text
        local n1, s1, n2, s2 = string.match(text, "^%s*([%d%.,]+)%s*(%a*)%s*/%s*([%d%.,]+)%s*(%a*)")
        if n1 then
            local hp = hw.parseAmount(n1, s1)
            local max = hw.parseAmount(n2, s2)
            if hp then
                return hp, max, text
            end
        end
        return nil, nil, text
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health, hum.MaxHealth, nil end

    return nil, nil, nil
end

hw.track = function(model)
    if hw.tracked[model] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "BossHighlight"
    highlight.FillColor = hw.color
    highlight.OutlineColor = hw.color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = model
    highlight.Parent = model

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BossHpTag"
    billboard.Size = UDim2.new(0, 240, 0, 46)
    billboard.StudsOffset = Vector3.new(0, 8, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = hw.findPart(model)
    billboard.Parent = model

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = model.Name
    nameLabel.TextColor3 = hw.color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = billboard

    local hpLabel = Instance.new("TextLabel")
    hpLabel.Position = UDim2.new(0, 0, 0.5, 0)
    hpLabel.Size = UDim2.new(1, 0, 0.5, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Text = "HP: ?"
    hpLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    hpLabel.TextStrokeTransparency = 0
    hpLabel.TextSize = 16
    hpLabel.Font = Enum.Font.SourceSansBold
    hpLabel.Parent = billboard

    hw.tracked[model] = {
        highlight = highlight,
        billboard = billboard,
        nameLabel = nameLabel,
        hpLabel = hpLabel,
        maxHp = 0,
    }
end

hw.untrack = function(model)
    local data = hw.tracked[model]
    if not data then return end

    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    hw.tracked[model] = nil
end

hw.update = function(model, data)
    -- część mogła jeszcze nie być załadowana przy pierwszym podpięciu
    local part = hw.findPart(model)
    if part and data.billboard.Adornee ~= part then
        data.billboard.Adornee = part
    end

    local hp, max, text = hw.getHealth(model)
    if not hp then
        data.hpLabel.Text = "HP: " .. (text or "?")
        return
    end

    local pct = (max and max > 0) and math.clamp(hp / max, 0, 1) or 1
    local shown = text or string.format("%s / %s", formatNumber(hp), formatNumber(max or hp))

    data.hpLabel.Text = string.format("HP: %s (%d%%)", shown, math.floor(pct * 100 + 0.5))
    data.hpLabel.TextColor3 = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(100, 255, 100), pct)
end

hw.enable = function()
    hw.enabled = true

    for _, child in ipairs(workspace:GetChildren()) do
        if hw.isBoss(child) then
            hw.track(child)
        end
    end

    table.insert(hw.connections, workspace.ChildAdded:Connect(function(child)
        if hw.enabled and hw.isBoss(child) then
            hw.track(child)
        end
    end))

    table.insert(hw.connections, workspace.ChildRemoved:Connect(function(child)
        hw.untrack(child)
    end))
end

hw.disable = function()
    hw.enabled = false

    for _, conn in ipairs(hw.connections) do
        conn:Disconnect()
    end
    table.clear(hw.connections)

    for model in pairs(hw.tracked) do
        hw.untrack(model)
    end
    hw.statusLabel.Text = "Bosses found: 0"
end

hwTab:AddSwitch("Highlight Bosses", function(state)
    if state then
        hw.enable()
    else
        hw.disable()
    end
end)

-- ---------- Teleporty do bossów ----------
hw.bossList = { "Grim Reaper", "Frankenbrute", "Scarecrow Colossus", "Pumpkin Titan" }
hw.tpOffset = Vector3.new(0, 3, 0) -- offset względem bossa (Vector3.new(0,0,0) = dokładnie w bossa)

hw.tpStatus = hwTab:AddLabel("Teleport: -")

hw.getRoot = function()
    local character = lp.player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

hw.teleportToModel = function(model)
    local hrp = hw.getRoot()
    local part = hw.findPart(model)
    if not hrp or not part then return false end

    hrp.CFrame = CFrame.new(part.Position + hw.tpOffset) * (hrp.CFrame - hrp.Position)
    hrp.AssemblyLinearVelocity = Vector3.zero
    return true
end

-- Najbliższy boss o danej nazwie (gdyby było kilka)
hw.findBossByName = function(name)
    local hrp = hw.getRoot()
    local best, bestDist = nil, math.huge

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and string.lower(child.Name) == string.lower(name) then
            local part = hw.findPart(child)
            if part then
                local dist = hrp and (part.Position - hrp.Position).Magnitude or 0
                if dist < bestDist then
                    best, bestDist = child, dist
                end
            end
        end
    end

    return best
end

for _, bossName in ipairs(hw.bossList) do
    hwTab:AddButton("Tp " .. bossName, function()
        local boss = hw.findBossByName(bossName)
        if boss and hw.teleportToModel(boss) then
            hw.tpStatus.Text = "Teleport: " .. bossName
        else
            hw.tpStatus.Text = "Teleport: " .. bossName .. " not found"
        end
    end)
end

-- Boss z najniższym aktualnym HP (z tekstu w halloweenBossHealth)
hwTab:AddButton("Tp lowest hp", function()
    local best, bestHp = nil, math.huge

    for _, child in ipairs(workspace:GetChildren()) do
        if hw.isBoss(child) then
            local hp = hw.getHealth(child)
            if hp and hp > 0 and hp < bestHp then
                best, bestHp = child, hp
            end
        end
    end

    if best and hw.teleportToModel(best) then
        hw.tpStatus.Text = "Teleport: " .. best.Name .. " (" .. formatNumber(bestHp) .. " HP)"
    else
        hw.tpStatus.Text = "Teleport: no boss with readable HP"
    end
end)

task.spawn(function()
    while true do
        if hw.enabled then
            local count = 0
            for model, data in pairs(hw.tracked) do
                if not model.Parent then
                    hw.untrack(model)
                else
                    count = count + 1
                    hw.update(model, data)
                end
            end
            hw.statusLabel.Text = "Bosses found: " .. count
        end
        task.wait(0.25)
    end
end)

hwTab:AddLabel("Grim Reaper, Frankenbrute, Scarecrow Colossus, Pumpkin Titan")


-- ==================== PET SHOP TAB (v4) ====================
-- Wklej w miejsce starej sekcji Pet Shop, przed OTHER TAB.
-- Wszystkie PriceType są obsługiwane poza "Tokens".

local petTab = tabs.petshop or silence:AddTab("Pet Shop")
local ps = {}

ps.selected = { pet = nil, aura = nil }
ps.auto = { pet = false, aura = false }
ps.gen = { pet = 0, aura = 0 }
ps.switches = {}
ps.priceLabels = {}
ps.dropdowns = {}
ps.switching = false

-- ---------- Ścieżki sklepu ----------
ps.getFolder = function()
    local rs = services.replicatedstorage
    local shared = rs:FindFirstChild("shared")
    local runtime = shared and shared:FindFirstChild("runtime")

    return (runtime and runtime:FindFirstChild("cPetShopFolder"))
        or rs:FindFirstChild("cPetShopFolder")
end

ps.getRemote = function()
    local rs = services.replicatedstorage
    local events = rs:FindFirstChild("rEvents")

    return (events and events:FindFirstChild("cPetShopRemote"))
        or rs:FindFirstChild("cPetShopRemote")
end

-- ---------- Statystyki gracza ----------
ps.findValue = function(root, names)
    if not root then return nil end

    for _, name in ipairs(names) do
        local wanted = tostring(name):lower():gsub("%s+", "")

        for _, child in ipairs(root:GetChildren()) do
            local key = child.Name:lower():gsub("%s+", "")

            if key == wanted and child:IsA("ValueBase") then
                return child
            end
        end
    end

    return nil
end

ps.getPlayerStat = function(names)
    local leaderstats = lp.player:FindFirstChild("leaderstats")

    return ps.findValue(leaderstats, names)
        or ps.findValue(lp.player, names)
end

-- ---------- Formatowanie liczb ----------
ps.formatExact = function(n)
    n = tonumber(n)
    if not n then return "?" end

    local s = string.format("%.0f", math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")

    return (n < 0 and "-" or "") .. out
end

ps.nameOf = function(value)
    if type(value) == "table" then
        return value.name or value.Name or value[1]
    end

    if value == nil then return nil end

    return tostring(value)
end

-- ---------- Priorytety petów i aur ----------
ps.zonePriority = {
    ["Core Pup"] = 70,
    ["Volt Talon"] = 70,
    ["Reactor Beast"] = 70,
    ["Plasma Ravager"] = 70,
    ["Titan Reactor"] = 70,
    ["Apex Overlord"] = 70,
    ["Neon Guardian"] = 60,
    ["Cybernetic Showdown Dragon"] = 60,
    ["Darkstar Hunter"] = 60,
    ["Muscle Sensei"] = 50,
    ["Infernal Dragon"] = 50,
    ["Aether Spirit Bunny"] = 50,
    ["Magic Butterfly"] = 40,
    ["Ultra Birdie"] = 40,
    ["Muscle King"] = 70,
    ["Entropic Blast"] = 60,
}

ps.rarityPriority = {
    Basic = 1,
    Advanced = 2,
    Rare = 3,
    Epic = 4,
    Unique = 5,
}

ps.itemZone = function(item)
    for _, attribute in ipairs({
        "ZoneRequirement",
        "IslandRequirement",
        "UnlockRequirement",
        "ZonePriority"
    }) do
        local value = tonumber(item:GetAttribute(attribute))
        if value then return value end
    end

    return ps.zonePriority[item.Name] or 0
end

ps.better = function(a, b)
    local zoneA, zoneB = ps.itemZone(a), ps.itemZone(b)

    if zoneA ~= zoneB then
        return zoneA > zoneB
    end

    local priceA = tonumber(a:GetAttribute("Price")) or 0
    local priceB = tonumber(b:GetAttribute("Price")) or 0

    if priceA ~= priceB then
        return priceA > priceB
    end

    local rarityA =
        ps.rarityPriority[tostring(a:GetAttribute("Rarity"))] or 0
    local rarityB =
        ps.rarityPriority[tostring(b:GetAttribute("Rarity"))] or 0

    if rarityA ~= rarityB then
        return rarityA > rarityB
    end

    return a.Name < b.Name
end

-- ---------- Listy petów i aur ----------
-- Wyklucza PriceType = "Tokens".
ps.shopLists = function()
    local pets, auras = {}, {}
    local folder = ps.getFolder()

    if folder then
        for _, item in ipairs(folder:GetChildren()) do
            local price = item:GetAttribute("Price")
            local priceType = item:GetAttribute("PriceType")

            if typeof(price) == "number"
                and priceType ~= nil
                and tostring(priceType) ~= ""
                and tostring(priceType) ~= "Tokens" then

                if item:GetAttribute("IsPowerUp") == true then
                    table.insert(auras, item)
                else
                    table.insert(pets, item)
                end
            end
        end
    end

    table.sort(pets, ps.better)
    table.sort(auras, ps.better)

    local petNames, auraNames = {}, {}

    for _, item in ipairs(pets) do
        table.insert(petNames, item.Name)
    end

    for _, item in ipairs(auras) do
        table.insert(auraNames, item.Name)
    end

    return petNames, auraNames
end

-- ---------- Wyświetlanie ceny ----------
ps.updatePrice = function(kind)
    local label = ps.priceLabels[kind]
    if not label then return end

    local name = ps.selected[kind]

    if not name then
        label.Text = "Price: select an item"
        return
    end

    local folder = ps.getFolder()
    local item = folder and folder:FindFirstChild(name)

    if not item then
        label.Text = "Price: waiting for the real shop"
        return
    end

    local price = item:GetAttribute("Price")
    local priceType = item:GetAttribute("PriceType") or "Unknown"

    label.Text = "Price: "
        .. ps.formatExact(price)
        .. " "
        .. tostring(priceType)
end

-- ---------- Kupowanie ----------
ps.buy = function(name)
    if not name then
        return false, "no item selected"
    end

    local folder = ps.getFolder()

    if not folder then
        return false, "shop folder not found"
    end

    local remote = ps.getRemote()

    if not remote then
        return false, "shop remote not found"
    end

    if not remote:IsA("RemoteFunction") then
        return false, "shop remote is a " .. remote.ClassName
    end

    local item = folder:FindFirstChild(name)

    if not item then
        return false, "item not found: " .. tostring(name)
    end

    local priceType = item:GetAttribute("PriceType")

    if priceType == nil or tostring(priceType) == "" then
        return false, "PriceType not found"
    end

    -- Blokada zakupów za Tokens.
    if tostring(priceType) == "Tokens" then
        return false, "Tokens currency is excluded"
    end

    local price = tonumber(item:GetAttribute("Price")) or 0

    -- Obsługa pozostałych typów walut.
    local stat = ps.getPlayerStat({ tostring(priceType) })

    if not stat then
        return false, tostring(priceType) .. " stat not found"
    end

    local have = tonumber(stat.Value) or 0

    if have < price then
        return false, "not enough " .. tostring(priceType)
            .. " (" .. ps.formatExact(have)
            .. " / " .. ps.formatExact(price) .. ")"
    end

    local ok, result = pcall(function()
        return remote:InvokeServer(item)
    end)

    if not ok then
        return false, "server error: " .. tostring(result)
    end

    if result ~= true then
        return false, "server replied: " .. tostring(result)
    end

    return true
end

ps.buyOnce = function(kind)
    local name = ps.selected[kind]
    local ok, reason = ps.buy(name)

    ps.status.Text = ok
        and ("Status: bought " .. tostring(name))
        or ("Status: " .. tostring(reason))
end

-- ---------- Auto Buy ----------
ps.setAuto = function(kind, state)
    ps.auto[kind] = state
    ps.gen[kind] = ps.gen[kind] + 1

    if not state then return end

    local gen = ps.gen[kind]

    task.spawn(function()
        while ps.auto[kind] and ps.gen[kind] == gen do
            local name = ps.selected[kind]
            local ok, reason = ps.buy(name)

            if not ok then
                ps.auto[kind] = false
                ps.switching = true
                ps.switches[kind]:Set(false)
                ps.switching = false

                ps.status.Text = "Status: stopped - " .. tostring(reason)
                break
            end

            ps.status.Text = "Status: bought " .. tostring(name)
            task.wait(0.6)
        end
    end)
end

-- ---------- UI: Pets ----------
local petNames, auraNames = ps.shopLists()

petTab:AddLabel("Pets")

ps.dropdowns.pet = petTab:AddDropdown("Select Pet", function(value)
    ps.selected.pet = ps.nameOf(value)
    ps.updatePrice("pet")
end)

for _, name in ipairs(petNames) do
    ps.dropdowns.pet:Add(name)
end

ps.priceLabels.pet = petTab:AddLabel("Price: select an item")

petTab:AddButton("Buy Pet", function()
    ps.buyOnce("pet")
end)

ps.switches.pet = petTab:AddSwitch("Auto Buy Pet", function(state)
    if ps.switching then return end
    ps.setAuto("pet", state)
end)

-- ---------- UI: Auras ----------
petTab:AddLabel("Auras")

ps.dropdowns.aura = petTab:AddDropdown("Select Aura", function(value)
    ps.selected.aura = ps.nameOf(value)
    ps.updatePrice("aura")
end)

for _, name in ipairs(auraNames) do
    ps.dropdowns.aura:Add(name)
end

ps.priceLabels.aura = petTab:AddLabel("Price: select an item")

petTab:AddButton("Buy Aura", function()
    ps.buyOnce("aura")
end)

ps.switches.aura = petTab:AddSwitch("Auto Buy Aura", function(state)
    if ps.switching then return end
    ps.setAuto("aura", state)
end)

ps.status = petTab:AddLabel("Status: -")

-- ---------- Odświeżanie list ----------
ps.refresh = function()
    local pets, auras = ps.shopLists()

    local function fill(dropdown, names)
        local okClear = pcall(function()
            dropdown:Clear()
        end)

        if not okClear then return end

        for _, name in ipairs(names) do
            dropdown:Add(name)
        end
    end

    fill(ps.dropdowns.pet, pets)
    fill(ps.dropdowns.aura, auras)

    ps.updatePrice("pet")
    ps.updatePrice("aura")
end

ps.watchFolder = function(folder)
    table.insert(Connections, folder.ChildAdded:Connect(function()
        task.defer(ps.refresh)
    end))

    table.insert(Connections, folder.ChildRemoved:Connect(function()
        task.defer(ps.refresh)
    end))
end

local shopFolder = ps.getFolder()

if shopFolder then
    ps.watchFolder(shopFolder)
else
    table.insert(
        Connections,
        services.replicatedstorage.DescendantAdded:Connect(function(child)
            if child.Name == "cPetShopFolder" then
                ps.watchFolder(child)
                task.defer(ps.refresh)
            end
        end)
    )
end

-- ---------- Cena na żywo ----------
task.spawn(function()
    while true do
        ps.updatePrice("pet")
        ps.updatePrice("aura")
        task.wait(1)
    end
end)


-- ==================== OTHER TAB ====================
local oth = tabs.other

oth.eggsowned = oth:AddLabel("Protein Eggs: 0")
oth.eggsowned.TextSize = 14
oth.autoEgg = false
oth.autoShake = false
oth.autoCrystal = false
oth.autoEvolve = false
oth.eatAllBoostsRunning = false
oth.evolvePetName = "Nova Phoenix"

task.spawn(function()
    while true do
        local count = 0
        local backpack = lp.player:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item.Name == "Protein Egg" then count = count + 1 end
            end
        end
        oth.eggsowned.Text = "Protein Eggs: " .. count
        task.wait(1)
    end
end)

oth.x2str = oth:AddLabel("x2 Strength: 00:00")
oth.x2str.TextSize = 14

task.spawn(function()
    while true do
        local boostTimers = lp.player:FindFirstChild("boostTimersFolder")
        local boost = boostTimers and boostTimers:FindFirstChild("Protein Egg")
        local seconds = (boost and boost:IsA("IntValue")) and boost.Value or 0
        oth.x2str.Text = "x2 Strength: " .. formatDuration(seconds)
        task.wait(1)
    end
end)

local function eatEgg()
    local char = lp.player.Character
    local backpack = lp.player:FindFirstChild("Backpack")
    local tool = (char and char:FindFirstChild("Protein Egg")) or (backpack and backpack:FindFirstChild("Protein Egg"))
    if tool and services.muscleEvent then
        for _ = 1, 5 do
            services.muscleEvent:FireServer("proteinEgg", tool)
        end
    end
end

task.spawn(function()
    while true do
        if oth.autoEgg then
            eatEgg()
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end)

oth:AddSwitch("Eat Eggs", function(state)
    oth.autoEgg = state
end)

local function eatShake()
    local char = lp.player.Character
    local backpack = lp.player:FindFirstChild("Backpack")
    local tool = (char and char:FindFirstChild("Tropical Shake")) or (backpack and backpack:FindFirstChild("Tropical Shake"))
    if tool and services.muscleEvent then
        services.muscleEvent:FireServer("tropicalShake", tool)
    end
end

task.spawn(function()
    while true do
        if oth.autoShake then
            eatShake()
            task.wait(150)
        else
            task.wait(1)
        end
    end
end)

oth:AddSwitch("Auto Shake", function(state)
    oth.autoShake = state
end)

-- Auto Spin Wheel
oth:AddSwitch("Spin Fortune Wheel", function(bool)
    _G.AutoSpinWheel = bool
    if bool then
        task.spawn(function()
            local rspin = services.replicatedstorage.rEvents:FindFirstChild("openFortuneWheelRemote")
            local chances = services.replicatedstorage.shared.catalogs.fortuneWheelChances["Fortune Wheel"]
            while _G.AutoSpinWheel and rspin do
                rspin:InvokeServer("openFortuneWheel", chances)
                task.wait(1)
            end
        end)
    end
end)

-- Auto Crystal
task.spawn(function()
    while true do
        if oth.autoCrystal then
            pcall(function()
                services.replicatedstorage.rEvents.openCrystalRemote:InvokeServer("openCrystalBulk", "Overcharged Crystal", 10)
            end)
            task.wait(0.2)
        else
            task.wait(1)
        end
    end
end)

oth:AddSwitch("Bulk Open Overcharged Crystal", function(state)
    oth.autoCrystal = state
end):Set(false)

-- Anti-Lag
local antiLagActive = false
oth:AddButton("Anti Lag (Optimization)", function()
    if antiLagActive then return end
    antiLagActive = true

    for _, v in ipairs(services.lighting:GetChildren()) do
        if v:IsA("Sky") or v:IsA("Atmosphere") then
            v:Destroy()
        end
    end

    local darkSky = Instance.new("Sky")
    darkSky.Name = "DarkSky"
    darkSky.SkyboxBk, darkSky.SkyboxDn, darkSky.SkyboxFt = "rbxassetid://0", "rbxassetid://0", "rbxassetid://0"
    darkSky.SkyboxLf, darkSky.SkyboxRt, darkSky.SkyboxUp = "rbxassetid://0", "rbxassetid://0", "rbxassetid://0"
    darkSky.Parent = services.lighting

    services.lighting.Brightness = 0
    services.lighting.GlobalShadows = false

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            obj:Destroy()
        elseif obj:IsA("BasePart") then
            obj.Color = Color3.new(0, 0, 0)
            obj.Material = Enum.Material.SmoothPlastic
        end
    end
end)

-- Titling & Ping Display
task.spawn(function()
    while silence do
        local ok, ping = pcall(function()
            return str.networkStats:GetValue()
        end)
        silence:SetTitle("❓❓❓  " .. (ok and math.floor(ping) or "?") .. " ms")
        task.wait(2)
    end
end)
