--[[
    ============================================================
    ИНСТРУМЕНТ ПОДБОРА ТАЙМИНГОВ
    ============================================================
    Назначение: Позволяет вручную регулировать задержки действий
    через консоль, чтобы найти границы серверных ограничений.
    
    Что проверяет: Минимальные допустимые интервалы между
    действиями, которые сервер принимает без блокировки.
    
    ТОЛЬКО ДЛЯ ТЕСТИРОВАНИЯ В ROBLOX STUDIO!
    ============================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- =============================================
-- КОНФИГУРАЦИЯ ТАЙМИНГОВ
-- =============================================
-- Все значения в секундах
_G.TimingConfig = _G.TimingConfig or {
    DribbleDelay  = 0.5,   -- Задержка между дриблингом
    ParryDelay    = 0.3,   -- Задержка между парированиями
    DodgeDelay    = 1.0,   -- Задержка между уклонениями
    AttackDelay   = 0.4,   -- Задержка между атаками
    ShootDelay    = 1.5,   -- Задержка между бросками
    BlockDelay    = 0.2,   -- Задержка между блоками
    SprintDelay   = 0.1,   -- Задержка между переключениями спринта
}

local CONFIG = _G.TimingConfig

-- =============================================
-- РЕЗУЛЬТАТЫ ТЕСТОВ
-- =============================================
local testResults = {}

-- =============================================
-- УТИЛИТЫ
-- =============================================

-- Поиск RemoteEvent по имени (с fallback)
local function findRemote(name)
    -- Ищем в стандартных местах
    local searchPaths = {
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage,
    }
    
    for _, container in ipairs(searchPaths) do
        if container then
            local remote = container:FindFirstChild(name)
            if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                return remote
            end
        end
    end
    
    return nil
end

-- Универсальная функция тестирования задержки
local function testActionTiming(actionName, remoteName, delay, iterations)
    iterations = iterations or 10
    
    print(string.format("\n▶ Тест: %s | Задержка: %.3fс | Итерации: %d", 
        actionName, delay, iterations))
    print(string.rep("-", 50))
    
    local remote = findRemote(remoteName)
    local accepted = 0
    local rejected = 0
    local timestamps = {}
    
    for i = 1, iterations do
        local sendTime = os.clock()
        table.insert(timestamps, sendTime)
        
        if remote then
            local success, err = pcall(function()
                remote:FireServer()
            end)
            
            if success then
                accepted = accepted + 1
                print(string.format("  [%d/%d] ✅ Отправлено (t=%.3fs)", i, iterations, sendTime - timestamps[1]))
            else
                rejected = rejected + 1
                print(string.format("  [%d/%d] ❌ Ошибка: %s", i, iterations, tostring(err)))
            end
        else
            -- Если remote не найден, симулируем
            print(string.format("  [%d/%d] ⚠️  Remote '%s' не найден (симуляция)", 
                i, iterations, remoteName))
            accepted = accepted + 1
        end
        
        if i < iterations then
            wait(delay)
        end
    end
    
    -- Рассчитываем реальные интервалы
    local intervals = {}
    for i = 2, #timestamps do
        table.insert(intervals, timestamps[i] - timestamps[i-1])
    end
    
    local avgInterval = 0
    local minInterval = math.huge
    local maxInterval = 0
    
    for _, interval in ipairs(intervals) do
        avgInterval = avgInterval + interval
        if interval < minInterval then minInterval = interval end
        if interval > maxInterval then maxInterval = interval end
    end
    
    if #intervals > 0 then
        avgInterval = avgInterval / #intervals
    end
    
    local result = {
        Action = actionName,
        Remote = remoteName,
        ConfiguredDelay = delay,
        Iterations = iterations,
        Accepted = accepted,
        Rejected = rejected,
        AvgInterval = avgInterval,
        MinInterval = minInterval,
        MaxInterval = maxInterval,
        Timestamp = os.date("%H:%M:%S"),
    }
    table.insert(testResults, result)
    
    print(string.rep("-", 50))
    print(string.format("  Результат: %d/%d принято", accepted, iterations))
    print(string.format("  Интервалы: мин=%.3fс сред=%.3fс макс=%.3fс", 
        minInterval, avgInterval, maxInterval))
    print("")
    
    return result
end

-- =============================================
-- ФУНКЦИИ ТЕСТИРОВАНИЯ КОНКРЕТНЫХ ДЕЙСТВИЙ
-- =============================================

_G.TestDribble = function(iterations)
    return testActionTiming("Дриблинг", "Dribble", CONFIG.DribbleDelay, iterations or 10)
end

_G.TestParry = function(iterations)
    return testActionTiming("Парирование", "Parry", CONFIG.ParryDelay, iterations or 10)
end

_G.TestDodge = function(iterations)
    return testActionTiming("Уклонение", "Dodge", CONFIG.DodgeDelay, iterations or 10)
end

_G.TestAttack = function(iterations)
    return testActionTiming("Атака", "Attack", CONFIG.AttackDelay, iterations or 10)
end

_G.TestShoot = function(iterations)
    return testActionTiming("Бросок", "Shoot", CONFIG.ShootDelay, iterations or 10)
end

_G.TestBlock = function(iterations)
    return testActionTiming("Блок", "Block", CONFIG.BlockDelay, iterations or 10)
end

-- =============================================
-- ПОЛНАЯ ТЕСТОВАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ
-- =============================================
_G.RunTimingSequence = function(iterations)
    iterations = iterations or 5
    print("╔════════════════════════════════════════════╗")
    print("║   ЗАПУСК ПОЛНОЙ ТЕСТОВОЙ ПОСЛЕДОВАТЕЛЬНОСТИ   ║")
    print("╚════════════════════════════════════════════╝")
    print("")
    
    _G.TestDribble(iterations)
    wait(1)
    _G.TestParry(iterations)
    wait(1)
    _G.TestDodge(iterations)
    wait(1)
    _G.TestAttack(iterations)
    wait(1)
    _G.TestShoot(iterations)
    wait(1)
    _G.TestBlock(iterations)
    
    print("\n✅ Последовательность завершена! Используйте _G.TimingReport() для отчёта.")
end

-- =============================================
-- БИНАРНЫЙ ПОИСК МИНИМАЛЬНОЙ ЗАДЕРЖКИ
-- =============================================
_G.FindMinDelay = function(remoteName, minBound, maxBound, steps)
    remoteName = remoteName or "Dribble"
    minBound = minBound or 0.01
    maxBound = maxBound or 2.0
    steps = steps or 6
    
    print("╔════════════════════════════════════════════╗")
    print("║   БИНАРНЫЙ ПОИСК МИНИМАЛЬНОЙ ЗАДЕРЖКИ      ║")
    print("╚════════════════════════════════════════════╝")
    print(string.format("Remote: %s | Диапазон: [%.3f, %.3f] | Шагов: %d",
        remoteName, minBound, maxBound, steps))
    print("")
    
    for step = 1, steps do
        local mid = (minBound + maxBound) / 2
        print(string.format("--- Шаг %d/%d: Тест с задержкой %.3fс ---", step, steps, mid))
        
        local result = testActionTiming(
            "BinarySearch_" .. step,
            remoteName,
            mid,
            5
        )
        
        -- Если все приняты — можно уменьшить задержку
        if result.Rejected == 0 then
            maxBound = mid
            print("  → Все приняты, уменьшаем верхнюю границу")
        else
            minBound = mid
            print("  → Есть отклонения, увеличиваем нижнюю границу")
        end
        
        wait(1)
    end
    
    print(string.format("\n🎯 Приблизительная минимальная задержка: %.3fс", (minBound + maxBound) / 2))
    print(string.format("   Безопасный диапазон: [%.3f, %.3f]с", minBound, maxBound))
end

-- =============================================
-- ОТЧЁТ
-- =============================================
_G.TimingReport = function()
    print("╔════════════════════════════════════════════╗")
    print("║          ОТЧЁТ ПО ТАЙМИНГАМ                ║")
    print("╚════════════════════════════════════════════╝")
    
    if #testResults == 0 then
        print("  Нет данных. Запустите тесты сначала.")
        return
    end
    
    print(string.format("  Всего тестов: %d\n", #testResults))
    print(string.format("  %-15s | %-8s | %-8s | %-10s | %-10s",
        "Действие", "Задержка", "Принято", "Мин.инт.", "Сред.инт."))
    print("  " .. string.rep("-", 60))
    
    for _, r in ipairs(testResults) do
        print(string.format("  %-15s | %.3fс  | %d/%-5d | %.3fс    | %.3fс",
            r.Action, r.ConfiguredDelay, r.Accepted, r.Iterations,
            r.MinInterval, r.AvgInterval))
    end
    
    print("")
end

-- Очистка результатов
_G.ClearTimingResults = function()
    testResults = {}
    print("[Timing] Результаты очищены")
end

-- Показать текущую конфигурацию
_G.ShowTimingConfig = function()
    print("=== ТЕКУЩАЯ КОНФИГУРАЦИЯ ТАЙМИНГОВ ===")
    for key, value in pairs(CONFIG) do
        print(string.format("  %s = %.3f сек", key, value))
    end
    print("======================================")
end

-- =============================================
-- ИНИЦИАЛИЗАЦИЯ
-- =============================================
print("============================================")
print("  ИНСТРУМЕНТ ПОДБОРА ТАЙМИНГОВ ЗАПУЩЕН")
print("============================================")
_G.ShowTimingConfig()
print("")
print("Изменение задержек из CommandBar:")
print("  _G.TimingConfig.DribbleDelay = 0.2")
print("  _G.TimingConfig.ParryDelay = 0.15")
print("  _G.TimingConfig.DodgeDelay = 0.5")
print("")
print("Тесты:")
print("  _G.TestDribble(10)        -- тест дриблинга")
print("  _G.TestParry(10)          -- тест парирования")
print("  _G.TestDodge(10)          -- тест уклонения")
print("  _G.RunTimingSequence(5)   -- полная последовательность")
print("  _G.FindMinDelay('Dribble', 0.01, 2.0, 6) -- бинарный поиск")
print("")
print("Отчёт:")
print("  _G.TimingReport()         -- показать результаты")
print("  _G.ShowTimingConfig()     -- текущие настройки")
print("  _G.ClearTimingResults()   -- очистить")
print("============================================")
