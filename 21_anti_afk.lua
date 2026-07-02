--[[
    ============================================================
    АНТИ-АФК СИМУЛЯЦИЯ
    ============================================================
    Назначение: Имитирует постоянную активность игрока,
    чтобы обойти систему кика за бездействие.
    
    Что проверяет: Обнаруживает ли сервер синтетические
    паттерны ввода и отличает их от реальных.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    Enabled = true,
    Interval = 60,          -- Интервал действий (секунды)
    JumpAction = true,      -- Прыгать
    MoveAction = true,      -- Двигаться
    MouseAction = true,     -- Двигать мышь (VirtualInputManager)
    RandomDelay = true,     -- Добавлять случайную задержку
    MaxRandomDelay = 10,    -- Макс. случайная задержка (сек)
}
_G.AntiAFKConfig = CONFIG

-- =============================================
-- СОСТОЯНИЕ
-- =============================================
local connections = {}
local actionLog = {}
local totalActions = 0
local sessionStart = os.clock()
local isActive = true
local loopConn = nil

-- =============================================
-- ДЕЙСТВИЯ ПРОТИВ АФК
-- =============================================

local function performJump()
    if not humanoid or humanoid.Health <= 0 then return end
    humanoid.Jump = true
    return "Прыжок"
end

local function performMove()
    if not humanoidRootPart or not humanoidRootPart.Parent then return end
    -- Небольшое смещение вперёд-назад
    local offset = Vector3.new(
        math.random(-2, 2),
        0,
        math.random(-2, 2)
    )
    humanoidRootPart.CFrame = humanoidRootPart.CFrame + offset
    task.delay(0.5, function()
        if humanoidRootPart and humanoidRootPart.Parent then
            humanoidRootPart.CFrame = humanoidRootPart.CFrame - offset
        end
    end)
    return "Движение"
end

local function performMouseMove()
    -- VirtualInputManager доступен только в Studio
    local success, err = pcall(function()
        local x = math.random(100, 700)
        local y = math.random(100, 500)
        VirtualInputManager:SendMouseMoveEvent(x, y, workspace)
    end)
    
    if success then
        return "Движение мыши"
    else
        return "Мышь (недоступно)"
    end
end

local function performRandomAction()
    local actions = {}
    
    if CONFIG.JumpAction then table.insert(actions, performJump) end
    if CONFIG.MoveAction then table.insert(actions, performMove) end
    if CONFIG.MouseAction then table.insert(actions, performMouseMove) end
    
    if #actions == 0 then return "Нет действий" end
    
    -- Выполняем 1-2 случайных действия
    local results = {}
    local count = math.random(1, math.min(2, #actions))
    
    for i = 1, count do
        local idx = math.random(1, #actions)
        local result = actions[idx]()
        if result then
            table.insert(results, result)
        end
    end
    
    return table.concat(results, " + ")
end

-- =============================================
-- ОСНОВНОЙ ЦИКЛ
-- =============================================
local function startAntiAFK()
    if loopConn then return end
    
    print("[AntiAFK] 🔄 Цикл запущен, интервал: " .. CONFIG.Interval .. "с")
    
    -- Используем spawn вместо while для неблокирующего цикла
    task.spawn(function()
        while isActive do
            if not CONFIG.Enabled then
                wait(5)  -- Проверяем включение каждые 5 сек
                continue
            end
            
            -- Случайная задержка для имитации человека
            local delay = CONFIG.Interval
            if CONFIG.RandomDelay then
                delay = delay + math.random() * CONFIG.MaxRandomDelay
            end
            
            wait(delay)
            
            if not CONFIG.Enabled or not isActive then break end
            
            -- Выполняем действие
            local actionResult = performRandomAction()
            totalActions = totalActions + 1
            
            local entry = {
                Time = os.date("%H:%M:%S"),
                Action = actionResult,
                Number = totalActions,
                Elapsed = os.clock() - sessionStart,
            }
            table.insert(actionLog, entry)
            
            -- Ограничиваем размер лога
            if #actionLog > 200 then
                table.remove(actionLog, 1)
            end
            
            print(string.format(
                "[AntiAFK] #%d [%s] %s | Активно: %.0f мин",
                totalActions, entry.Time, actionResult,
                entry.Elapsed / 60
            ))
        end
    end)
end

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.AntiAFKStats = function()
    print("=== СТАТИСТИКА АНТИ-АФК ===")
    print(string.format("  Статус: %s", CONFIG.Enabled and "ВКЛ ✅" or "ВЫКЛ ❌"))
    print(string.format("  Всего действий: %d", totalActions))
    
    local elapsed = os.clock() - sessionStart
    print(string.format("  Время активности: %.0f мин (%.0f сек)", elapsed / 60, elapsed))
    print(string.format("  Интервал: %d сек (±%d случайных)", 
        CONFIG.Interval, CONFIG.RandomDelay and CONFIG.MaxRandomDelay or 0))
    
    if #actionLog > 0 then
        print("  Последние действия:")
        local start = math.max(1, #actionLog - 5)
        for i = start, #actionLog do
            local e = actionLog[i]
            print(string.format("    #%d [%s] %s", e.Number, e.Time, e.Action))
        end
    end
    print("===========================")
end

_G.StopAntiAFK = function()
    isActive = false
    CONFIG.Enabled = false
    print("[AntiAFK] Остановлен")
end

_G.StartAntiAFK = function()
    isActive = true
    CONFIG.Enabled = true
    startAntiAFK()
    print("[AntiAFK] Перезапущен")
end

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    print("[AntiAFK] Персонаж обновлён")
end)

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
startAntiAFK()

print("============================================")
print("  АНТИ-АФК СИМУЛЯЦИЯ ЗАПУЩЕНА")
print("============================================")
print(string.format("Интервал: %dс (+случайная задержка до %dс)", 
    CONFIG.Interval, CONFIG.MaxRandomDelay))
print("")
print("Команды:")
print("  _G.AntiAFKConfig.Interval = 30  -- интервал")
print("  _G.AntiAFKStats()               -- статистика")
print("  _G.StopAntiAFK()                -- остановить")
print("  _G.StartAntiAFK()               -- перезапустить")
print("============================================")
