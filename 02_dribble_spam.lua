--[[
	============================================================
	  02_dribble_spam.lua — Симуляция спама дриблингом
	============================================================
	  Назначение:
	    Проверяет серверную валидацию частоты запросов дриблинга.
	    Отправляет массовые запросы без задержки, чтобы убедиться,
	    что сервер правильно ограничивает частоту действий
	    (rate-limiting / cooldown).

	  Что тестируется:
	    1. Массовая отправка RemoteEvent 'Dribble' без пауз
	    2. Замер времени обработки всех запросов
	    3. Отправка с минимальными задержками (быстрее человека)
	    4. Пакетная отправка нескольких запросов за один кадр

	  Ожидаемый результат:
	    Сервер должен обработать только первый запрос (или
	    несколько первых) и отклонить остальные до истечения
	    кулдауна. Должна быть защита от флуда.

	  Использование:
	    Вставить в CommandBar в Roblox Studio (режим Play).
	============================================================
]]

-- === Сервисы ===
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- === Получаем локального игрока ===
local localPlayer = Players.LocalPlayer
if not localPlayer then
	warn("[DribbleSpam] Ошибка: LocalPlayer не найден. Запустите в режиме Play.")
	return
end

print("==============================================")
print("[DribbleSpam] Начинаем тест спама дриблингом")
print("[DribbleSpam] Игрок: " .. localPlayer.Name)
print("==============================================")

-- === Поиск RemoteEvent для дриблинга ===
-- Ищем в нескольких типичных местах
local dribbleRemote = nil
local searchLocations = {
	-- Прямые пути
	{parent = ReplicatedStorage, name = "Dribble"},
	{parent = ReplicatedStorage, name = "DribbleEvent"},
	{parent = ReplicatedStorage, name = "DribbleAction"},
	-- Внутри папок Remotes / Events
	{parent = ReplicatedStorage:FindFirstChild("Remotes"), name = "Dribble"},
	{parent = ReplicatedStorage:FindFirstChild("Events"), name = "Dribble"},
	{parent = ReplicatedStorage:FindFirstChild("RemoteEvents"), name = "Dribble"},
	{parent = ReplicatedStorage:FindFirstChild("GameRemotes"), name = "Dribble"},
	{parent = ReplicatedStorage:FindFirstChild("Remotes"), name = "DribbleEvent"},
}

for _, loc in ipairs(searchLocations) do
	if loc.parent then
		local found = loc.parent:FindFirstChild(loc.name)
		if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction")) then
			dribbleRemote = found
			break
		end
	end
end

-- Если не нашли, ищем по всему ReplicatedStorage рекурсивно
if not dribbleRemote then
	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("RemoteEvent") and descendant.Name:lower():find("dribble") then
			dribbleRemote = descendant
			break
		end
	end
end

if not dribbleRemote then
	warn("[DribbleSpam] RemoteEvent для дриблинга не найден!")
	warn("[DribbleSpam] Подсказка: создайте RemoteEvent 'Dribble' в ReplicatedStorage")
	warn("[DribbleSpam] Продолжаем тест в режиме симуляции (без реальной отправки)...")
end

-- === Настройки теста ===
local TOTAL_REQUESTS = 60       -- Общее количество запросов
local BURST_SIZE = 10            -- Размер пакета (запросов за один кадр)
local MICRO_DELAY = 0            -- Задержка между запросами в пакете (0 = без задержки)
local INTER_BURST_DELAY = 0.05   -- Задержка между пакетами (минимальная)

print(string.format("\n[DribbleSpam] Параметры теста:"))
print(string.format("  Всего запросов: %d", TOTAL_REQUESTS))
print(string.format("  Размер пакета: %d", BURST_SIZE))
print(string.format("  Задержка в пакете: %.4f сек", MICRO_DELAY))
print(string.format("  Задержка между пакетами: %.4f сек", INTER_BURST_DELAY))

-- === Статистика ===
local stats = {
	sent = 0,          -- Отправлено запросов
	errors = 0,        -- Ошибки при отправке
	startTime = 0,     -- Время начала
	endTime = 0,       -- Время окончания
	timestamps = {},   -- Временные метки каждого запроса
}

-- ============================================================
-- ТЕСТ 1: Мгновенная пакетная отправка (без пауз)
-- ============================================================
print("\n--- Тест 1: Мгновенный пакетный спам (0 задержка) ---")

stats.startTime = tick()

for i = 1, TOTAL_REQUESTS do
	local requestTime = tick()

	local success, err = pcall(function()
		if dribbleRemote then
			if dribbleRemote:IsA("RemoteEvent") then
				dribbleRemote:FireServer()
			elseif dribbleRemote:IsA("RemoteFunction") then
				dribbleRemote:InvokeServer()
			end
		end
	end)

	if success then
		stats.sent = stats.sent + 1
	else
		stats.errors = stats.errors + 1
		-- Выводим только первые 5 ошибок, чтобы не засорять лог
		if stats.errors <= 5 then
			print(string.format("  ✗ Ошибка запроса #%d: %s", i, tostring(err)))
		end
	end

	table.insert(stats.timestamps, requestTime)

	-- Отображаем прогресс каждые 10 запросов
	if i % 10 == 0 then
		local elapsed = tick() - stats.startTime
		print(string.format("  → Отправлено %d/%d запросов за %.4f сек (%.0f запросов/сек)",
			i, TOTAL_REQUESTS, elapsed, i / elapsed))
	end
end

stats.endTime = tick()

-- === Вывод статистики теста 1 ===
local totalTime = stats.endTime - stats.startTime
print(string.format("\n[DribbleSpam] Результаты теста 1 (мгновенный спам):"))
print(string.format("  Отправлено: %d запросов", stats.sent))
print(string.format("  Ошибок: %d", stats.errors))
print(string.format("  Общее время: %.4f сек", totalTime))
print(string.format("  Скорость: %.1f запросов/сек", stats.sent / math.max(totalTime, 0.001)))

if #stats.timestamps >= 2 then
	-- Вычисляем минимальный интервал между запросами
	local minInterval = math.huge
	local maxInterval = 0
	for j = 2, #stats.timestamps do
		local interval = stats.timestamps[j] - stats.timestamps[j - 1]
		minInterval = math.min(minInterval, interval)
		maxInterval = math.max(maxInterval, interval)
	end
	print(string.format("  Мин. интервал между запросами: %.6f сек", minInterval))
	print(string.format("  Макс. интервал между запросами: %.6f сек", maxInterval))
end

-- ============================================================
-- ТЕСТ 2: Пакетная отправка с микрозадержками
-- ============================================================
print("\n--- Тест 2: Пакетная отправка (burst-режим) ---")
task.wait(1) -- Ждём секунду, чтобы кулдаун сервера (если есть) мог сброситься

local burstStats = {
	sent = 0,
	bursts = 0,
	startTime = tick(),
}

local remaining = TOTAL_REQUESTS
while remaining > 0 do
	local batchSize = math.min(BURST_SIZE, remaining)
	burstStats.bursts = burstStats.bursts + 1

	print(string.format("  Пакет #%d: отправляю %d запросов...", burstStats.bursts, batchSize))

	-- Отправляем весь пакет без задержки
	for j = 1, batchSize do
		pcall(function()
			if dribbleRemote and dribbleRemote:IsA("RemoteEvent") then
				dribbleRemote:FireServer("burst", burstStats.bursts, j)
			end
		end)
		burstStats.sent = burstStats.sent + 1

		if MICRO_DELAY > 0 then
			task.wait(MICRO_DELAY)
		end
	end

	remaining = remaining - batchSize

	-- Минимальная задержка между пакетами
	if remaining > 0 then
		task.wait(INTER_BURST_DELAY)
	end
end

local burstTotalTime = tick() - burstStats.startTime
print(string.format("\n[DribbleSpam] Результаты теста 2 (burst-режим):"))
print(string.format("  Пакетов отправлено: %d", burstStats.bursts))
print(string.format("  Запросов отправлено: %d", burstStats.sent))
print(string.format("  Общее время: %.4f сек", burstTotalTime))
print(string.format("  Скорость: %.1f запросов/сек", burstStats.sent / math.max(burstTotalTime, 0.001)))

-- ============================================================
-- ТЕСТ 3: Однокадровый спам (всё в одном RenderStepped)
-- ============================================================
print("\n--- Тест 3: Однокадровый спам (все запросы за 1 кадр) ---")
task.wait(1)

local frameSent = 0
local frameStart = tick()

-- Подключаемся к одному кадру и отправляем максимум запросов
local connection
connection = RunService.RenderStepped:Connect(function()
	connection:Disconnect() -- Отключаемся сразу, чтобы сработало один раз

	for k = 1, TOTAL_REQUESTS do
		pcall(function()
			if dribbleRemote and dribbleRemote:IsA("RemoteEvent") then
				dribbleRemote:FireServer("single_frame", k)
			end
		end)
		frameSent = frameSent + 1
	end
end)

-- Ждём, пока кадр пройдёт
task.wait(0.1)

local frameTime = tick() - frameStart
print(string.format("[DribbleSpam] Результаты теста 3 (однокадровый):"))
print(string.format("  Запросов за 1 кадр: %d", frameSent))
print(string.format("  Время кадра: %.4f сек", frameTime))

-- ============================================================
-- ИТОГИ
-- ============================================================
print("\n==============================================")
print("[DribbleSpam] Все тесты завершены!")
print("[DribbleSpam] Проверьте серверный лог на:")
print("  - Сообщения о rate-limiting / троттлинге")
print("  - Сколько дриблов сервер реально обработал")
print("  - Был ли игрок наказан за спам (кик/предупреждение)")
print("[DribbleSpam] Ожидаемое поведение сервера:")
print("  ✓ Обработан 1 дрибл, остальные отклонены до кулдауна")
print("  ✓ Rate-limit логирует превышение частоты")
print("  ✓ При серьёзном злоупотреблении — кик/бан")
print("==============================================")
