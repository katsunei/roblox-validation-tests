--[[
    ============================================================
    Скрипт #09: Симуляция полёта
    ============================================================
    Назначение:
        Модификация гравитации и применение сил для полёта
        персонажа. Управление клавишами WASD + Space/Shift.

    Что тестирует (серверная валидация):
        - Сервер должен обнаруживать аномальные изменения
          Y-координаты (полёт вверх без прыжка/платформы)
        - Детектировать нулевую гравитацию
        - Проверять физическую реалистичность перемещений

    Управление:
        F     — включить/выключить полёт
        W/A/S/D — перемещение в горизонтальной плоскости
        Space   — подъём вверх
        Shift   — спуск вниз

    Использование:
        Вставить в CommandBar в Roblox Studio.
    ============================================================
--]]

-- === Сервисы ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- === Локальный игрок ===
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === Состояние полёта ===
local isFlying = false
local flySpeed = 80 -- Скорость полёта (studs/s)
local verticalSpeed = 60 -- Скорость подъёма/спуска
local originalGravity = workspace.Gravity
local bodyVelocity = nil
local bodyGyro = nil
local renderConnection = nil

-- === Отслеживание нажатых клавиш ===
local keysPressed = {}

-- === Счётчики для логирования ===
local flightStartTime = 0
local maxHeight = 0
local startHeight = 0
local totalFlightTime = 0
local flightCount = 0

print("╔══════════════════════════════════════════════════════╗")
print("║           СИМУЛЯЦИЯ ПОЛЁТА                          ║")
print("╠══════════════════════════════════════════════════════╣")
print("║  F     — включить/выключить полёт                  ║")
print("║  WASD  — перемещение по горизонтали                ║")
print("║  Space — подъём вверх                               ║")
print("║  Shift — спуск вниз                                 ║")
print("╚══════════════════════════════════════════════════════╝")
print("")

-- ============================================================
-- Создание объектов физики для полёта
-- ============================================================
local function CreateFlyObjects()
    -- BodyVelocity — управляет скоростью персонажа
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "TestFlyVelocity"
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.P = 10000 -- Сила коррекции
    bodyVelocity.Parent = rootPart

    -- BodyGyro — стабилизирует ориентацию
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "TestFlyGyro"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.D = 200
    bodyGyro.P = 10000
    bodyGyro.Parent = rootPart

    print("[Полёт] ✅ Объекты физики созданы (BodyVelocity + BodyGyro)")
end

-- ============================================================
-- Удаление объектов физики
-- ============================================================
local function DestroyFlyObjects()
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end
    print("[Полёт] 🗑 Объекты физики удалены")
end

-- ============================================================
-- Расчёт вектора перемещения на основе нажатых клавиш
-- ============================================================
local function GetMoveDirection()
    local camera = workspace.CurrentCamera
    local camCF = camera.CFrame

    -- Горизонтальные направления камеры (без компоненты Y)
    local lookVector = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
    local rightVector = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

    local moveDir = Vector3.new(0, 0, 0)

    -- Горизонтальное движение (WASD)
    if keysPressed[Enum.KeyCode.W] then
        moveDir = moveDir + lookVector
    end
    if keysPressed[Enum.KeyCode.S] then
        moveDir = moveDir - lookVector
    end
    if keysPressed[Enum.KeyCode.D] then
        moveDir = moveDir + rightVector
    end
    if keysPressed[Enum.KeyCode.A] then
        moveDir = moveDir - rightVector
    end

    -- Вертикальное движение (Space / Shift)
    if keysPressed[Enum.KeyCode.Space] then
        moveDir = moveDir + Vector3.new(0, 1, 0)
    end
    if keysPressed[Enum.KeyCode.LeftShift] or keysPressed[Enum.KeyCode.RightShift] then
        moveDir = moveDir - Vector3.new(0, 1, 0)
    end

    -- Нормализуем, если есть движение
    if moveDir.Magnitude > 0 then
        moveDir = moveDir.Unit
    end

    return moveDir
end

-- ============================================================
-- Включение полёта
-- ============================================================
local function EnableFlight()
    if isFlying then return end
    isFlying = true
    flightCount = flightCount + 1
    flightStartTime = tick()
    startHeight = rootPart.Position.Y
    maxHeight = startHeight

    print("")
    print("[Полёт] ▶ ПОЛЁТ ВКЛЮЧЁН (сеанс #" .. flightCount .. ")")
    print("[Полёт] Начальная высота: " .. string.format("%.1f", startHeight))

    -- Создаём объекты физики
    CreateFlyObjects()

    -- Опционально: отключаем гравитацию
    workspace.Gravity = 0
    print("[Полёт] Гравитация: " .. workspace.Gravity .. " (была: " .. originalGravity .. ")")

    -- Отключаем падение гуманоида
    humanoid.PlatformStand = true

    -- Обновление скорости каждый кадр
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isFlying then return end
        if not bodyVelocity or not bodyVelocity.Parent then return end

        local moveDir = GetMoveDirection()
        local targetVelocity = Vector3.new(0, 0, 0)

        if moveDir.Magnitude > 0 then
            -- Разделяем горизонтальную и вертикальную составляющие
            local horizontal = Vector3.new(moveDir.X, 0, moveDir.Z)
            local vertical = Vector3.new(0, moveDir.Y, 0)

            targetVelocity = horizontal * flySpeed + vertical * verticalSpeed
        end

        bodyVelocity.Velocity = targetVelocity

        -- Обновляем ориентацию по камере
        if bodyGyro then
            local camera = workspace.CurrentCamera
            local lookAt = rootPart.Position + Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
            bodyGyro.CFrame = CFrame.new(rootPart.Position, lookAt)
        end

        -- Отслеживаем максимальную высоту
        local currentHeight = rootPart.Position.Y
        if currentHeight > maxHeight then
            maxHeight = currentHeight
        end
    end)
end

-- ============================================================
-- Отключение полёта
-- ============================================================
local function DisableFlight()
    if not isFlying then return end
    isFlying = false

    local flightDuration = tick() - flightStartTime
    totalFlightTime = totalFlightTime + flightDuration

    -- Отключаем рендер-подключение
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end

    -- Удаляем объекты физики
    DestroyFlyObjects()

    -- Восстанавливаем гравитацию
    workspace.Gravity = originalGravity

    -- Восстанавливаем состояние гуманоида
    humanoid.PlatformStand = false

    print("")
    print("[Полёт] ⏹ ПОЛЁТ ОТКЛЮЧЁН")
    print("[Полёт] Длительность:     " .. string.format("%.1f с", flightDuration))
    print("[Полёт] Макс. высота:     " .. string.format("%.1f studs", maxHeight))
    print("[Полёт] Набор высоты:     " .. string.format("%.1f studs", maxHeight - startHeight))
    print("[Полёт] Гравитация восстановлена: " .. workspace.Gravity)
end

-- ============================================================
-- Переключение полёта (Toggle)
-- ============================================================
local function ToggleFlight()
    if isFlying then
        DisableFlight()
    else
        EnableFlight()
    end
end

-- ============================================================
-- Обработка ввода
-- ============================================================
local inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    keysPressed[input.KeyCode] = true

    -- F — переключение полёта
    if input.KeyCode == Enum.KeyCode.F then
        ToggleFlight()
    end
end)

local inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
    keysPressed[input.KeyCode] = nil
end)

-- ============================================================
-- Очистка при завершении скрипта / перезапуске персонажа
-- ============================================================
local function Cleanup()
    print("")
    print("═══════════════════════════════════════")
    print("  ОЧИСТКА СИМУЛЯЦИИ ПОЛЁТА")
    print("═══════════════════════════════════════")

    -- Отключаем полёт, если активен
    if isFlying then
        DisableFlight()
    end

    -- Отключаем подключения ввода
    if inputBeganConn then
        inputBeganConn:Disconnect()
    end
    if inputEndedConn then
        inputEndedConn:Disconnect()
    end

    -- Восстанавливаем гравитацию (на всякий случай)
    workspace.Gravity = originalGravity

    print("[Очистка] ✅ Гравитация: " .. workspace.Gravity)
    print("[Очистка] Всего сеансов полёта: " .. flightCount)
    print("[Очистка] Общее время полёта: " .. string.format("%.1f с", totalFlightTime))
    print("")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║  ⚠ Серверная валидация должна:                         ║")
    print("║    • Отслеживать аномальные изменения Y-позиции        ║")
    print("║    • Детектировать BodyVelocity/VectorForce у игрока   ║")
    print("║    • Проверять отсутствие опоры под ногами             ║")
    print("║    • Ограничивать время в воздухе без касания земли    ║")
    print("╚══════════════════════════════════════════════════════════╝")
end

-- Регистрация очистки через _G для ручного вызова
_G.StopFlight = Cleanup

-- Очистка при уничтожении персонажа
player.CharacterRemoving:Connect(function()
    Cleanup()
end)

print("[Полёт] ✅ Скрипт загружен. Нажмите F для переключения полёта.")
print("[Полёт] Для ручной остановки: _G.StopFlight()")
