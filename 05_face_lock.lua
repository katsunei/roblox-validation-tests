--[[
    ============================================================
    СИМУЛЯЦИЯ FACE LOCK (АИМЛОК)
    ============================================================
    Назначение: Каждый кадр поворачивает персонажа лицом
    к ближайшему игроку.
    
    Что проверяет: Обнаруживает ли сервер неестественное
    вращение (мгновенные развороты, идеальное отслеживание).
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    Enabled = true,
    MaxRange = 100,              -- Макс. дистанция отслеживания (стады)
    SmoothMode = false,          -- true = плавный поворот, false = мгновенный
    SmoothSpeed = 15,            -- Скорость плавного поворота (только если SmoothMode=true)
    LockSpecificTarget = nil,    -- Имя конкретного игрока или nil для ближайшего
    ToggleKey = Enum.KeyCode.G,  -- Клавиша вкл/выкл
    ShowTargetLine = true,       -- Показывать линию к цели
    LogTargetSwitches = true,    -- Логировать смену целей
}

_G.FaceLockConfig = CONFIG

-- =============================================
-- СОСТОЯНИЕ
-- =============================================
local currentTarget = nil
local previousTarget = nil
local targetLine = nil  -- Визуальная линия к цели
local connections = {}
local switchCount = 0
local startTime = os.clock()
local rotationLog = {}  -- Лог вращений для анализа

-- =============================================
-- ВИЗУАЛЬНАЯ ЛИНИЯ К ЦЕЛИ
-- =============================================
local function createTargetLine()
    if targetLine then targetLine:Destroy() end
    
    if not CONFIG.ShowTargetLine then return end
    
    -- Создаём Beam между игроком и целью
    local att0 = Instance.new("Attachment")
    att0.Name = "FaceLock_Att0"
    att0.Parent = humanoidRootPart
    
    local att1 = Instance.new("Attachment")
    att1.Name = "FaceLock_Att1"
    
    local beam = Instance.new("Beam")
    beam.Name = "FaceLock_Beam"
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    beam.Transparency = NumberSequence.new(0.3)
    beam.Width0 = 0.15
    beam.Width1 = 0.15
    beam.FaceCamera = true
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    
    targetLine = {Att0 = att0, Att1 = att1, Beam = beam}
    return att1 -- Возвращаем второй аттачмент для привязки к цели
end

local function updateTargetLine(targetRoot)
    if not CONFIG.ShowTargetLine or not targetLine then return end
    
    if targetRoot and targetRoot.Parent then
        targetLine.Att1.Parent = targetRoot
        targetLine.Beam.Parent = humanoidRootPart
        targetLine.Beam.Enabled = true
    else
        targetLine.Beam.Enabled = false
    end
end

local function destroyTargetLine()
    if targetLine then
        if targetLine.Att0 then targetLine.Att0:Destroy() end
        if targetLine.Att1 then targetLine.Att1:Destroy() end
        if targetLine.Beam then targetLine.Beam:Destroy() end
        targetLine = nil
    end
end

-- =============================================
-- ПОИСК ЦЕЛИ
-- =============================================
local function findNearestPlayer()
    -- Если задана конкретная цель
    if CONFIG.LockSpecificTarget then
        local target = Players:FindFirstChild(CONFIG.LockSpecificTarget)
        if target and target.Character then
            local root = target.Character:FindFirstChild("HumanoidRootPart")
            if root then
                return target, root
            end
        end
        return nil, nil
    end
    
    -- Поиск ближайшего игрока
    local nearestPlayer = nil
    local nearestRoot = nil
    local nearestDist = CONFIG.MaxRange
    local myPos = humanoidRootPart.Position
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChild("Humanoid")
            
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myPos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = player
                    nearestRoot = root
                end
            end
        end
    end
    
    return nearestPlayer, nearestRoot
end

-- =============================================
-- ОСНОВНОЙ ЦИКЛ
-- =============================================
local function faceLockUpdate()
    if not CONFIG.Enabled then return end
    if not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    local targetPlayer, targetRoot = findNearestPlayer()
    
    if not targetPlayer or not targetRoot then
        currentTarget = nil
        updateTargetLine(nil)
        return
    end
    
    -- Логируем смену цели
    if targetPlayer ~= previousTarget then
        switchCount = switchCount + 1
        if CONFIG.LogTargetSwitches then
            local dist = (targetRoot.Position - humanoidRootPart.Position).Magnitude
            print(string.format(
                "[FaceLock] Цель #%d: %s (%.1f стадов)",
                switchCount, targetPlayer.Name, dist
            ))
        end
        previousTarget = targetPlayer
        currentTarget = targetPlayer
    end
    
    -- Вычисляем направление к цели
    local direction = (targetRoot.Position - humanoidRootPart.Position)
    direction = Vector3.new(direction.X, 0, direction.Z) -- Только горизонтальный поворот
    
    if direction.Magnitude < 0.01 then return end
    
    local targetCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + direction)
    
    -- Записываем данные о вращении для анализа
    local prevLookVector = humanoidRootPart.CFrame.LookVector
    local newLookVector = targetCFrame.LookVector
    local angleDelta = math.acos(math.clamp(prevLookVector:Dot(newLookVector), -1, 1))
    
    table.insert(rotationLog, {
        Time = os.clock() - startTime,
        AngleDelta = math.deg(angleDelta),
        Target = targetPlayer.Name,
        Distance = (targetRoot.Position - humanoidRootPart.Position).Magnitude
    })
    
    -- Ограничиваем размер лога
    if #rotationLog > 500 then
        table.remove(rotationLog, 1)
    end
    
    -- Применяем поворот
    if CONFIG.SmoothMode then
        -- Плавный поворот (lerp)
        humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(
            targetCFrame, 
            math.clamp(CONFIG.SmoothSpeed * (1/60), 0, 1)
        )
    else
        -- Мгновенный поворот (подозрительный для сервера!)
        humanoidRootPart.CFrame = targetCFrame
    end
    
    -- Обновляем визуальную линию
    updateTargetLine(targetRoot)
end

local renderConn = RunService.RenderStepped:Connect(faceLockUpdate)
table.insert(connections, renderConn)

-- =============================================
-- ПЕРЕКЛЮЧЕНИЕ ПО КЛАВИШЕ
-- =============================================
local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == CONFIG.ToggleKey then
        CONFIG.Enabled = not CONFIG.Enabled
        if CONFIG.Enabled then
            print("[FaceLock] ✅ Включён")
            createTargetLine()
        else
            print("[FaceLock] ❌ Выключен")
            destroyTargetLine()
            currentTarget = nil
        end
    end
end)
table.insert(connections, inputConn)

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    destroyTargetLine()
    if CONFIG.Enabled and CONFIG.ShowTargetLine then
        createTargetLine()
    end
    print("[FaceLock] Персонаж переподключён")
end)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ УПРАВЛЕНИЯ
-- =============================================

-- Статистика вращений
_G.FaceLockStats = function()
    print("=== СТАТИСТИКА FACE LOCK ===")
    print(string.format("Время работы: %.1f сек", os.clock() - startTime))
    print(string.format("Смен цели: %d", switchCount))
    print(string.format("Записей вращения: %d", #rotationLog))
    
    if #rotationLog > 0 then
        local totalAngle = 0
        local maxAngle = 0
        local instantTurns = 0  -- Повороты > 90° за кадр
        
        for _, entry in ipairs(rotationLog) do
            totalAngle = totalAngle + entry.AngleDelta
            if entry.AngleDelta > maxAngle then
                maxAngle = entry.AngleDelta
            end
            if entry.AngleDelta > 90 then
                instantTurns = instantTurns + 1
            end
        end
        
        print(string.format("Средний поворот: %.1f°/кадр", totalAngle / #rotationLog))
        print(string.format("Максимальный поворот: %.1f°", maxAngle))
        print(string.format("Мгновенных разворотов (>90°): %d", instantTurns))
        print(string.format("⚠️  Аномальность: %s",
            instantTurns > 10 and "ВЫСОКАЯ (сервер должен обнаружить)" or "НИЗКАЯ"
        ))
    end
    print("============================")
end

-- Установить конкретную цель
_G.FaceLockTarget = function(playerName)
    CONFIG.LockSpecificTarget = playerName
    if playerName then
        print("[FaceLock] Цель зафиксирована: " .. playerName)
    else
        print("[FaceLock] Режим: ближайший игрок")
    end
end

-- Переключить режим плавности
_G.FaceLockSmooth = function(enabled)
    CONFIG.SmoothMode = enabled
    print("[FaceLock] Плавный режим: " .. tostring(enabled))
end

-- Полная очистка
_G.CleanupFaceLock = function()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    destroyTargetLine()
    CONFIG.Enabled = false
    print("[FaceLock] Полностью отключён и очищен")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
if CONFIG.ShowTargetLine then
    createTargetLine()
end

print("============================================")
print("  СИМУЛЯЦИЯ FACE LOCK ЗАПУЩЕНА")
print("============================================")
print("Режим: " .. (CONFIG.SmoothMode and "Плавный" or "Мгновенный (подозрительный)"))
print("Дальность: " .. CONFIG.MaxRange .. " стадов")
print("Переключение: клавиша " .. CONFIG.ToggleKey.Name)
print("")
print("Управление из CommandBar:")
print("  _G.FaceLockTarget('PlayerName') -- цель")
print("  _G.FaceLockTarget(nil)          -- ближайший")
print("  _G.FaceLockSmooth(true)         -- плавный режим")
print("  _G.FaceLockStats()              -- статистика")
print("  _G.CleanupFaceLock()            -- отключить")
print("============================================")
