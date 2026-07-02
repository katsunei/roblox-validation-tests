--[[
	=============================================================
	  ТЕСТОВЫЙ СКРИПТ #14 — Бесконечная выносливость
	=============================================================
	  Назначение:
	    Симуляция чита «Infinite Stamina». Замораживает
	    выносливость на максимальном значении, перехватывая
	    любые попытки её уменьшения.

	  Что тестируется на стороне сервера:
	    • Авторитетно ли сервер отслеживает выносливость
	    • Принимает ли сервер действия от клиента с нулевой
	      выносливостью (спринт, уклонение, атака)
	    • Обрабатывает ли сервер RemoteEvent на восстановление

	  Использование:
	    Вставить в CommandBar Roblox Studio.
	    _G.InfiniteStamina_Cleanup() — отключить.
	=============================================================
--]]

-- ============================================================
-- Сервисы
-- ============================================================
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer

-- ============================================================
-- Конфигурация
-- ============================================================
local CONFIG = {
	-- Значение, на которое устанавливается выносливость
	TargetStamina    = 100,
	-- Интервал принудительной установки (секунды)
	ForceInterval    = 0.05,
	-- Искать RemoteEvent'ы для восстановления выносливости
	TryRemotes       = true,
	-- Паттерны имён RemoteEvent'ов для восстановления
	RemotePatterns   = {"Stamina", "stamina", "RestoreStamina", "RegenStamina", "SetStamina"},
}

-- ============================================================
-- Состояние
-- ============================================================
local connections      = {}  -- Все активные соединения
local active           = false
local originalStamina  = nil
local stats = {
	blockedDrains   = 0,     -- Заблокированных уменьшений
	remotesFired    = 0,     -- Отправленных RemoteEvent'ов
	totalRestored   = 0,     -- Общее кол-во восстановлений
	startTime       = 0,
}

-- ============================================================
-- Поиск объекта выносливости
-- ============================================================

--- Ищет значение выносливости во всех возможных местах
local function findStaminaSources()
	local sources = {}
	local character = LocalPlayer.Character

	-- 1. Атрибут «Stamina» на персонаже
	if character then
		local val = character:GetAttribute("Stamina")
		if val ~= nil then
			table.insert(sources, {
				type  = "attribute",
				owner = character,
				name  = "Stamina",
				value = val,
			})
			print("[InfStamina] Найден атрибут Stamina на персонаже:", val)
		end
	end

	-- 2. Атрибут «Stamina» на объекте игрока
	local val = LocalPlayer:GetAttribute("Stamina")
	if val ~= nil then
		table.insert(sources, {
			type  = "attribute",
			owner = LocalPlayer,
			name  = "Stamina",
			value = val,
		})
		print("[InfStamina] Найден атрибут Stamina на Player:", val)
	end

	-- 3. NumberValue / IntValue в персонаже
	if character then
		for _, child in ipairs(character:GetDescendants()) do
			if (child:IsA("NumberValue") or child:IsA("IntValue"))
				and child.Name:lower():find("stamina") then
				table.insert(sources, {
					type     = "valueObject",
					instance = child,
					value    = child.Value,
				})
				print("[InfStamina] Найден ValueObject:", child:GetFullName(), "=", child.Value)
			end
		end
	end

	-- 4. leaderstats или PlayerGui-значения
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		for _, child in ipairs(leaderstats:GetChildren()) do
			if child.Name:lower():find("stamina") and
				(child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue")) then
				table.insert(sources, {
					type     = "valueObject",
					instance = child,
					value    = child.Value,
				})
				print("[InfStamina] Найден leaderstats ValueObject:", child.Name, "=", child.Value)
			end
		end
	end

	return sources
end

-- ============================================================
-- Поиск RemoteEvent'ов для выносливости
-- ============================================================
local function findStaminaRemotes()
	local remotes = {}
	local searchLocations = {
		game:GetService("ReplicatedStorage"),
	}

	-- Пытаемся добавить другие места поиска (могут быть недоступны)
	pcall(function()
		table.insert(searchLocations, game:GetService("ReplicatedFirst"))
	end)

	for _, location in ipairs(searchLocations) do
		for _, desc in ipairs(location:GetDescendants()) do
			if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
				for _, pattern in ipairs(CONFIG.RemotePatterns) do
					if desc.Name:find(pattern) then
						table.insert(remotes, desc)
						print("[InfStamina] Найден Remote:", desc:GetFullName())
						break
					end
				end
			end
		end
	end

	return remotes
end

-- ============================================================
-- Заморозка выносливости через атрибут
-- ============================================================
local function freezeAttribute(owner, attrName, targetValue)
	-- Устанавливаем сразу
	pcall(function()
		owner:SetAttribute(attrName, targetValue)
	end)

	-- Подписываемся на изменения
	local conn = owner:GetAttributeChangedSignal(attrName):Connect(function()
		local current = owner:GetAttribute(attrName)
		if current ~= targetValue then
			stats.blockedDrains += 1
			local drained = targetValue - (current or 0)
			print(string.format(
				"[InfStamina] Заблокировано уменьшение: %.1f -> %.1f (потрачено: %.1f)",
				current or 0, targetValue, drained
			))
			pcall(function()
				owner:SetAttribute(attrName, targetValue)
			end)
			stats.totalRestored += 1
		end
	end)
	table.insert(connections, conn)
end

-- ============================================================
-- Заморозка выносливости через ValueObject
-- ============================================================
local function freezeValueObject(valueObj, targetValue)
	-- Устанавливаем сразу
	pcall(function()
		valueObj.Value = targetValue
	end)

	-- Подписываемся на изменения
	local conn = valueObj.Changed:Connect(function(newVal)
		if newVal ~= targetValue then
			stats.blockedDrains += 1
			print(string.format(
				"[InfStamina] Заблокировано (ValueObject): %.1f -> %.1f",
				newVal, targetValue
			))
			pcall(function()
				valueObj.Value = targetValue
			end)
			stats.totalRestored += 1
		end
	end)
	table.insert(connections, conn)
end

-- ============================================================
-- Попытка отправки RemoteEvent для восстановления
-- ============================================================
local function tryFireRemotes(remotes)
	for _, remote in ipairs(remotes) do
		pcall(function()
			if remote:IsA("RemoteEvent") then
				remote:FireServer(CONFIG.TargetStamina)
				remote:FireServer("restore", CONFIG.TargetStamina)
				remote:FireServer("set", CONFIG.TargetStamina)
				stats.remotesFired += 3
				print("[InfStamina] Отправлен RemoteEvent:", remote.Name)
			elseif remote:IsA("RemoteFunction") then
				remote:InvokeServer(CONFIG.TargetStamina)
				stats.remotesFired += 1
				print("[InfStamina] Вызван RemoteFunction:", remote.Name)
			end
		end)
	end
end

-- ============================================================
-- Основной цикл принудительной установки
-- ============================================================
local function startForceLoop(sources, remotes)
	local conn = RunService.Heartbeat:Connect(function()
		if not active then return end

		-- Принудительно устанавливаем значение через все источники
		for _, source in ipairs(sources) do
			pcall(function()
				if source.type == "attribute" then
					local current = source.owner:GetAttribute(source.name)
					if current ~= CONFIG.TargetStamina then
						source.owner:SetAttribute(source.name, CONFIG.TargetStamina)
						stats.totalRestored += 1
					end
				elseif source.type == "valueObject" then
					if source.instance.Value ~= CONFIG.TargetStamina then
						source.instance.Value = CONFIG.TargetStamina
						stats.totalRestored += 1
					end
				end
			end)
		end
	end)
	table.insert(connections, conn)
end

-- ============================================================
-- Попытка установить глобальные переменные
-- ============================================================
local function overrideGlobals()
	-- Пытаемся установить _G-переменные, связанные со стаминой
	local globalNames = {
		"Stamina", "stamina", "CurrentStamina", "currentStamina",
		"playerStamina", "StaminaValue", "staminaCooldown",
		"canSprint", "CanSprint", "sprintEnabled",
	}

	for _, name in ipairs(globalNames) do
		pcall(function()
			if type(_G[name]) == "number" then
				print("[InfStamina] Перезаписан _G." .. name .. " =", _G[name], "->", CONFIG.TargetStamina)
				_G[name] = CONFIG.TargetStamina
			elseif type(_G[name]) == "boolean" then
				print("[InfStamina] Перезаписан _G." .. name .. " =", _G[name], "-> true")
				_G[name] = true
			end
		end)
	end

	-- Также устанавливаем свои флаги
	_G.Stamina         = CONFIG.TargetStamina
	_G.InfiniteStamina = true
	_G.canSprint       = true
end

-- ============================================================
-- Вывод статистики
-- ============================================================
local function printStats()
	local elapsed = tick() - stats.startTime
	print("\n[InfStamina] ===== СТАТИСТИКА =====")
	print("[InfStamina] Время работы:", string.format("%.1f сек", elapsed))
	print("[InfStamina] Заблокировано уменьшений:", stats.blockedDrains)
	print("[InfStamina] Remote'ов отправлено:", stats.remotesFired)
	print("[InfStamina] Восстановлений выносливости:", stats.totalRestored)
	print("[InfStamina] ========================\n")
end

-- ============================================================
-- Запуск
-- ============================================================
local function start()
	if active then
		warn("[InfStamina] Уже запущен!")
		return
	end
	active = true
	stats.startTime = tick()

	print("[InfStamina] ===== ЗАПУСК БЕСКОНЕЧНОЙ ВЫНОСЛИВОСТИ =====")

	-- Шаг 1: Ищем источники выносливости
	local sources = findStaminaSources()
	if #sources == 0 then
		warn("[InfStamina] Источники выносливости не найдены. Работаем только через глобальные переменные.")
	else
		-- Сохраняем оригинальное значение
		originalStamina = sources[1].value
		print("[InfStamina] Оригинальная выносливость:", originalStamina)
	end

	-- Шаг 2: Замораживаем каждый источник
	for _, source in ipairs(sources) do
		if source.type == "attribute" then
			freezeAttribute(source.owner, source.name, CONFIG.TargetStamina)
		elseif source.type == "valueObject" then
			freezeValueObject(source.instance, CONFIG.TargetStamina)
		end
	end

	-- Шаг 3: Ищем RemoteEvent'ы
	local remotes = {}
	if CONFIG.TryRemotes then
		remotes = findStaminaRemotes()
		if #remotes > 0 then
			tryFireRemotes(remotes)
		end
	end

	-- Шаг 4: Перезаписываем глобальные переменные
	overrideGlobals()

	-- Шаг 5: Запускаем цикл принудительной установки
	startForceLoop(sources, remotes)

	-- Шаг 6: Периодический вывод статистики
	task.spawn(function()
		while active do
			task.wait(10)
			if active then
				printStats()
			end
		end
	end)

	-- Шаг 7: Отслеживаем респавн персонажа
	local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
		task.wait(1) -- Ждём загрузку
		if not active then return end
		print("[InfStamina] Персонаж респавнился, переподключаем...")
		local newSources = findStaminaSources()
		for _, source in ipairs(newSources) do
			if source.type == "attribute" then
				freezeAttribute(source.owner, source.name, CONFIG.TargetStamina)
			elseif source.type == "valueObject" then
				freezeValueObject(source.instance, CONFIG.TargetStamina)
			end
		end
		overrideGlobals()
	end)
	table.insert(connections, charConn)

	print("[InfStamina] Выносливость заморожена на:", CONFIG.TargetStamina)
	print("[InfStamina] Для отключения: _G.InfiniteStamina_Cleanup()")
end

-- ============================================================
-- Функция очистки
-- ============================================================
local function cleanup()
	print("[InfStamina] ===== ОЧИСТКА =====")
	active = false

	-- Отключаем все соединения
	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}

	-- Восстанавливаем оригинальное значение (если было)
	if originalStamina then
		local sources = findStaminaSources()
		for _, source in ipairs(sources) do
			pcall(function()
				if source.type == "attribute" then
					source.owner:SetAttribute(source.name, originalStamina)
				elseif source.type == "valueObject" then
					source.instance.Value = originalStamina
				end
			end)
		end
		print("[InfStamina] Восстановлена оригинальная выносливость:", originalStamina)
	end

	-- Убираем глобальные флаги
	_G.InfiniteStamina = nil
	_G.canSprint       = nil

	printStats()
	print("[InfStamina] Очистка завершена.")
end

_G.InfiniteStamina_Cleanup = cleanup

-- ============================================================
-- Запуск
-- ============================================================
start()
