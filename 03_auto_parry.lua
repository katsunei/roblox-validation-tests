--[[
	============================================================
	  03_auto_parry.lua — Симуляция автоматического парирования
	============================================================
	  Назначение:
	    Проверяет, способен ли сервер обнаружить нечеловечески
	    быстрое парирование. Скрипт мониторит анимации атак
	    ближайших игроков и мгновенно отправляет запрос на
	    парирование при обнаружении замаха.

	  Что тестируется:
	    1. Мониторинг анимаций соперников (AnimationPlayed)
	    2. Мгновенная реакция на обнаружение атаки (<1мс)
	    3. Отправка RemoteEvent парирования с нулевой задержкой
	    4. Логирование времени реакции для анализа

	  Ожидаемый результат:
	    Сервер должен определить, что время реакции нереально
	    мало (< ~150мс для человека) и отклонить парирование
	    или пометить игрока как подозрительного.

	  Использование:
	    Вставить в CommandBar в Roblox Studio (режим Play).
	    Нужен как минимум второй игрок (или NPC с анимациями).
	============================================================
]]

-- === Сервисы ===
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- === Получаем локального игрока ===
local localPlayer = Players.LocalPlayer
if not localPlayer then
	warn("[AutoParry] Ошибка: LocalPlayer не найден. Запустите в режиме Play.")
	return
end

print("==============================================")
print("[AutoParry] Начинаем тест автоматического парирования")
print("[AutoParry] Игрок: " .. localPlayer.Name)
print("==============================================")

-- === Настройки ===
local CONFIG = {
	DETECTION_RADIUS = 30,          -- Радиус обнаружения атак (стадов)
	REACTION_DELAY = 0.0,           -- Задержка реакции (0 = мгновенно, нечеловеческая)
	MAX_PARRIES = 20,               -- Максимальное кол-во парирований в тесте
	LOG_DETAILS = true,             -- Подробное логирование
}

-- === Ключевые слова для обнаружения анимаций атак ===
-- Скрипт ищет эти паттерны в названиях/ID анимаций
local ATTACK_ANIMATION_PATTERNS = {
	"attack",
	"punch",
	"kick",
	"swing",
	"slash",
	"hit",
	"strike",
	"combat",
	"fight",
	"melee",
	"shoot",
	"throw",
}

-- === Поиск RemoteEvent для парирования ===
local parryRemote = nil
local searchNames = {"Parry", "ParryEvent", "Block", "Defend", "Counter", "ParryAction"}

for _, name in ipairs(searchNames) do
	-- Прямой поиск
	local found = ReplicatedStorage:FindFirstChild(name)
	if found and found:IsA("RemoteEvent") then
		parryRemote = found
		break
	end

	-- Поиск в подпапках
	for _, folder in ipairs({"Remotes", "Events", "RemoteEvents", "GameRemotes", "Combat"}) do
		local parent = ReplicatedStorage:FindFirstChild(folder)
		if parent then
			found = parent:FindFirstChild(name)
			if found and found:IsA("RemoteEvent") then
				parryRemote = found
				break
			end
		end
	end

	if parryRemote then break end
end

if parryRemote then
	print("[AutoParry] Найден RemoteEvent для парирования: " .. parryRemote:GetFullName())
else
	warn("[AutoParry] RemoteEvent для парирования не найден.")
	warn("[AutoParry] Работаем в режиме симуляции (без реальной отправки).")
end

-- === Статистика ===
local stats = {
	attacksDetected = 0,     -- Обнаружено атак
	parriesSent = 0,         -- Отправлено парирований
	reactionTimes = {},      -- Массив времён реакции
	connections = {},        -- Активные подключения (для очистки)
	active = true,           -- Флаг активности
}

-- === Вспомогательные функции ===

--- Проверяет, является ли анимация атакой
--- @param animationId string — ID анимации
--- @param animationName string — Имя анимации
--- @return boolean
local function isAttackAnimation(animationId, animationName)
	local checkStr = (animationName or ""):lower() .. " " .. (animationId or ""):lower()
	for _, pattern in ipairs(ATTACK_ANIMATION_PATTERNS) do
		if checkStr:find(pattern) then
			return true
		end
	end
	return false
end

--- Отправляет парирование и логирует время реакции
--- @param detectionTime number — Время обнаружения атаки (tick())
--- @param attackerName string — Имя атакующего
--- @param animInfo string — Информация об анимации
local function executeParry(detectionTime, attackerName, animInfo)
	if not stats.active then return end
	if stats.parriesSent >= CONFIG.MAX_PARRIES then
		print("[AutoParry] Достигнут лимит парирований. Останавливаем.")
		stats.active = false
		return
	end

	-- Симуляция задержки (0 = мгновенно, нечеловеческая скорость)
	if CONFIG.REACTION_DELAY > 0 then
		task.wait(CONFIG.REACTION_DELAY)
	end

	local parryTime = tick()
	local reactionMs = (parryTime - detectionTime) * 1000 -- В миллисекундах

	-- Отправляем парирование
	local success, err = pcall(function()
		if parryRemote then
			parryRemote:FireServer()
		end
	end)

	stats.parriesSent = stats.parriesSent + 1
	table.insert(stats.reactionTimes, reactionMs)

	-- Определяем, реалистично ли время реакции
	local humanPossible = reactionMs >= 150 -- Минимальная человеческая реакция ~150мс
	local statusIcon = humanPossible and "👤" or "🤖"

	if CONFIG.LOG_DETAILS then
		print(string.format(
			"  %s Парирование #%d | Атакующий: %s | Реакция: %.2f мс | %s",
			statusIcon,
			stats.parriesSent,
			attackerName,
			reactionMs,
			humanPossible and "Человеческая скорость" or "НЕЧЕЛОВЕЧЕСКАЯ СКОРОСТЬ"
		))
		if animInfo then
			print(string.format("      Анимация: %s", animInfo))
		end
		if not success then
			print(string.format("      ✗ Ошибка отправки: %s", tostring(err)))
		end
	end
end

--- Мониторит анимации конкретного персонажа
--- @param character Model — Модель персонажа
--- @param playerName string — Имя игрока
local function monitorCharacter(character, playerName)
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Получаем Animator (анимации проигрываются через него)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		-- Ждём появления Animator
		animator = humanoid:WaitForChild("Animator", 3)
	end

	if not animator then
		print(string.format("  [AutoParry] Animator не найден у %s", playerName))
		return
	end

	-- Подключаемся к событию проигрывания анимации
	local conn = animator.AnimationPlayed:Connect(function(animationTrack)
		if not stats.active then return end

		local detectionTime = tick()
		stats.attacksDetected = stats.attacksDetected + 1

		local animId = animationTrack.Animation and animationTrack.Animation.AnimationId or "unknown"
		local animName = animationTrack.Name or "unnamed"

		-- Проверяем, похожа ли анимация на атаку
		if isAttackAnimation(animId, animName) then
			print(string.format("  ⚡ Обнаружена атака от %s! (анимация: %s)", playerName, animName))
			-- Мгновенное парирование
			executeParry(detectionTime, playerName, animName .. " [" .. animId .. "]")
		else
			-- Даже если не распознали как атаку — пробуем парировать
			-- (параноидальный режим автопарри)
			if CONFIG.LOG_DETAILS then
				print(string.format("  📌 Анимация от %s: %s (ID: %s) — не атака, но парируем", playerName, animName, animId))
			end
			executeParry(detectionTime, playerName, animName .. " [" .. animId .. "] (не подтверждённая атака)")
		end
	end)

	table.insert(stats.connections, conn)
	print(string.format("[AutoParry] Мониторинг %s активирован (Animator подключён)", playerName))
end

-- ============================================================
-- ОСНОВНАЯ ЛОГИКА: Мониторинг всех игроков
-- ============================================================
print("\n--- Запуск мониторинга атак ---")

-- Мониторим всех существующих игроков (кроме себя)
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= localPlayer then
		if player.Character then
			monitorCharacter(player.Character, player.Name)
		end

		-- Подключаемся к появлению нового персонажа
		local conn = player.CharacterAdded:Connect(function(character)
			task.wait(0.5) -- Ждём загрузки модели
			monitorCharacter(character, player.Name)
		end)
		table.insert(stats.connections, conn)
	end
end

-- Мониторим новых игроков
local playerAddedConn = Players.PlayerAdded:Connect(function(player)
	print(string.format("[AutoParry] Новый игрок: %s — начинаю мониторинг", player.Name))

	if player.Character then
		monitorCharacter(player.Character, player.Name)
	end

	local conn = player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		monitorCharacter(character, player.Name)
	end)
	table.insert(stats.connections, conn)
end)
table.insert(stats.connections, playerAddedConn)

-- ============================================================
-- ДОПОЛНИТЕЛЬНО: Мониторинг получения урона (альтернативный триггер)
-- ============================================================
local function setupDamageMonitor()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Мониторинг изменения здоровья (получения урона)
	local lastHealth = humanoid.Health
	local healthConn = humanoid.HealthChanged:Connect(function(newHealth)
		if not stats.active then return end

		if newHealth < lastHealth then
			local damageTime = tick()
			local damage = lastHealth - newHealth
			print(string.format("  💥 Получен урон: %.1f (здоровье: %.1f → %.1f)", damage, lastHealth, newHealth))
			-- Это уже поздно для парирования, но логируем для анализа
		end
		lastHealth = newHealth
	end)
	table.insert(stats.connections, healthConn)

	-- Очистка при смерти
	local diedConn = humanoid.Died:Connect(function()
		print("[AutoParry] Персонаж умер. Ожидаем респавн...")
	end)
	table.insert(stats.connections, diedConn)
end

-- Применяем к текущему персонажу
if localPlayer.Character then
	setupDamageMonitor()
end

-- И к будущим персонажам
local charConn = localPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.5)
	setupDamageMonitor()
end)
table.insert(stats.connections, charConn)

-- ============================================================
-- АВТОМАТИЧЕСКАЯ ОСТАНОВКА И ОТЧЁТ
-- ============================================================

-- Останавливаемся через 60 секунд или при достижении лимита
task.delay(60, function()
	if not stats.active then return end
	stats.active = false

	print("\n==============================================")
	print("[AutoParry] Тест завершён (таймаут 60 сек)")

	-- Очищаем подключения
	for _, conn in ipairs(stats.connections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end

	-- Выводим итоговую статистику
	print(string.format("[AutoParry] Статистика:"))
	print(string.format("  Обнаружено анимаций: %d", stats.attacksDetected))
	print(string.format("  Отправлено парирований: %d", stats.parriesSent))

	if #stats.reactionTimes > 0 then
		-- Вычисляем среднее, мин и макс время реакции
		local sum = 0
		local minTime = math.huge
		local maxTime = 0

		for _, rt in ipairs(stats.reactionTimes) do
			sum = sum + rt
			minTime = math.min(minTime, rt)
			maxTime = math.max(maxTime, rt)
		end

		local avgTime = sum / #stats.reactionTimes
		local belowHuman = 0
		for _, rt in ipairs(stats.reactionTimes) do
			if rt < 150 then
				belowHuman = belowHuman + 1
			end
		end

		print(string.format("  Среднее время реакции: %.2f мс", avgTime))
		print(string.format("  Минимальное: %.2f мс", minTime))
		print(string.format("  Максимальное: %.2f мс", maxTime))
		print(string.format("  Ниже человеческого порога (<150мс): %d из %d (%.0f%%)",
			belowHuman, #stats.reactionTimes, (belowHuman / #stats.reactionTimes) * 100))
	end

	print("\n[AutoParry] Ожидаемое поведение сервера:")
	print("  ✓ Парирования с временем реакции <150мс — отклонены")
	print("  ✓ Игрок помечен как подозрительный")
	print("  ✓ Серверная проверка таймингов активна")
	print("==============================================")
end)

print("\n[AutoParry] Мониторинг запущен. Тест продлится 60 секунд.")
print("[AutoParry] Атакуйте другим игроком, чтобы увидеть срабатывание.")
print("[AutoParry] Для ручной остановки: скрипт завершится автоматически.")
