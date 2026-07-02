--[[
    ============================================================
    СИМУЛЯЦИЯ NO RAGDOLL
    ============================================================
    Назначение: Предотвращает ragdoll-анимацию при нокдауне,
    сохраняя персонажа в вертикальном положении.
    
    Что проверяет: Применяет ли сервер ragdoll-состояние
    независимо от клиента.
    
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
    RestoreJoints = true,       -- Восстанавливать суставы при ragdoll
    ForceStanding = true,       -- Принудительно удерживать стоя
    BlockStateChanges = true,   -- Блокировать изменения состояния ragdoll
}
_G.NoRagdollConfig = CONFIG

local connections = {}
local ragdollBlockCount = 0
local sessionStart = os.clock()
local originalMotors = {}  -- Сохранённые Motor6D

-- =============================================
-- СОХРАНЕНИЕ ОРИГИНАЛЬНЫХ JOINT'ОВ
-- =============================================
local function saveJoints()
    originalMotors = {}
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            originalMotors[descendant.Name] = {
                Part0 = descendant.Part0,
                Part1 = descendant.Part1,
                C0 = descendant.C0,
                C1 = descendant.C1,
                Parent = descendant.Parent,
                Enabled = descendant.Enabled,
            }
        end
    end
    print(string.format("[NoRagdoll] Сохранено %d суставов", #originalMotors))
end

-- =============================================
-- ВОССТАНОВЛЕНИЕ JOINT'ОВ
-- =============================================
local function restoreJoints()
    if not CONFIG.RestoreJoints then return end
    
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            local saved = originalMotors[descendant.Name]
            if saved then
                descendant.Enabled = true
            end
        end
    end
end

-- =============================================
-- МОНИТОРИНГ RAGDOLL-СОСТОЯНИЙ
-- =============================================

-- Метод 1: Мониторинг BoolValue "Ragdolled"
local function monitorBoolValues()
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BoolValue") then
            local name = descendant.Name:lower()
            if name:find("ragdoll") or name:find("knockdown") or name:find("knocked") then
                local conn = descendant.Changed:Connect(function(value)
                    if not CONFIG.Enabled then return end
                    if value == true then
                        ragdollBlockCount = ragdollBlockCount + 1
                        descendant.Value = false
                        restoreJoints()
                        print(string.format(
                            "[NoRagdoll] Заблокирован ragdoll через BoolValue '%s' (#%d)",
                            descendant.Name, ragdollBlockCount
                        ))
                    end
                end)
                table.insert(connections, conn)
                print("[NoRagdoll] Мониторинг BoolValue: " .. descendant.Name)
            end
        end
    end
end

-- Метод 2: Мониторинг атрибутов
local function monitorAttributes()
    local attrNames = {"Ragdolled", "IsRagdoll", "Knockdown", "KnockedDown", "Ragdoll"}
    for _, attrName in ipairs(attrNames) do
        if character:GetAttribute(attrName) ~= nil then
            local conn = character:GetAttributeChangedSignal(attrName):Connect(function()
                if not CONFIG.Enabled then return end
                local val = character:GetAttribute(attrName)
                if val == true then
                    ragdollBlockCount = ragdollBlockCount + 1
                    character:SetAttribute(attrName, false)
                    restoreJoints()
                    print(string.format(
                        "[NoRagdoll] Заблокирован ragdoll через атрибут '%s' (#%d)",
                        attrName, ragdollBlockCount
                    ))
                end
            end)
            table.insert(connections, conn)
            print("[NoRagdoll] Мониторинг атрибута: " .. attrName)
        end
    end
end

-- Метод 3: Мониторинг HumanoidState
local stateConn = humanoid.StateChanged:Connect(function(_, newState)
    if not CONFIG.Enabled then return end
    
    if newState == Enum.HumanoidStateType.Physics 
        or newState == Enum.HumanoidStateType.FallingDown
        or newState == Enum.HumanoidStateType.Ragdoll then
        
        ragdollBlockCount = ragdollBlockCount + 1
        
        -- Принудительно возвращаем в нормальное состояние
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        
        if CONFIG.ForceStanding then
            wait()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        
        restoreJoints()
        
        print(string.format(
            "[NoRagdoll] Заблокировано состояние '%s' (#%d)",
            newState.Name, ragdollBlockCount
        ))
    end
end)
table.insert(connections, stateConn)

-- Метод 4: Блокировка отключения Motor6D (основной признак ragdoll)
local childRemovedConn = character.DescendantRemoving:Connect(function(descendant)
    if not CONFIG.Enabled then return end
    if not CONFIG.RestoreJoints then return end
    
    if descendant:IsA("Motor6D") then
        print(string.format("[NoRagdoll] Обнаружено удаление Motor6D: %s", descendant.Name))
        -- Motor6D нельзя восстановить после удаления напрямую,
        -- но мы логируем это для отладки
    end
end)
table.insert(connections, childRemovedConn)

-- Метод 5: Непрерывный мониторинг — активация суставов
local heartbeatConn = RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then return end
    if not CONFIG.RestoreJoints then return end
    if not character or not character.Parent then return end
    
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") and not descendant.Enabled then
            descendant.Enabled = true
        end
    end
end)
table.insert(connections, heartbeatConn)

-- =============================================
-- ОБРАБОТКА РЕСПАВНА
-- =============================================
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    saveJoints()
    monitorBoolValues()
    monitorAttributes()
    print("[NoRagdoll] Персонаж обновлён, мониторинг перезапущен")
end)
table.insert(connections, charConn)

-- =============================================
-- ГЛОБАЛЬНЫЕ ФУНКЦИИ
-- =============================================
_G.NoRagdollStats = function()
    print("=== СТАТИСТИКА NO RAGDOLL ===")
    print(string.format("  Статус: %s", CONFIG.Enabled and "ВКЛ" or "ВЫКЛ"))
    print(string.format("  Заблокировано ragdoll: %d", ragdollBlockCount))
    print(string.format("  Время работы: %.0f сек", os.clock() - sessionStart))
    print("=============================")
end

_G.CleanupNoRagdoll = function()
    CONFIG.Enabled = false
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    print("[NoRagdoll] Полностью отключён")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
saveJoints()
monitorBoolValues()
monitorAttributes()

-- Блокируем нежелательные состояния
if CONFIG.BlockStateChanges then
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

print("============================================")
print("  СИМУЛЯЦИЯ NO RAGDOLL ЗАПУЩЕНА")
print("============================================")
print("Режим: " .. (CONFIG.ForceStanding and "Принудительное стояние" or "Быстрое восстановление"))
print("")
print("Команды:")
print("  _G.NoRagdollStats()       -- статистика")
print("  _G.NoRagdollConfig.Enabled = false  -- выкл")
print("  _G.CleanupNoRagdoll()     -- полная очистка")
print("============================================")
