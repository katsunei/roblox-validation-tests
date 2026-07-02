--[[
    ============================================================
    СИМУЛЯЦИЯ САМОУБИЙСТВА ПЕРСОНАЖА
    ============================================================
    Назначение: Мгновенно убивает своего персонажа различными
    способами для проверки серверной обработки смертей.
    
    Что проверяет: Как сервер обрабатывает самоубийство,
    валидирует ли причину смерти, корректен ли респавн.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- =============================================
-- СОСТОЯНИЕ
-- =============================================
local killLog = {}
local totalKills = 0
local sessionStart = os.clock()

-- =============================================
-- МЕТОД 1: Humanoid.Health = 0
-- =============================================
_G.Kill_Health = function()
    local char = LocalPlayer.Character
    if not char then print("[SelfKill] Нет персонажа!") return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then print("[SelfKill] Нет Humanoid!") return end
    
    local prevHealth = hum.Health
    hum.Health = 0
    totalKills = totalKills + 1
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Method = "Health = 0",
        PrevHealth = prevHealth,
        Success = hum.Health <= 0,
        Number = totalKills,
    }
    table.insert(killLog, entry)
    
    print(string.format("[SelfKill] #%d Метод: Health = 0 | HP: %.0f → %.0f | %s",
        totalKills, prevHealth, hum.Health,
        entry.Success and "✅ Успех" or "❌ Заблокировано"))
end

-- =============================================
-- МЕТОД 2: TakeDamage
-- =============================================
_G.Kill_TakeDamage = function()
    local char = LocalPlayer.Character
    if not char then print("[SelfKill] Нет персонажа!") return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then print("[SelfKill] Нет Humanoid!") return end
    
    local prevHealth = hum.Health
    hum:TakeDamage(math.huge)
    totalKills = totalKills + 1
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Method = "TakeDamage(∞)",
        PrevHealth = prevHealth,
        Success = hum.Health <= 0,
        Number = totalKills,
    }
    table.insert(killLog, entry)
    
    print(string.format("[SelfKill] #%d Метод: TakeDamage(∞) | HP: %.0f → %.0f | %s",
        totalKills, prevHealth, hum.Health,
        entry.Success and "✅ Успех" or "❌ Заблокировано"))
end

-- =============================================
-- МЕТОД 3: BreakJoints
-- =============================================
_G.Kill_BreakJoints = function()
    local char = LocalPlayer.Character
    if not char then print("[SelfKill] Нет персонажа!") return end
    
    totalKills = totalKills + 1
    
    local success, err = pcall(function()
        char:BreakJoints()
    end)
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Method = "BreakJoints",
        PrevHealth = 0,
        Success = success,
        Number = totalKills,
    }
    table.insert(killLog, entry)
    
    print(string.format("[SelfKill] #%d Метод: BreakJoints() | %s",
        totalKills, success and "✅ Успех" or "❌ Ошибка: " .. tostring(err)))
end

-- =============================================
-- МЕТОД 4: Удаление HumanoidRootPart
-- =============================================
_G.Kill_RemoveRoot = function()
    local char = LocalPlayer.Character
    if not char then print("[SelfKill] Нет персонажа!") return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then print("[SelfKill] Нет HumanoidRootPart!") return end
    
    totalKills = totalKills + 1
    
    local success, err = pcall(function()
        root:Destroy()
    end)
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Method = "RemoveRoot",
        PrevHealth = 0,
        Success = success,
        Number = totalKills,
    }
    table.insert(killLog, entry)
    
    print(string.format("[SelfKill] #%d Метод: Destroy HumanoidRootPart | %s",
        totalKills, success and "✅ Успех" or "❌ Ошибка: " .. tostring(err)))
end

-- =============================================
-- МЕТОД 5: Телепорт под карту (Void)
-- =============================================
_G.Kill_Void = function()
    local char = LocalPlayer.Character
    if not char then print("[SelfKill] Нет персонажа!") return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    totalKills = totalKills + 1
    
    local prevPos = root.Position
    root.CFrame = CFrame.new(0, -500, 0)
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Method = "Void (-500Y)",
        PrevHealth = 0,
        Success = true,
        Number = totalKills,
    }
    table.insert(killLog, entry)
    
    print(string.format("[SelfKill] #%d Метод: Телепорт в Void (Y=-500) | ✅",
        totalKills))
end

-- =============================================
-- МЕТОД 6: Через RemoteEvent (если есть)
-- =============================================
_G.Kill_Remote = function()
    totalKills = totalKills + 1
    
    local remoteNames = {"Kill", "Death", "SelfKill", "Damage", "TakeDamage"}
    local found = false
    
    local searchPaths = {
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage,
    }
    
    for _, container in ipairs(searchPaths) do
        if container then
            for _, name in ipairs(remoteNames) do
                local remote = container:FindFirstChild(name)
                if remote and remote:IsA("RemoteEvent") then
                    local success, err = pcall(function()
                        remote:FireServer(LocalPlayer, math.huge)
                    end)
                    print(string.format("[SelfKill] #%d Remote '%s' | %s",
                        totalKills, name, 
                        success and "✅ Отправлено" or "❌ " .. tostring(err)))
                    found = true
                end
            end
        end
    end
    
    if not found then
        print(string.format("[SelfKill] #%d ⚠️  Damage remote не найден", totalKills))
    end
end

-- =============================================
-- ЗАПУСК ВСЕХ МЕТОДОВ
-- =============================================
_G.TestAllKillMethods = function()
    print("╔════════════════════════════════════════════╗")
    print("║    ТЕСТИРОВАНИЕ ВСЕХ МЕТОДОВ САМОУБИЙСТВА   ║")
    print("╚════════════════════════════════════════════╝\n")
    
    local methods = {
        {"Health = 0", _G.Kill_Health},
        {"TakeDamage(∞)", _G.Kill_TakeDamage},
        {"BreakJoints", _G.Kill_BreakJoints},
        {"RemoveRoot", _G.Kill_RemoveRoot},
        {"Void", _G.Kill_Void},
        {"Remote", _G.Kill_Remote},
    }
    
    for i, method in ipairs(methods) do
        print(string.format("\n--- Метод %d/%d: %s ---", i, #methods, method[1]))
        
        -- Ждём респавна перед следующим методом
        if i > 1 then
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") 
                or LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                print("  Ожидание респавна...")
                LocalPlayer.CharacterAdded:Wait()
                wait(1)
            end
        end
        
        method[2]()
        wait(2)
    end
    
    print("\n✅ Все методы протестированы!")
    print("Используйте _G.KillReport() для отчёта.")
end

-- =============================================
-- ОТЧЁТ
-- =============================================
_G.KillReport = function()
    print("=== ОТЧЁТ ПО САМОУБИЙСТВАМ ===")
    print(string.format("  Всего попыток: %d", totalKills))
    
    if #killLog > 0 then
        print(string.format("\n  %-8s | %-20s | %-8s",
            "Время", "Метод", "Результат"))
        print("  " .. string.rep("-", 42))
        
        for _, e in ipairs(killLog) do
            print(string.format("  %-8s | %-20s | %-8s",
                e.Time, e.Method, e.Success and "✅" or "❌"))
        end
    end
    print("==============================")
end

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    local respawnTime = os.clock() - sessionStart
    print(string.format("[SelfKill] Респавн произошёл (%.1fс от старта)", respawnTime))
end)

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  СИМУЛЯЦИЯ САМОУБИЙСТВА ЗАПУЩЕНА")
print("============================================")
print("Методы:")
print("  _G.Kill_Health()         -- Health = 0")
print("  _G.Kill_TakeDamage()     -- TakeDamage(∞)")
print("  _G.Kill_BreakJoints()    -- BreakJoints()")
print("  _G.Kill_RemoveRoot()     -- Удаление RootPart")
print("  _G.Kill_Void()           -- Телепорт в Void")
print("  _G.Kill_Remote()         -- Через RemoteEvent")
print("  _G.TestAllKillMethods()  -- ВСЕ методы")
print("  _G.KillReport()          -- отчёт")
print("============================================")
