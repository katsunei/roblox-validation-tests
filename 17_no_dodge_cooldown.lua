--[[
    ============================================================
    СИМУЛЯЦИЯ ОТКЛЮЧЕНИЯ КУЛДАУНА НА УКЛОНЕНИЕ
    ============================================================
    Назначение: Позволяет уклоняться без задержек,
    отправляя dodge-запросы с минимальным интервалом.
    
    Что проверяет: Применяет ли сервер кулдаун на dodge
    независимо от клиента.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    Enabled = true,
    SpamCount = 30,           -- Количество dodge-запросов в тесте
    SpamInterval = 0.01,      -- Минимальный интервал (почти мгновенно)
    DodgeKey = Enum.KeyCode.Q, -- Клавиша для ручного спама
}
_G.NoDodgeCDConfig = CONFIG

local connections = {}
local dodgeLog = {}
local totalDodges = 0
local sessionStart = os.clock()

-- =============================================
-- ПОИСК DODGE REMOTE
-- =============================================
local function findDodgeRemote()
    local searchNames = {"Dodge", "Roll", "Dash", "Evade", "DodgeRoll", "Combat_Dodge"}
    local searchPaths = {
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage,
    }
    
    for _, container in ipairs(searchPaths) do
        if container then
            for _, name in ipairs(searchNames) do
                local remote = container:FindFirstChild(name)
                if remote and remote:IsA("RemoteEvent") then
                    return remote, name
                end
            end
        end
    end
    
    return nil, nil
end

local dodgeRemote, remoteName = findDodgeRemote()

-- =============================================
-- СБРОС КЛИЕНТСКИХ КУЛДАУНОВ
-- =============================================
local function resetClientCooldowns()
    -- Сброс через _G
    local cooldownKeys = {
        "DodgeCooldown", "dodgeCooldown", "canDodge", "CanDodge",
        "DodgeReady", "dodgeReady", "RollCooldown", "DashCooldown",
    }
    
    for _, key in ipairs(cooldownKeys) do
        if _G[key] ~= nil then
            if type(_G[key]) == "boolean" then
                _G[key] = true
            elseif type(_G[key]) == "number" then
                _G[key] = 0
            end
        end
    end
    
    -- Сброс атрибутов на персонаже
    local char = LocalPlayer.Character
    if char then
        for _, attrName in ipairs({"DodgeCooldown", "CanDodge", "DodgeReady"}) do
            if char:GetAttribute(attrName) ~= nil then
                local val = char:GetAttribute(attrName)
                if type(val) == "boolean" then
                    char:SetAttribute(attrName, true)
                elseif type(val) == "number" then
                    char:SetAttribute(attrName, 0)
                end
            end
        end
    end
end

-- =============================================
-- ТЕСТ СПАМА DODGE
-- =============================================
_G.SpamDodge = function(count, interval)
    count = count or CONFIG.SpamCount
    interval = interval or CONFIG.SpamInterval
    
    print(string.format("\n▶ СПАМ DODGE: %d запросов, интервал %.3fс", count, interval))
    print(string.rep("-", 50))
    
    local startTime = os.clock()
    local sent = 0
    local errors = 0
    
    for i = 1, count do
        -- Сбрасываем клиентские кулдауны перед каждой попыткой
        resetClientCooldowns()
        
        if dodgeRemote then
            local success, err = pcall(function()
                dodgeRemote:FireServer()
            end)
            
            if success then
                sent = sent + 1
            else
                errors = errors + 1
            end
        else
            sent = sent + 1  -- Симуляция
        end
        
        totalDodges = totalDodges + 1
        
        if i % 10 == 0 then
            print(string.format("  [%d/%d] Отправлено, ошибок: %d", i, count, errors))
        end
        
        if interval > 0 and i < count then
            wait(interval)
        end
    end
    
    local elapsed = os.clock() - startTime
    local rate = sent / elapsed
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Count = sent,
        Errors = errors,
        Interval = interval,
        Elapsed = elapsed,
        Rate = rate,
    }
    table.insert(dodgeLog, entry)
    
    print(string.rep("-", 50))
    print(string.format("  Отправлено: %d | Ошибок: %d", sent, errors))
    print(string.format("  Время: %.3fс | Скорость: %.1f dodge/с", elapsed, rate))
    
    if not dodgeRemote then
        print("  ⚠️  Dodge Remote не найден — симуляция")
    end
    
    print(string.format("  Ожидание: сервер должен принять ≤1 dodge за кулдаун"))
    print("")
    
    return entry
end

-- =============================================
-- МОНИТОРИНГ ПО КЛАВИШЕ
-- =============================================
local keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not CONFIG.Enabled then return end
    
    if input.KeyCode == CONFIG.DodgeKey then
        resetClientCooldowns()
        
        if dodgeRemote then
            pcall(function()
                dodgeRemote:FireServer()
            end)
        end
        
        totalDodges = totalDodges + 1
        print(string.format("[NoDodgeCD] Dodge #%d (кулдаун обойдён)", totalDodges))
    end
end)
table.insert(connections, keyConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.DodgeCDStats = function()
    print("=== СТАТИСТИКА DODGE БЕЗ КУЛДАУНА ===")
    print(string.format("  Remote: %s", remoteName or "НЕ НАЙДЕН"))
    print(string.format("  Всего dodge: %d", totalDodges))
    print(string.format("  Время работы: %.0f сек", os.clock() - sessionStart))
    if #dodgeLog > 0 then
        print("  Тесты:")
        for i, e in ipairs(dodgeLog) do
            print(string.format("    #%d [%s] %d dodge, %.1f/с", 
                i, e.Time, e.Count, e.Rate))
        end
    end
    print("=======================================")
end

_G.CleanupNoDodgeCD = function()
    CONFIG.Enabled = false
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    print("[NoDodgeCD] Полностью отключён")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  СИМУЛЯЦИЯ ОТКЛЮЧЕНИЯ DODGE КУЛДАУНА")
print("============================================")
print(string.format("Remote: %s", remoteName or "НЕ НАЙДЕН (симуляция)"))
print(string.format("Клавиша: %s", CONFIG.DodgeKey.Name))
print("")
print("Команды:")
print("  _G.SpamDodge(30, 0.01)     -- спам 30 dodge")
print("  _G.SpamDodge(50, 0)        -- спам 50 без задержки")
print("  _G.DodgeCDStats()          -- статистика")
print("  _G.CleanupNoDodgeCD()      -- отключить")
print("============================================")
