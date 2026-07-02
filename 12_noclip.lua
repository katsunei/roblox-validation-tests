--[[
    ============================================================
    СИМУЛЯЦИЯ NOCLIP
    ============================================================
    Назначение: Отключает коллизию персонажа, позволяя
    проходить сквозь стены и объекты.
    
    Что проверяет: Фиксирует ли сервер перемещение персонажа
    сквозь твёрдые объекты (невозможные позиции).
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    Enabled = false,
    ToggleKey = Enum.KeyCode.N,
}
_G.NoclipConfig = CONFIG

-- =============================================
-- СОСТОЯНИЕ
-- =============================================
local connections = {}
local noclipLog = {}
local sessionStart = os.clock()
local wallPassCount = 0

-- =============================================
-- ОСНОВНАЯ ЛОГИКА NOCLIP
-- =============================================

-- Каждый кадр отключаем коллизию для всех частей персонажа
local noclipConn = RunService.Stepped:Connect(function()
    if not CONFIG.Enabled then return end
    if not character or not character.Parent then return end
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)
table.insert(connections, noclipConn)

-- Детектор прохождения сквозь стены
local wallDetectConn = RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then return end
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- Рейкаст вперёд для обнаружения стен, через которые проходим
    local lookDir = rootPart.CFrame.LookVector * 3
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    
    local result = workspace:Raycast(rootPart.Position, lookDir, params)
    
    if result and result.Instance then
        -- Мы рядом со стеной и можем пройти сквозь неё
        local dist = (result.Position - rootPart.Position).Magnitude
        if dist < 2 then
            wallPassCount = wallPassCount + 1
            if wallPassCount % 30 == 1 then  -- Логируем каждые ~30 касаний
                table.insert(noclipLog, {
                    Time = os.date("%H:%M:%S"),
                    WallName = result.Instance.Name,
                    Position = rootPart.Position,
                    Passes = wallPassCount,
                })
                print(string.format(
                    "[Noclip] Проход сквозь: '%s' | Позиция: (%.0f, %.0f, %.0f) | Всего: %d",
                    result.Instance.Name,
                    rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z,
                    wallPassCount
                ))
            end
        end
    end
end)
table.insert(connections, wallDetectConn)

-- =============================================
-- ПЕРЕКЛЮЧЕНИЕ ПО КЛАВИШЕ
-- =============================================
local toggleConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.ToggleKey then
        CONFIG.Enabled = not CONFIG.Enabled
        
        if CONFIG.Enabled then
            print("[Noclip] ✅ Включён — коллизия отключена")
        else
            -- Восстанавливаем коллизию
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
            print("[Noclip] ❌ Выключен — коллизия восстановлена")
        end
    end
end)
table.insert(connections, toggleConn)

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    print("[Noclip] Персонаж обновлён")
end)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.NoclipStats = function()
    print("=== СТАТИСТИКА NOCLIP ===")
    print(string.format("  Статус: %s", CONFIG.Enabled and "ВКЛ" or "ВЫКЛ"))
    print(string.format("  Проходов сквозь стены: %d", wallPassCount))
    print(string.format("  Время работы: %.0f сек", os.clock() - sessionStart))
    if #noclipLog > 0 then
        print("  Последние проходы:")
        local start = math.max(1, #noclipLog - 5)
        for i = start, #noclipLog do
            local e = noclipLog[i]
            print(string.format("    [%s] '%s' @ (%.0f,%.0f,%.0f)",
                e.Time, e.WallName, e.Position.X, e.Position.Y, e.Position.Z))
        end
    end
    print("=========================")
end

_G.CleanupNoclip = function()
    CONFIG.Enabled = false
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    print("[Noclip] Полностью очищен, коллизия восстановлена")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  СИМУЛЯЦИЯ NOCLIP ЗАПУЩЕНА")
print("============================================")
print("Переключение: клавиша " .. CONFIG.ToggleKey.Name)
print("Статус: " .. (CONFIG.Enabled and "ВКЛ" or "ВЫКЛ (нажмите N)"))
print("")
print("Команды:")
print("  _G.NoclipStats()       -- статистика")
print("  _G.CleanupNoclip()     -- отключить полностью")
print("============================================")
