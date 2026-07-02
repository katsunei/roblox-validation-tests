--[[
    ============================================================
    Скрипт #10: Симуляция Speed Hack
    ============================================================
    Назначение:
        Временное увеличение WalkSpeed выше допустимого лимита.
        Тестирует мгновенное и постепенное изменение скорости.

    Что тестирует (серверная валидация):
        - Сервер должен определять скорость выше порога
        - Детектировать аномальное расстояние за единицу времени
        - Обнаруживать мгновенные скачки WalkSpeed
        - Обнаруживать постепенное увеличение скорости

    Использование:
        Вставить в CommandBar в Roblox Studio.
    ============================================================
--]]

-- === Сервисы ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- === Локальный игрок ===
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === Сохраняем оригинальные значения ===
local originalWalkSpeed = humanoid.WalkSpeed
local originalJumpPower = humanoid.JumpPower

-- === Параметры тестов ===
local TEST_SPEEDS = {50, 100, 200} -- Скорости для тестирования
local TEST_DURATION = 3 -- Секунд на каждый тест
local GRADUAL_STEP = 5 -- Шаг постепенного увеличения
local GRADUAL_INTERVAL = 0.2 -- Интервал между шагами (сек)

-- === Переменные отслеживания ===
local trackingConnection = nil
local lastPosition = rootPart.Position
local lastTime = tick()
local totalDistance = 0
local distanceLog = {} -- {time, distance, speed}

print("╔══════════════════════════════════════════════════════╗")
print("║             СИМУЛЯЦИЯ SPEED HACK                    ║")
print("╠══════════════════════════════════════════════════════╣")
print("║  Оригинальная WalkSpeed: " .. originalWalkSpeed)
print("║  Оригинальный JumpPower: " .. originalJumpPower)
print("║  Тестовые скорости:      " .. table.concat(TEST_SPEEDS, ", "))
print("║  Длительность теста:     " .. TEST_DURATION .. " сек")
print("╚══════════════════════════════════════════════════════╝")
print("")

-- ============================================================
-- Функция: Отслеживание пройденного расстояния
-- ============================================================
local function StartTracking()
    totalDistance = 0
    lastPosition = rootPart.Position
    lastTime = tick()
    distanceLog = {}

    trackingConnection = RunService.Heartbeat:Connect(function()
        local currentPos = rootPart.Position
        local currentTime = tick()
        local dt = currentTime - lastTime

        if dt > 0 then
            -- Расстояние за этот кадр (горизонтальное)
            local delta = Vector3.new(
                currentPos.X - lastPosition.X,
                0, -- Игнорируем вертикальное перемещение
                currentPos.Z - lastPosition.Z
            )
            local frameDist = delta.Magnitude
            totalDistance = totalDistance + frameDist

            -- Скорость в studs/s
            local currentSpeed = frameDist / dt

            -- Логируем каждые ~0.5 секунды
            local elapsed = currentTime - (distanceLog[1] and distanceLog[1].time or currentTime)
            if #distanceLog == 0 or (currentTime - distanceLog[#distanceLog].time) >= 0.5 then
                table.insert(distanceLog, {
                    time = currentTime,
                    totalDist = totalDistance,
                    speed = currentSpeed,
                    walkSpeed = humanoid.WalkSpeed,
                })
            end
        end

        lastPosition = currentPos
        lastTime = currentTime
    end)
end

local function StopTracking()
    if trackingConnection then
        trackingConnection:Disconnect()
        trackingConnection = nil
    end
end

-- ============================================================
-- Функция: Установка WalkSpeed с логированием
-- ============================================================
local function SetSpeed(speed, label)
    local prevSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = speed
    print("[Speed] " .. (label or "") .. " WalkSpeed: " .. prevSpeed .. " → " .. speed)
end

-- ============================================================
-- Функция: Печать результатов отслеживания
-- ============================================================
local function PrintTrackingResults(testName, duration)
    local avgSpeed = totalDistance / math.max(duration, 0.01)

    print("")
    print("┌─── Результаты: " .. testName .. " ───")
    print("│ Общее расстояние:     " .. string.format("%.2f studs", totalDistance))
    print("│ Длительность:         " .. string.format("%.2f с", duration))
    print("│ Средняя скорость:     " .. string.format("%.2f studs/s", avgSpeed))
    print("│ WalkSpeed при тесте:  " .. humanoid.WalkSpeed)

    -- Подробный лог
    if #distanceLog > 1 then
        print("│")
        print("│ Подробный лог:")
        for i = 2, math.min(#distanceLog, 10) do
            local entry = distanceLog[i]
            print("│   t=" .. string.format("%.1f", entry.time - distanceLog[1].time)
                .. "с | dist=" .. string.format("%.1f", entry.totalDist)
                .. " | speed=" .. string.format("%.1f", entry.speed)
                .. " | WS=" .. entry.walkSpeed)
        end
    end
    print("└──────────────────────────────")
end

-- ============================================================
-- Тест 1: Мгновенное изменение скорости
-- ============================================================
local function TestInstantSpeed()
    print("")
    print("═══════════════════════════════════════")
    print("  ТЕСТ 1: МГНОВЕННОЕ ИЗМЕНЕНИЕ СКОРОСТИ")
    print("═══════════════════════════════════════")

    for _, speed in ipairs(TEST_SPEEDS) do
        print("")
        print("▶ Тест скорости: " .. speed)

        -- Устанавливаем скорость мгновенно
        SetSpeed(speed, "[Мгновенно]")

        -- Начинаем отслеживание
        StartTracking()

        -- Ждём время теста
        local startTime = tick()
        wait(TEST_DURATION)
        local elapsed = tick() - startTime

        -- Останавливаем отслеживание
        StopTracking()

        -- Печатаем результаты
        PrintTrackingResults("Мгновенно → " .. speed, elapsed)

        -- Восстанавливаем скорость между тестами
        SetSpeed(originalWalkSpeed, "[Восстановление]")
        wait(1) -- Пауза между тестами
    end
end

-- ============================================================
-- Тест 2: Постепенное увеличение скорости
-- ============================================================
local function TestGradualSpeed()
    print("")
    print("═══════════════════════════════════════")
    print("  ТЕСТ 2: ПОСТЕПЕННОЕ УВЕЛИЧЕНИЕ СКОРОСТИ")
    print("═══════════════════════════════════════")

    local maxTestSpeed = TEST_SPEEDS[#TEST_SPEEDS] -- Максимальная целевая скорость

    print("▶ Постепенное увеличение: " .. originalWalkSpeed .. " → " .. maxTestSpeed)
    print("  Шаг: +" .. GRADUAL_STEP .. " каждые " .. GRADUAL_INTERVAL .. " сек")

    -- Начинаем с оригинальной скорости
    SetSpeed(originalWalkSpeed, "[Старт]")
    StartTracking()

    local startTime = tick()
    local currentSpeed = originalWalkSpeed

    while currentSpeed < maxTestSpeed do
        currentSpeed = math.min(currentSpeed + GRADUAL_STEP, maxTestSpeed)
        SetSpeed(currentSpeed, "[Постепенно]")
        wait(GRADUAL_INTERVAL)
    end

    -- Держим максимальную скорость ещё немного
    wait(TEST_DURATION)

    local elapsed = tick() - startTime
    StopTracking()

    PrintTrackingResults("Постепенно → " .. maxTestSpeed, elapsed)

    -- Восстанавливаем
    SetSpeed(originalWalkSpeed, "[Восстановление]")
end

-- ============================================================
-- Тест 3: Скачкообразное изменение (туда-сюда)
-- ============================================================
local function TestOscillatingSpeed()
    print("")
    print("═══════════════════════════════════════")
    print("  ТЕСТ 3: СКАЧКООБРАЗНОЕ ИЗМЕНЕНИЕ")
    print("═══════════════════════════════════════")

    print("▶ Переключение между нормальной и максимальной скоростью")

    StartTracking()
    local startTime = tick()
    local maxSpeed = TEST_SPEEDS[#TEST_SPEEDS]

    for i = 1, 6 do
        if i % 2 == 1 then
            SetSpeed(maxSpeed, "[Скачок ↑]")
        else
            SetSpeed(originalWalkSpeed, "[Скачок ↓]")
        end
        wait(1)
    end

    local elapsed = tick() - startTime
    StopTracking()

    PrintTrackingResults("Скачкообразно (норма ↔ " .. maxSpeed .. ")", elapsed)

    -- Восстанавливаем
    SetSpeed(originalWalkSpeed, "[Восстановление]")
end

-- ============================================================
-- Основная функция
-- ============================================================
local function Main()
    -- Запускаем все тесты последовательно
    TestInstantSpeed()
    wait(2)

    TestGradualSpeed()
    wait(2)

    TestOscillatingSpeed()

    -- Гарантированное восстановление оригинальных значений
    humanoid.WalkSpeed = originalWalkSpeed
    humanoid.JumpPower = originalJumpPower

    -- Итоги
    print("")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║              ИТОГИ ТЕСТИРОВАНИЯ SPEED HACK              ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  WalkSpeed восстановлен: " .. humanoid.WalkSpeed)
    print("║  JumpPower восстановлен: " .. humanoid.JumpPower)
    print("║                                                         ║")
    print("║  ⚠ Серверная валидация должна:                         ║")
    print("║    • Устанавливать порог допустимой WalkSpeed           ║")
    print("║    • Отслеживать расстояние/время за серверный тик      ║")
    print("║    • Обнаруживать мгновенные скачки скорости            ║")
    print("║    • Обнаруживать постепенное «подкручивание»           ║")
    print("║    • Проверять реальное перемещение (не только свойство) ║")
    print("╚══════════════════════════════════════════════════════════╝")
end

-- === Запуск ===
Main()
