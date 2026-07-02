--[[
    ============================================================
    СИМУЛЯЦИЯ ИММУНИТЕТА К ОГЛУШЕНИЮ
    ============================================================
    Назначение: Игнорирует эффекты стана/оглушения,
    мгновенно восстанавливая контроль над персонажем.
    
    Что проверяет: Применяет ли сервер стан независимо
    от клиентского состояния.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- =============================================
-- НАСТРОЙКИ
-- =============================================
local CONFIG = {
    Enabled = true,
    RestoreWalkSpeed = 16,   -- Стандартная скорость ходьбы
    RestoreJumpPower = 50,   -- Стандартная сила прыжка
}
_G.StunImmunityConfig = CONFIG

local connections = {}
local stunBlockCount = 0
local sessionStart = os.clock()
local stunLog = {}

-- Сохраняем нормальные значения
local normalWalkSpeed = humanoid.WalkSpeed
local normalJumpPower = humanoid.JumpPower

-- =============================================
-- МОНИТОРИНГ ОГЛУШЕНИЯ
-- =============================================

-- Метод 1: Мониторинг WalkSpeed/JumpPower = 0 (типичный стан)
local walkConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
    if not CONFIG.Enabled then return end
    if humanoid.WalkSpeed <= 0 then
        stunBlockCount = stunBlockCount + 1
        local stunTime = os.clock()
        
        task.defer(function()
            humanoid.WalkSpeed = CONFIG.RestoreWalkSpeed
        end)
        
        table.insert(stunLog, {
            Time = os.date("%H:%M:%S"),
            Type = "WalkSpeed=0",
            Number = stunBlockCount,
        })
        
        print(string.format(
            "[StunImmunity] Стан #%d заблокирован (WalkSpeed→0), восстановлено до %d",
            stunBlockCount, CONFIG.RestoreWalkSpeed
        ))
    end
end)
table.insert(connections, walkConn)

local jumpConn = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
    if not CONFIG.Enabled then return end
    if humanoid.JumpPower <= 0 then
        task.defer(function()
            humanoid.JumpPower = CONFIG.RestoreJumpPower
        end)
        print("[StunImmunity] JumpPower восстановлен")
    end
end)
table.insert(connections, jumpConn)

-- Метод 2: Мониторинг атрибутов стана
local function monitorStunAttributes()
    local stunAttrNames = {"Stunned", "IsStunned", "Stun", "Frozen", "Disabled", "CC"}
    
    for _, attrName in ipairs(stunAttrNames) do
        -- Проверяем на персонаже
        if character:GetAttribute(attrName) ~= nil then
            local conn = character:GetAttributeChangedSignal(attrName):Connect(function()
                if not CONFIG.Enabled then return end
                local val = character:GetAttribute(attrName)
                if val == true or (type(val) == "number" and val > 0) then
                    stunBlockCount = stunBlockCount + 1
                    character:SetAttribute(attrName, type(val) == "boolean" and false or 0)
                    
                    table.insert(stunLog, {
                        Time = os.date("%H:%M:%S"),
                        Type = "Attr:" .. attrName,
                        Number = stunBlockCount,
                    })
                    
                    print(string.format(
                        "[StunImmunity] Стан #%d заблокирован (атрибут '%s')",
                        stunBlockCount, attrName
                    ))
                end
            end)
            table.insert(connections, conn)
            print("[StunImmunity] Мониторинг атрибута: " .. attrName)
        end
        
        -- Проверяем на LocalPlayer
        if LocalPlayer:GetAttribute(attrName) ~= nil then
            local conn = LocalPlayer:GetAttributeChangedSignal(attrName):Connect(function()
                if not CONFIG.Enabled then return end
                local val = LocalPlayer:GetAttribute(attrName)
                if val == true or (type(val) == "number" and val > 0) then
                    stunBlockCount = stunBlockCount + 1
                    LocalPlayer:SetAttribute(attrName, type(val) == "boolean" and false or 0)
                    print(string.format("[StunImmunity] Стан Player.%s заблокирован", attrName))
                end
            end)
            table.insert(connections, conn)
        end
    end
end

-- Метод 3: Мониторинг BoolValue
local function monitorStunValues()
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BoolValue") then
            local name = descendant.Name:lower()
            if name:find("stun") or name:find("frozen") or name:find("disable") then
                local conn = descendant.Changed:Connect(function(value)
                    if not CONFIG.Enabled then return end
                    if value == true then
                        stunBlockCount = stunBlockCount + 1
                        descendant.Value = false
                        print(string.format(
                            "[StunImmunity] BoolValue '%s' сброшен (#%d)",
                            descendant.Name, stunBlockCount
                        ))
                    end
                end)
                table.insert(connections, conn)
                print("[StunImmunity] Мониторинг BoolValue: " .. descendant.Name)
            end
        end
    end
end

-- Метод 4: Принудительное восстановление каждый кадр
local heartbeatConn = RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then return end
    if not humanoid or humanoid.Health <= 0 then return end
    
    -- Восстанавливаем скорость если заблокирована
    if humanoid.WalkSpeed <= 0 then
        humanoid.WalkSpeed = CONFIG.RestoreWalkSpeed
    end
    if humanoid.JumpPower <= 0 then
        humanoid.JumpPower = CONFIG.RestoreJumpPower
    end
    
    -- Разрешаем все типы движения
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
end)
table.insert(connections, heartbeatConn)

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    normalWalkSpeed = humanoid.WalkSpeed
    normalJumpPower = humanoid.JumpPower
    monitorStunAttributes()
    monitorStunValues()
    print("[StunImmunity] Персонаж обновлён")
end)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.StunImmunityStats = function()
    print("=== СТАТИСТИКА ИММУНИТЕТА К СТАНУ ===")
    print(string.format("  Статус: %s", CONFIG.Enabled and "ВКЛ" or "ВЫКЛ"))
    print(string.format("  Заблокировано станов: %d", stunBlockCount))
    print(string.format("  Время работы: %.0f сек", os.clock() - sessionStart))
    if #stunLog > 0 then
        print("  Последние блокировки:")
        local start = math.max(1, #stunLog - 5)
        for i = start, #stunLog do
            local e = stunLog[i]
            print(string.format("    #%d [%s] Тип: %s", e.Number, e.Time, e.Type))
        end
    end
    print("=====================================")
end

_G.CleanupStunImmunity = function()
    CONFIG.Enabled = false
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    print("[StunImmunity] Полностью отключён")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
monitorStunAttributes()
monitorStunValues()

print("============================================")
print("  СИМУЛЯЦИЯ ИММУНИТЕТА К ОГЛУШЕНИЮ ЗАПУЩЕНА")
print("============================================")
print(string.format("WalkSpeed восстановления: %d", CONFIG.RestoreWalkSpeed))
print(string.format("JumpPower восстановления: %d", CONFIG.RestoreJumpPower))
print("")
print("Команды:")
print("  _G.StunImmunityStats()      -- статистика")
print("  _G.StunImmunityConfig.Enabled = false  -- выкл")
print("  _G.CleanupStunImmunity()    -- полная очистка")
print("============================================")
