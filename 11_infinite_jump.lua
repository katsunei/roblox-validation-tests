--[[
    ============================================================
    СИМУЛЯЦИЯ БЕСКОНЕЧНЫХ ПРЫЖКОВ
    ============================================================
    Назначение: Позволяет прыгать в воздухе неограниченное
    количество раз (multi-jump / infinite jump).
    
    Что проверяет: Обнаруживает ли сервер многократные
    прыжки без контакта с землёй и ограничивает их.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    Enabled = true,
    ToggleKey = Enum.KeyCode.J,    -- Клавиша вкл/выкл
    JumpForce = 50,                -- Сила прыжка в воздухе
    MaxAirJumps = math.huge,       -- Лимит прыжков (math.huge = бесконечно)
}
_G.InfJumpConfig = CONFIG

-- =============================================
-- СОСТОЯНИЕ
-- =============================================
local connections = {}
local airJumpCount = 0
local totalAirJumps = 0
local sessionStart = os.clock()
local jumpLog = {}
local isGrounded = true

-- =============================================
-- ОПРЕДЕЛЕНИЕ КОНТАКТА С ЗЕМЛЁЙ
-- =============================================
local function checkGrounded()
    local rayOrigin = humanoidRootPart.Position
    local rayDirection = Vector3.new(0, -4, 0)  -- Чуть ниже ног
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    
    local result = workspace:Raycast(rayOrigin, rayDirection, params)
    return result ~= nil
end

-- =============================================
-- ОСНОВНАЯ ЛОГИКА БЕСКОНЕЧНОГО ПРЫЖКА
-- =============================================

-- Метод 1: Через JumpRequest
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if not CONFIG.Enabled then return end
    if not humanoid or humanoid.Health <= 0 then return end
    
    if airJumpCount < CONFIG.MaxAirJumps then
        -- Принудительно разрешаем прыжок
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        
        -- Дополнительная сила для воздушного прыжка
        if not checkGrounded() then
            airJumpCount = airJumpCount + 1
            totalAirJumps = totalAirJumps + 1
            
            -- Применяем вертикальный импульс
            humanoidRootPart.Velocity = Vector3.new(
                humanoidRootPart.Velocity.X,
                CONFIG.JumpForce,
                humanoidRootPart.Velocity.Z
            )
            
            local height = humanoidRootPart.Position.Y
            table.insert(jumpLog, {
                Time = os.date("%H:%M:%S"),
                AirJump = airJumpCount,
                Height = height,
                Elapsed = os.clock() - sessionStart,
            })
            
            print(string.format(
                "[InfJump] Воздушный прыжок #%d | Высота: %.1f | Серия: %d",
                totalAirJumps, height, airJumpCount
            ))
        end
    end
end)
table.insert(connections, jumpConn)

-- Метод 2: Отключаем Freefall state чтобы игра думала что мы на земле
local stateConn = humanoid.StateChanged:Connect(function(_, newState)
    if not CONFIG.Enabled then return end
    
    if newState == Enum.HumanoidStateType.Landed then
        -- Сброс счётчика при приземлении
        if airJumpCount > 0 then
            print(string.format(
                "[InfJump] Приземление после %d воздушных прыжков",
                airJumpCount
            ))
        end
        airJumpCount = 0
        isGrounded = true
    elseif newState == Enum.HumanoidStateType.Freefall then
        isGrounded = false
    end
end)
table.insert(connections, stateConn)

-- Мониторинг высоты
local heightConn = RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then return end
    
    -- Обновляем состояние grounded
    isGrounded = checkGrounded()
    if isGrounded then
        airJumpCount = 0
    end
end)
table.insert(connections, heightConn)

-- =============================================
-- ПЕРЕКЛЮЧЕНИЕ ПО КЛАВИШЕ
-- =============================================
local toggleConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.ToggleKey then
        CONFIG.Enabled = not CONFIG.Enabled
        print("[InfJump] " .. (CONFIG.Enabled and "✅ Включён" or "❌ Выключен"))
    end
end)
table.insert(connections, toggleConn)

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    airJumpCount = 0
    print("[InfJump] Персонаж обновлён")
end)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.InfJumpStats = function()
    print("=== СТАТИСТИКА БЕСКОНЕЧНЫХ ПРЫЖКОВ ===")
    print(string.format("  Время работы: %.0f сек", os.clock() - sessionStart))
    print(string.format("  Всего воздушных прыжков: %d", totalAirJumps))
    print(string.format("  Текущая серия: %d", airJumpCount))
    
    if #jumpLog > 0 then
        local maxHeight = 0
        local maxSeries = 0
        for _, entry in ipairs(jumpLog) do
            if entry.Height > maxHeight then maxHeight = entry.Height end
            if entry.AirJump > maxSeries then maxSeries = entry.AirJump end
        end
        print(string.format("  Максимальная высота: %.1f", maxHeight))
        print(string.format("  Максимальная серия: %d", maxSeries))
    end
    print("======================================")
end

_G.CleanupInfJump = function()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    CONFIG.Enabled = false
    print("[InfJump] Очищен и отключён")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  СИМУЛЯЦИЯ БЕСКОНЕЧНЫХ ПРЫЖКОВ ЗАПУЩЕНА")
print("============================================")
print("Переключение: клавиша " .. CONFIG.ToggleKey.Name)
print("Сила прыжка: " .. CONFIG.JumpForce)
print("")
print("Команды:")
print("  _G.InfJumpConfig.JumpForce = 80   -- сила")
print("  _G.InfJumpConfig.MaxAirJumps = 5  -- лимит")
print("  _G.InfJumpStats()                 -- статистика")
print("  _G.CleanupInfJump()               -- отключить")
print("============================================")
