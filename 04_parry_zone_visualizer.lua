--[[
    ============================================================
    ВИЗУАЛИЗАТОР ЗОНЫ ПАРИРОВАНИЯ
    ============================================================
    Назначение: Отладочный инструмент, рисующий вокруг персонажа
    полупрозрачную сферу, показывающую радиус парирования.
    
    Что проверяет: Помогает визуально отладить механику парирования,
    показывает зону действия и логирует успешные парирования.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    ParryRadius = 10,           -- Радиус парирования в стадах
    SphereTransparency = 0.85,  -- Прозрачность сферы (0 = непрозрачная, 1 = невидимая)
    IdleColor = Color3.fromRGB(0, 150, 255),      -- Цвет в режиме ожидания (синий)
    ActiveColor = Color3.fromRGB(0, 255, 100),     -- Цвет при успешном парировании (зелёный)
    FailColor = Color3.fromRGB(255, 50, 50),       -- Цвет при провале (красный)
    FlashDuration = 0.5,        -- Длительность подсветки после парирования (сек)
    ShowPlayerMarkers = true,   -- Показывать маркеры игроков в зоне
}

-- Глобальный доступ для настройки из CommandBar
_G.ParryVisualizerConfig = CONFIG

-- =============================================
-- СОЗДАНИЕ СФЕРЫ ВИЗУАЛИЗАЦИИ
-- =============================================
local parryZone = Instance.new("Part")
parryZone.Name = "ParryZoneVisualizer"
parryZone.Shape = Enum.PartType.Ball
parryZone.Size = Vector3.new(CONFIG.ParryRadius * 2, CONFIG.ParryRadius * 2, CONFIG.ParryRadius * 2)
parryZone.Anchored = true
parryZone.CanCollide = false
parryZone.CanTouch = false
parryZone.CanQuery = false
parryZone.Material = Enum.Material.ForceField
parryZone.Color = CONFIG.IdleColor
parryZone.Transparency = CONFIG.SphereTransparency
parryZone.CastShadow = false
parryZone.Parent = workspace

-- Добавляем BillboardGui с информацией
local billboard = Instance.new("BillboardGui")
billboard.Name = "ParryInfo"
billboard.Size = UDim2.new(0, 200, 0, 80)
billboard.StudsOffset = Vector3.new(0, CONFIG.ParryRadius + 2, 0)
billboard.AlwaysOnTop = true
billboard.Parent = parryZone

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 1, 0)
infoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
infoLabel.BackgroundTransparency = 0.5
infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.RobotoMono
infoLabel.Text = "Parry Zone: " .. CONFIG.ParryRadius .. " studs"
infoLabel.Parent = billboard

-- =============================================
-- ОТСЛЕЖИВАНИЕ СОСТОЯНИЯ
-- =============================================
local parryLog = {}  -- Журнал парирований
local playersInZone = {}  -- Игроки в зоне парирования
local connections = {}
local flashEndTime = 0

-- =============================================
-- ФУНКЦИИ
-- =============================================

-- Получить игроков в зоне парирования
local function getPlayersInRange()
    local inRange = {}
    local myPos = humanoidRootPart.Position
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local distance = (otherRoot.Position - myPos).Magnitude
                if distance <= CONFIG.ParryRadius then
                    table.insert(inRange, {
                        Player = player,
                        Distance = distance,
                        Position = otherRoot.Position
                    })
                end
            end
        end
    end
    
    return inRange
end

-- Логирование парирования
local function logParry(success, targetName, reactionTime)
    local entry = {
        Timestamp = os.clock(),
        Time = os.date("%H:%M:%S"),
        Success = success,
        Target = targetName or "Unknown",
        ReactionTime = reactionTime or 0,
        PlayersInZone = #getPlayersInRange()
    }
    table.insert(parryLog, entry)
    
    local status = success and "✅ УСПЕХ" or "❌ ПРОВАЛ"
    print(string.format(
        "[ParryVis] %s | %s | Цель: %s | Реакция: %.0fмс | Игроков в зоне: %d",
        entry.Time, status, entry.Target, 
        entry.ReactionTime * 1000, entry.PlayersInZone
    ))
end

-- Подсветка сферы при парировании
local function flashZone(success)
    parryZone.Color = success and CONFIG.ActiveColor or CONFIG.FailColor
    parryZone.Transparency = CONFIG.SphereTransparency - 0.3
    flashEndTime = os.clock() + CONFIG.FlashDuration
end

-- Маркеры игроков в зоне
local playerMarkers = {}

local function updatePlayerMarkers(playersInRange)
    -- Удаляем старые маркеры
    for _, marker in pairs(playerMarkers) do
        marker:Destroy()
    end
    playerMarkers = {}
    
    if not CONFIG.ShowPlayerMarkers then return end
    
    for _, data in ipairs(playersInRange) do
        local marker = Instance.new("Part")
        marker.Name = "PlayerMarker_" .. data.Player.Name
        marker.Shape = Enum.PartType.Cylinder
        marker.Size = Vector3.new(0.2, CONFIG.ParryRadius * 2.5, 0.2)
        marker.Anchored = true
        marker.CanCollide = false
        marker.CanTouch = false
        marker.CanQuery = false
        marker.Material = Enum.Material.Neon
        marker.CastShadow = false
        
        -- Цвет зависит от расстояния (ближе = краснее)
        local ratio = data.Distance / CONFIG.ParryRadius
        marker.Color = Color3.fromRGB(
            math.floor(255 * (1 - ratio)),
            math.floor(255 * ratio),
            0
        )
        marker.Transparency = 0.3
        
        -- Вертикальная линия от позиции игрока
        marker.CFrame = CFrame.new(data.Position) * CFrame.Angles(0, 0, math.rad(90))
        marker.Parent = workspace
        
        table.insert(playerMarkers, marker)
    end
end

-- =============================================
-- МОНИТОРИНГ СОБЫТИЙ ПАРИРОВАНИЯ
-- =============================================

-- Попытка найти RemoteEvent парирования
local function setupParryMonitoring()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Events")
        or ReplicatedStorage
    
    -- Мониторим различные возможные имена ремоутов
    local parryNames = {"Parry", "Block", "Deflect", "Counter", "ParryResult", "CombatParry"}
    
    for _, name in ipairs(parryNames) do
        local remote = remotes:FindFirstChild(name)
        if remote then
            if remote:IsA("RemoteEvent") then
                local conn = remote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    local success = args[1] -- Предполагаем первый аргумент = результат
                    logParry(success ~= false, tostring(args[2] or ""), 0)
                    flashZone(success ~= false)
                end)
                table.insert(connections, conn)
                print("[ParryVis] Подключен к RemoteEvent: " .. name)
            end
        end
    end
    
    -- Мониторинг атрибутов парирования
    local function watchAttribute(obj, attrName)
        local conn = obj:GetAttributeChangedSignal(attrName):Connect(function()
            local val = obj:GetAttribute(attrName)
            if val == true then
                logParry(true, "AttributeParry", 0)
                flashZone(true)
            end
        end)
        table.insert(connections, conn)
    end
    
    -- Проверяем атрибуты на персонаже
    if character then
        for _, attrName in ipairs({"IsParrying", "Parried", "BlockSuccess", "ParrySuccess"}) do
            if character:GetAttribute(attrName) ~= nil then
                watchAttribute(character, attrName)
                print("[ParryVis] Мониторинг атрибута: " .. attrName)
            end
        end
    end
end

-- =============================================
-- ОСНОВНОЙ ЦИКЛ ОБНОВЛЕНИЯ
-- =============================================
local renderConn = RunService.RenderStepped:Connect(function()
    if not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    -- Обновляем позицию сферы
    parryZone.CFrame = CFrame.new(humanoidRootPart.Position)
    parryZone.Size = Vector3.new(
        CONFIG.ParryRadius * 2, 
        CONFIG.ParryRadius * 2, 
        CONFIG.ParryRadius * 2
    )
    
    -- Возвращаем цвет после подсветки
    if os.clock() > flashEndTime then
        parryZone.Color = CONFIG.IdleColor
        parryZone.Transparency = CONFIG.SphereTransparency
    end
    
    -- Обновляем маркеры игроков
    local playersInRange = getPlayersInRange()
    updatePlayerMarkers(playersInRange)
    
    -- Обновляем информацию
    local count = #playersInRange
    local nearestDist = math.huge
    for _, data in ipairs(playersInRange) do
        if data.Distance < nearestDist then
            nearestDist = data.Distance
        end
    end
    
    if count > 0 then
        infoLabel.Text = string.format(
            "Parry Zone: %d studs\nИгроков: %d | Ближ: %.1f",
            CONFIG.ParryRadius, count, nearestDist
        )
        infoLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    else
        infoLabel.Text = "Parry Zone: " .. CONFIG.ParryRadius .. " studs\nИгроков в зоне: 0"
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)
table.insert(connections, renderConn)

-- =============================================
-- ОБРАБОТКА СМЕРТИ / РЕСПАВНА
-- =============================================
local function onCharacterAdded(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    setupParryMonitoring()
    print("[ParryVis] Персонаж переподключён")
end

local charConn = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ УПРАВЛЕНИЯ
-- =============================================

-- Показать журнал парирований
_G.ParryLog = function()
    print("=== ЖУРНАЛ ПАРИРОВАНИЙ ===")
    print(string.format("Всего записей: %d", #parryLog))
    for i, entry in ipairs(parryLog) do
        local status = entry.Success and "✅" or "❌"
        print(string.format(
            "  %d. [%s] %s | Цель: %s | Реакция: %.0fмс",
            i, entry.Time, status, entry.Target, entry.ReactionTime * 1000
        ))
    end
    print("========================")
end

-- Изменить радиус
_G.SetParryRadius = function(radius)
    CONFIG.ParryRadius = radius
    print("[ParryVis] Радиус парирования изменён на: " .. radius)
end

-- Симулировать парирование (для теста)
_G.SimulateParry = function(success)
    success = success ~= false
    logParry(success, "SimulatedTarget", math.random() * 0.3)
    flashZone(success)
end

-- Очистка
_G.CleanupParryVisualizer = function()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    for _, marker in pairs(playerMarkers) do
        marker:Destroy()
    end
    playerMarkers = {}
    
    if parryZone then parryZone:Destroy() end
    
    print("[ParryVis] Визуализатор отключён и очищен")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
setupParryMonitoring()

print("============================================")
print("  ВИЗУАЛИЗАТОР ЗОНЫ ПАРИРОВАНИЯ ЗАПУЩЕН")
print("============================================")
print("Радиус: " .. CONFIG.ParryRadius .. " стадов")
print("")
print("Управление из CommandBar:")
print("  _G.SetParryRadius(15)     -- изменить радиус")
print("  _G.SimulateParry(true)    -- симулировать успешное парирование")
print("  _G.SimulateParry(false)   -- симулировать провал")
print("  _G.ParryLog()             -- показать журнал")
print("  _G.CleanupParryVisualizer() -- отключить визуализатор")
print("  _G.ParryVisualizerConfig  -- таблица настроек")
print("============================================")
