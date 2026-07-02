--[[
    ============================================================
    ТЕЛЕПОРТАЦИЯ К ИГРОКУ
    ============================================================
    Назначение: Мгновенно перемещает персонажа к другому
    игроку, проверяя серверную валидацию позиции.
    
    Что проверяет: Обнаруживает ли сервер невозможные
    перемещения (телепортацию на большие расстояния).
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
_G.TeleportTarget = nil       -- Имя игрока для телепортации
_G.TeleportFollow = false     -- Режим преследования (каждый кадр)
_G.TeleportOffset = Vector3.new(5, 0, 0)  -- Смещение от цели

local connections = {}
local teleportLog = {}
local totalTeleports = 0
local sessionStart = os.clock()

-- =============================================
-- СПИСОК ДОСТУПНЫХ ИГРОКОВ
-- =============================================
_G.ListPlayers = function()
    print("=== ДОСТУПНЫЕ ИГРОКИ ===")
    local myPos = humanoidRootPart.Position
    
    for i, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myPos).Magnitude
                print(string.format("  %d. %s (%.0f стадов)", i, player.Name, dist))
            else
                print(string.format("  %d. %s (нет персонажа)", i, player.Name))
            end
        end
    end
    
    if #Players:GetPlayers() <= 1 then
        print("  (нет других игроков на сервере)")
    end
    
    print("========================")
    print("Использование: _G.TeleportTarget = 'ИмяИгрока'")
    print("Затем:         _G.TeleportNow()")
end

-- =============================================
-- ТЕЛЕПОРТАЦИЯ
-- =============================================
_G.TeleportNow = function(targetName)
    targetName = targetName or _G.TeleportTarget
    
    if not targetName then
        print("[Teleport] ❌ Цель не указана! Установите _G.TeleportTarget = 'Имя'")
        print("           Или: _G.TeleportNow('ИмяИгрока')")
        _G.ListPlayers()
        return
    end
    
    local targetPlayer = Players:FindFirstChild(targetName)
    if not targetPlayer then
        print("[Teleport] ❌ Игрок '" .. targetName .. "' не найден!")
        return
    end
    
    if not targetPlayer.Character then
        print("[Teleport] ❌ У игрока нет персонажа!")
        return
    end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        print("[Teleport] ❌ HumanoidRootPart цели не найден!")
        return
    end
    
    local startPos = humanoidRootPart.Position
    local targetPos = targetRoot.CFrame * CFrame.new(_G.TeleportOffset)
    local distance = (targetPos.Position - startPos).Magnitude
    
    -- Телепортация
    humanoidRootPart.CFrame = targetPos
    
    totalTeleports = totalTeleports + 1
    
    local entry = {
        Time = os.date("%H:%M:%S"),
        Target = targetName,
        Distance = distance,
        From = startPos,
        To = targetPos.Position,
        Number = totalTeleports,
    }
    table.insert(teleportLog, entry)
    
    print(string.format(
        "[Teleport] ✅ #%d → %s | Дистанция: %.0f стадов",
        totalTeleports, targetName, distance
    ))
    print(string.format(
        "  Из: (%.0f, %.0f, %.0f) → В: (%.0f, %.0f, %.0f)",
        startPos.X, startPos.Y, startPos.Z,
        targetPos.Position.X, targetPos.Position.Y, targetPos.Position.Z
    ))
    
    if distance > 50 then
        print("  ⚠️  Сервер должен обнаружить телепорт на " .. math.floor(distance) .. " стадов!")
    end
end

-- =============================================
-- РЕЖИМ ПРЕСЛЕДОВАНИЯ (FOLLOW)
-- =============================================
local followConn = nil

_G.TeleportFollow = function(targetName, enabled)
    _G.TeleportTarget = targetName or _G.TeleportTarget
    
    if enabled == false then
        if followConn then
            followConn:Disconnect()
            followConn = nil
        end
        print("[Teleport] Режим преследования ВЫКЛ")
        return
    end
    
    if not _G.TeleportTarget then
        print("[Teleport] ❌ Установите цель!")
        return
    end
    
    -- Отключаем предыдущий
    if followConn then
        followConn:Disconnect()
    end
    
    print("[Teleport] 🔄 Режим преследования ВКЛ для: " .. _G.TeleportTarget)
    
    followConn = RunService.Heartbeat:Connect(function()
        local target = Players:FindFirstChild(_G.TeleportTarget)
        if target and target.Character then
            local root = target.Character:FindFirstChild("HumanoidRootPart")
            if root and humanoidRootPart and humanoidRootPart.Parent then
                humanoidRootPart.CFrame = root.CFrame * CFrame.new(_G.TeleportOffset)
            end
        end
    end)
    table.insert(connections, followConn)
end

-- =============================================
-- ТЕЛЕПОРТАЦИЯ ПО КООРДИНАТАМ
-- =============================================
_G.TeleportTo = function(x, y, z)
    if not x or not y or not z then
        print("[Teleport] Использование: _G.TeleportTo(100, 50, 200)")
        return
    end
    
    local startPos = humanoidRootPart.Position
    local targetPos = Vector3.new(x, y, z)
    local distance = (targetPos - startPos).Magnitude
    
    humanoidRootPart.CFrame = CFrame.new(targetPos)
    totalTeleports = totalTeleports + 1
    
    print(string.format(
        "[Teleport] ✅ #%d → Координаты (%.0f, %.0f, %.0f) | Дистанция: %.0f",
        totalTeleports, x, y, z, distance
    ))
end

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    print("[Teleport] Персонаж обновлён")
end)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.TeleportStats = function()
    print("=== СТАТИСТИКА ТЕЛЕПОРТАЦИИ ===")
    print(string.format("  Всего телепортаций: %d", totalTeleports))
    print(string.format("  Время работы: %.0f сек", os.clock() - sessionStart))
    if #teleportLog > 0 then
        print("  Последние:")
        local start = math.max(1, #teleportLog - 5)
        for i = start, #teleportLog do
            local e = teleportLog[i]
            print(string.format("    #%d [%s] → %s (%.0f стадов)",
                e.Number, e.Time, e.Target, e.Distance))
        end
    end
    print("===============================")
end

_G.CleanupTeleport = function()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    if followConn then
        followConn:Disconnect()
        followConn = nil
    end
    print("[Teleport] Полностью отключён")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  ТЕЛЕПОРТАЦИЯ К ИГРОКУ ЗАПУЩЕНА")
print("============================================")
print("Команды:")
print("  _G.ListPlayers()                    -- список игроков")
print("  _G.TeleportTarget = 'Name'          -- установить цель")
print("  _G.TeleportNow()                    -- телепортироваться")
print("  _G.TeleportNow('Name')              -- телепорт к конкретному")
print("  _G.TeleportFollow('Name')           -- преследование")
print("  _G.TeleportFollow(nil, false)       -- стоп преследование")
print("  _G.TeleportTo(x, y, z)              -- телепорт по координатам")
print("  _G.TeleportOffset = Vector3.new(5,0,0) -- смещение")
print("  _G.TeleportStats()                  -- статистика")
print("  _G.CleanupTeleport()                -- отключить")
print("============================================")
