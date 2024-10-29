local notificationsEnabled = true

RegisterCommand('ask', function()
    local playerId = GetPlayerServerId(PlayerId())
    local playerName = GetPlayerName(PlayerId())

    local question = KeyboardInput("Введите ваш вопрос", "", 255)

    if question then
        TriggerServerEvent('ask:send', playerId, playerName, question)
    else
        print('Некорректные данные')
    end
end, false)

RegisterCommand('answer', function()
    local questionId = tonumber(KeyboardInput("Введите ID вопроса", "", 10))
    local response = KeyboardInput("Введите ваш ответ", "", 255)

    if questionId and response then
        TriggerServerEvent('ask:respond', GetPlayerServerId(PlayerId()), questionId, response)
    else
        print('Некорректные данные для ответа на вопрос')
    end
end, false)

RegisterCommand('toggleanswers', function()
    notificationsEnabled = not notificationsEnabled
    local status = notificationsEnabled and "включены" or "отключены"
    TriggerServerEvent('ask:toggleAnswers', GetPlayerServerId(PlayerId()))
end, false)

RegisterNetEvent('ask:receiveResponse')
AddEventHandler('ask:receiveResponse', function(questionId, adminName, response)
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0}, -- оранжевый
        args = {"Система", "Вы получили ответ на ваш вопрос #" .. questionId .. " от " .. adminName .. ": " .. response}
    })
end)

RegisterNetEvent('ask:notifyAdmin')
AddEventHandler('ask:notifyAdmin', function(questionId, playerName, question)
    if notificationsEnabled then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0}, -- зеленый
            args = {"Система", "Новый вопрос #" .. questionId .. " от " .. playerName .. ": " .. question}
        })
    end
end)

RegisterNetEvent('ask:playSound')
AddEventHandler('ask:playSound', function()
    if notificationsEnabled then
        -- Воспроизведение звука уведомления
        PlaySoundFrontend(-1, "CHARACTER_SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
end)

function KeyboardInput(textEntry, exampleText, maxStringLength)
    AddTextEntry('FMMC_KEY_TIP1', textEntry) 
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", exampleText, "", "", "", maxStringLength)
    blockinput = true

    while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
        Wait(0)
    end

    if UpdateOnscreenKeyboard() ~= 2 then
        local result = GetOnscreenKeyboardResult()
        Wait(500)
        blockinput = false
        return result
    else
        Wait(500)
        blockinput = false
        return nil
    end
end
