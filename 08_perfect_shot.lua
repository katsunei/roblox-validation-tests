--[[
    ============================================================
    Скрипт #08: Симуляция идеального броска (баскетбол)
    ============================================================
    Назначение:
        Автоматический расчёт и выполнение идеального
        баскетбольного броска с использованием физики
        проективного движения.

    Что тестирует (серверная валидация):
        - Сервер должен проверять параметры броска на реалистичность
        - Отклонять невозможно точные или повторяющиеся попадания
        - Валидировать скорость и угол полёта мяча
        - Проверять расстояние до корзины и позицию игрока

    Формулы:
        v = sqrt(g * d² / (2 * (d * tan(θ) - h)))
        Где: d = расстояние, h = разница высот, θ = угол броска

    Использование:
        Вставить в CommandBar в Roblox Studio.
    ============================================================
--]]

-- === Сервисы ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- === Локальный игрок ===
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === Константы физики ===
local GRAVITY = workspace.Gravity -- Обычно 196.2
local PREFERRED_ANGLE = math.rad(55) -- Оптимальный угол для баскетбольного броска (55°)
local ANGLES_TO_TEST = {45, 50, 55, 60, 65, 70} -- Углы для перебора (в градусах)

print("╔══════════════════════════════════════════════════════╗")
print("║   СИМУЛЯЦИЯ ИДЕАЛЬНОГО БАСКЕТБОЛЬНОГО БРОСКА        ║")
print("╠══════════════════════════════════════════════════════╣")
print("║   Гравитация: " .. GRAVITY .. " studs/s²")
print("╚══════════════════════════════════════════════════════╝")
print("")

-- ============================================================
-- Поиск баскетбольного кольца/корзины в Workspace
-- ============================================================
local function FindHoop()
    local searchNames = {"Hoop", "Basket", "Goal", "BasketballHoop", "BasketGoal", "Net", "Ring", "Rim"}
    local found = nil

    -- Рекурсивный поиск по имени
    local function searchRecursive(parent)
        for _, child in ipairs(parent:GetChildren()) do
            for _, targetName in ipairs(searchNames) do
                if string.lower(child.Name):find(string.lower(targetName)) then
                    -- Нашли объект — пытаемся получить позицию
                    if child:IsA("BasePart") then
                        print("[Кольцо] ✅ Найден BasePart: " .. child:GetFullName())
                        return child
                    elseif child:IsA("Model") then
                        -- Ищем PrimaryPart или первый BasePart в модели
                        local part = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            print("[Кольцо] ✅ Найдена модель: " .. child:GetFullName())
                            return part
                        end
                    end
                end
            end
            -- Ищем глубже
            if not found then
                local result = searchRecursive(child)
                if result then return result end
            end
        end
        return nil
    end

    found = searchRecursive(workspace)

    if not found then
        warn("[Кольцо] ❌ Баскетбольное кольцо не найдено в Workspace!")
        warn("[Кольцо] Искали объекты с именами: " .. table.concat(searchNames, ", "))
        warn("[Кольцо] Создаём виртуальную цель для демонстрации расчётов...")

        -- Создаём виртуальную позицию кольца для демонстрации
        return nil
    end

    return found
end

-- ============================================================
-- Поиск баскетбольного мяча
-- ============================================================
local function FindBall()
    local ballNames = {"Basketball", "Ball", "BasketBall", "Мяч"}

    for _, obj in ipairs(workspace:GetDescendants()) do
        for _, name in ipairs(ballNames) do
            if string.lower(obj.Name):find(string.lower(name)) and obj:IsA("BasePart") then
                print("[Мяч] ✅ Найден: " .. obj:GetFullName())
                return obj
            end
        end
    end

    warn("[Мяч] ❌ Баскетбольный мяч не найден.")
    return nil
end

-- ============================================================
-- Расчёт параметров идеального броска
-- ============================================================
local function CalculateShot(startPos, targetPos, angleDeg)
    local angleRad = math.rad(angleDeg)

    -- Горизонтальное расстояние до цели
    local dx = targetPos.X - startPos.X
    local dz = targetPos.Z - startPos.Z
    local horizontalDistance = math.sqrt(dx * dx + dz * dz)

    -- Разница высот (положительная = цель выше)
    local heightDiff = targetPos.Y - startPos.Y

    -- Направление броска (единичный вектор по горизонтали)
    local direction = Vector3.new(dx, 0, dz).Unit

    -- Расчёт начальной скорости по формуле проективного движения
    -- v = sqrt(g * d² / (2 * (d * tan(θ) - h)))
    local tanAngle = math.tan(angleRad)
    local denominator = 2 * (horizontalDistance * tanAngle - heightDiff)

    if denominator <= 0 then
        -- Невозможная траектория при данном угле
        return nil
    end

    local velocityMagnitude = math.sqrt(GRAVITY * horizontalDistance * horizontalDistance / denominator)

    -- Компоненты скорости
    local vHorizontal = velocityMagnitude * math.cos(angleRad)
    local vVertical = velocityMagnitude * math.sin(angleRad)

    -- Итоговый вектор скорости
    local velocity = direction * vHorizontal + Vector3.new(0, vVertical, 0)

    -- Время полёта
    local timeOfFlight = horizontalDistance / vHorizontal

    -- Максимальная высота траектории
    local maxHeight = startPos.Y + (vVertical * vVertical) / (2 * GRAVITY)

    return {
        Velocity = velocity,
        Speed = velocityMagnitude,
        Angle = angleDeg,
        AngleRad = angleRad,
        HorizontalDistance = horizontalDistance,
        HeightDiff = heightDiff,
        TimeOfFlight = timeOfFlight,
        MaxHeight = maxHeight,
        Direction = direction,
        VHorizontal = vHorizontal,
        VVertical = vVertical,
    }
end

-- ============================================================
-- Логирование параметров броска
-- ============================================================
local function LogShotParams(params, label)
    print("")
    print("┌─── " .. (label or "Параметры броска") .. " ───")
    print("│ Угол:                " .. string.format("%.1f°", params.Angle))
    print("│ Скорость:            " .. string.format("%.2f studs/s", params.Speed))
    print("│ Горизонт. расст.:    " .. string.format("%.2f studs", params.HorizontalDistance))
    print("│ Разница высот:       " .. string.format("%.2f studs", params.HeightDiff))
    print("│ Время полёта:        " .. string.format("%.3f с", params.TimeOfFlight))
    print("│ Макс. высота:        " .. string.format("%.2f studs", params.MaxHeight))
    print("│ Скорость (гор.):     " .. string.format("%.2f studs/s", params.VHorizontal))
    print("│ Скорость (верт.):    " .. string.format("%.2f studs/s", params.VVertical))
    print("│ Вектор скорости:     " .. tostring(params.Velocity))
    print("└──────────────────────────────")
end

-- ============================================================
-- Попытка отправки через RemoteEvent
-- ============================================================
local function TryFireRemote(params, targetPos)
    print("")
    print("[Remote] Поиск RemoteEvent для броска...")

    -- Список возможных имён RemoteEvent
    local remoteNames = {
        "ShootBall", "Shoot", "ThrowBall", "Throw",
        "BasketballShoot", "MakeShot", "FireBall",
        "ShootEvent", "BallShoot", "LaunchBall"
    }

    local firedCount = 0

    for _, remoteName in ipairs(remoteNames) do
        local remote = ReplicatedStorage:FindFirstChild(remoteName, true)
        if remote and remote:IsA("RemoteEvent") then
            print("[Remote] ✅ Найден: " .. remote:GetFullName())

            -- Попытка #1: Отправляем вектор скорости
            local success1, err1 = pcall(function()
                remote:FireServer(params.Velocity, targetPos)
            end)
            if success1 then
                print("[Remote] 📤 Отправлено (вектор скорости)")
                firedCount = firedCount + 1
            else
                warn("[Remote] ⚠ Ошибка: " .. tostring(err1))
            end

            -- Попытка #2: Отправляем параметры отдельно
            local success2, err2 = pcall(function()
                remote:FireServer({
                    velocity = params.Speed,
                    angle = params.Angle,
                    direction = params.Direction,
                    target = targetPos,
                })
            end)
            if success2 then
                print("[Remote] 📤 Отправлено (таблица параметров)")
                firedCount = firedCount + 1
            else
                warn("[Remote] ⚠ Ошибка: " .. tostring(err2))
            end
        end
    end

    if firedCount == 0 then
        warn("[Remote] ❌ Не найден подходящий RemoteEvent для броска.")
    else
        print("[Remote] Всего отправлено: " .. firedCount .. " вызовов.")
    end

    return firedCount
end

-- ============================================================
-- Попытка прямого управления скоростью мяча
-- ============================================================
local function TryDirectBallControl(ball, params)
    if not ball then
        warn("[Мяч] Мяч не найден — пропускаем прямое управление.")
        return false
    end

    print("")
    print("[Мяч] Попытка прямого задания скорости мяча...")

    -- Попытка #1: Прямое задание Velocity (устаревшее, но может работать)
    local success1, err1 = pcall(function()
        ball.Velocity = params.Velocity
    end)
    if success1 then
        print("[Мяч] ✅ ball.Velocity установлен")
    else
        warn("[Мяч] ⚠ Velocity: " .. tostring(err1))
    end

    -- Попытка #2: AssemblyLinearVelocity (новый API)
    local success2, err2 = pcall(function()
        ball.AssemblyLinearVelocity = params.Velocity
    end)
    if success2 then
        print("[Мяч] ✅ ball.AssemblyLinearVelocity установлен")
    else
        warn("[Мяч] ⚠ AssemblyLinearVelocity: " .. tostring(err2))
    end

    -- Попытка #3: Перемещение мяча к игроку + задание скорости
    local success3, err3 = pcall(function()
        ball.CFrame = rootPart.CFrame + Vector3.new(0, 3, 0)
        wait(0.1)
        ball.AssemblyLinearVelocity = params.Velocity
    end)
    if success3 then
        print("[Мяч] ✅ Мяч телепортирован к игроку и запущен")
    else
        warn("[Мяч] ⚠ Телепорт + запуск: " .. tostring(err3))
    end

    return success1 or success2 or success3
end

-- ============================================================
-- Основная логика
-- ============================================================
local function Main()
    print("")
    print("▶ Начинаем расчёт идеального броска...")
    print("")

    -- Позиция игрока (точка броска — чуть выше головы)
    local startPos = rootPart.Position + Vector3.new(0, 3, 0)
    print("[Игрок] Позиция броска: " .. tostring(startPos))

    -- Поиск кольца
    local hoopPart = FindHoop()
    local targetPos

    if hoopPart then
        targetPos = hoopPart.Position
        print("[Кольцо] Позиция: " .. tostring(targetPos))
    else
        -- Виртуальная цель: 30 studs впереди, 10 studs выше
        local lookVector = rootPart.CFrame.LookVector
        targetPos = startPos + lookVector * 30 + Vector3.new(0, 10, 0)
        print("[Кольцо] Виртуальная цель: " .. tostring(targetPos))
    end

    -- Расчёт для нескольких углов и выбор лучшего
    print("")
    print("═══════════════════════════════════════")
    print("  ПЕРЕБОР УГЛОВ БРОСКА")
    print("═══════════════════════════════════════")

    local bestShot = nil
    local allShots = {}

    for _, angle in ipairs(ANGLES_TO_TEST) do
        local params = CalculateShot(startPos, targetPos, angle)
        if params then
            table.insert(allShots, params)
            LogShotParams(params, "Угол " .. angle .. "°")

            -- Выбираем бросок с минимальной скоростью (наиболее реалистичный)
            if not bestShot or params.Speed < bestShot.Speed then
                bestShot = params
            end
        else
            print("│ Угол " .. angle .. "° — ❌ невозможная траектория")
        end
    end

    if not bestShot then
        warn("[Бросок] ❌ Не найден ни один допустимый угол для броска!")
        warn("[Бросок] Цель слишком далеко или слишком высоко.")
        return
    end

    -- Лучший бросок
    print("")
    print("★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★")
    print("  ЛУЧШИЙ БРОСОК (минимальная скорость)")
    print("★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★")
    LogShotParams(bestShot, "ОПТИМАЛЬНЫЙ БРОСОК")

    -- Попытка выполнения через RemoteEvent
    TryFireRemote(bestShot, targetPos)

    -- Попытка прямого управления мячом
    local ball = FindBall()
    TryDirectBallControl(ball, bestShot)

    -- Серия быстрых бросков (тест на rate limiting)
    print("")
    print("═══════════════════════════════════════")
    print("  СЕРИЯ БЫСТРЫХ БРОСКОВ (rate limit)")
    print("═══════════════════════════════════════")

    for i = 1, 5 do
        print("[Серия] Бросок #" .. i .. "...")
        TryFireRemote(bestShot, targetPos)
        wait(0.1) -- Минимальная задержка между бросками
    end

    -- Итоги
    print("")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║                    ИТОГИ ТЕСТИРОВАНИЯ                   ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Рассчитано углов: " .. #allShots .. " из " .. #ANGLES_TO_TEST)
    print("║  Лучший угол:     " .. string.format("%.1f°", bestShot.Angle))
    print("║  Мин. скорость:   " .. string.format("%.2f studs/s", bestShot.Speed))
    print("║                                                         ║")
    print("║  ⚠ Серверная валидация должна:                         ║")
    print("║    • Проверять реалистичность параметров                ║")
    print("║    • Ограничивать частоту бросков (rate limiting)       ║")
    print("║    • Проверять позицию игрока                           ║")
    print("║    • Отклонять идеально точные серии бросков            ║")
    print("╚══════════════════════════════════════════════════════════╝")
end

-- === Запуск ===
Main()
