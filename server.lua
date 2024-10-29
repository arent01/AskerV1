local webhookUrl = '' -- Ссылка на хук
local questionCount = 0
local lastQuestionTime = {} -- Хранит время последней отправки вопроса для каждого игрока
local cooldown = 60 -- 1 минута в секундах
local activeQuestions = {} -- Хранит активные вопросы
local adminsMuted = {} -- Хранит состояние отключения уведомлений для администраторов


-- Список администраторов по их FiveM ID
local adminIds = {
    "fivem:1234567890", -- Указывать все id через запятую
}

RegisterServerEvent('ask:send')
AddEventHandler('ask:send', function(playerId, playerName, question)
    local currentTime = os.time()
    local fivemId = getFiveMId(playerId)

    if lastQuestionTime[playerId] and currentTime - lastQuestionTime[playerId] < cooldown then
        local timeLeft = cooldown - (currentTime - lastQuestionTime[playerId])
        local minutes = math.floor(timeLeft / 60)
        local seconds = timeLeft % 60

        -- Отправляем сообщение в консоль игрока
        TriggerClientEvent('chat:addMessage', playerId, {
            color = {255, 165, 0}, -- оранжевый
            args = {"Система", string.format("До следующего вопроса осталось: %d минут и %d секунд", minutes, seconds)}
        })

        TriggerClientEvent('chat:addMessage', playerId, {
            color = {255, 165, 0},
            args = {"Система", "Вы можете задавать вопросы раз в минуту."}
        })
        return
    end

    questionCount = questionCount + 1
    local questionId = questionCount
    lastQuestionTime[playerId] = currentTime
    activeQuestions[questionId] = {playerId = playerId, playerName = playerName, question = question}

    TriggerClientEvent('chat:addMessage', playerId, {
        color = {255, 165, 0}, -- оранжевый
        args = {"Система", "Ваш вопрос #" .. questionId .. " был успешно отправлен."}
    })

    sendToDiscord(questionId, playerName, fivemId, question, "Новый вопрос", 65280) -- зелёный цвет

    -- Уведомление администраторам
    for _, adminId in ipairs(GetPlayers()) do
        if isAdmin(adminId) and not adminsMuted[adminId] then
            TriggerClientEvent('ask:notifyAdmin', adminId, questionId, playerName, question)
            TriggerClientEvent('ask:playSound', adminId) -- Звуковое уведомление
        end
    end
end)

RegisterServerEvent('ask:respond')
AddEventHandler('ask:respond', function(adminId, questionId, response)
    local adminFivemId = getFiveMId(adminId)
    if isAdmin(adminId) then
        local adminName = GetPlayerName(adminId)
        if activeQuestions[questionId] then
            local question = activeQuestions[questionId]
            local playerFivemId = getFiveMId(question.playerId)
            TriggerClientEvent('ask:receiveResponse', question.playerId, questionId, adminName, response)
            sendResponseToDiscord(questionId, adminName, adminFivemId, question.playerName, playerFivemId, question.question, response)
            TriggerClientEvent('ask:notifyClosed', question.playerId, questionId) -- Уведомление конкретному игроку о закрытии вопроса

            -- Уведомление для администратора о закрытии тикета
            TriggerClientEvent('chat:addMessage', adminId, {
                color = {255, 0, 0}, -- красный
                args = {"Система", "Вопрос #" .. questionId .. " был успешно закрыт."}
            })

            activeQuestions[questionId] = nil -- Закрываем вопрос
        else
            TriggerClientEvent('chat:addMessage', adminId, {
                color = {255, 165, 0}, -- оранжевый
                args = {"Система", "Вопрос #" .. questionId .. " уже закрыт или не существует."}
            })
        end
    else
        TriggerClientEvent('chat:addMessage', adminId, {
            color = {255, 165, 0}, -- оранжевый
            args = {"Система", "У вас нет прав для ответа на вопросы."}
        })
    end
end)


RegisterServerEvent('ask:toggleAnswers')
AddEventHandler('ask:toggleAnswers', function(adminId)
    if isAdmin(adminId) then
        adminsMuted[adminId] = not adminsMuted[adminId]
        local status = adminsMuted[adminId] and "отключены" or "включены"
        TriggerClientEvent('chat:addMessage', adminId, {
            color = {255, 165, 0}, -- оранжевый
            args = {"Система", "Уведомления о вопросах " .. status .. "."}
        })
    else
        TriggerClientEvent('chat:addMessage', adminId, {
            color = {255, 165, 0}, -- оранжевый
            args = {"Система", "У вас нет прав для выполнения этой команды."}
        })
    end
end)


function isAdmin(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, id in ipairs(identifiers) do
        if isAdminId(id) then
            return true
        end
    end
    return false
end

function isAdminId(id)
    for _, adminId in ipairs(adminIds) do
        if adminId == id then
            return true
        end
    end
    return false
end

function getFiveMId(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 6) == "fivem:" then
            return string.sub(id, 7) -- Убираем префикс "fivem:"
        end
    end
    return "неизвестно"
end

function sendToDiscord(questionId, playerName, playerFivemId, question, title, color)
    local embed = {
        {
            ["color"] = color,
            ["title"] = title .. " #" .. questionId,
            ["description"] = "Игрок: " .. playerName .. "\nUser ID: " .. playerFivemId .. "\nВопрос: " .. question,
            ["footer"] = {
                ["text"] = os.date("!%Y-%m-%d %H:%M:%S", os.time() + 3 * 3600) .. " МСК" -- Московское время
            }
        }
    }
    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({username = "AskerV1", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

function sendResponseToDiscord(questionId, adminName, adminFivemId, playerName, playerFivemId, question, response)
    local embed = {
        {
            ["color"] = 16711680, -- красный цвет для ответа
            ["title"] = "Ответ на вопрос #" .. questionId,
            ["description"] = "Администратор: " .. adminName .. "\nAdmin ID: " .. adminFivemId ..
                "\n\n**Ответ на вопрос:**\n" .. response ..
                "\n\n---\n\nИгрок: " .. playerName .. "\nUser ID: " .. playerFivemId .. "\nТекст вопроса: " .. question,
            ["footer"] = {
                ["text"] = os.date("!%Y-%m-%d %H:%M:%S", os.time() + 3 * 3600) .. " МСК" -- Московское время
            }
        }
    }
    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({username = "AskerV1", embeds = embed}), { ['Content-Type'] = 'application/json' })
end