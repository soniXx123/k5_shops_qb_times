local QBCore = exports['qb-core']:GetCoreObject()

local openShop = nil
local loadedPeds = {}
local showingPrompt = false

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerPos = GetEntityCoords(PlayerPedId())

        for k, v in pairs(Config.Shops) do
            local distance = #(v.coords - playerPos)
            if distance < 2.0 then
                sleep = 1
                if not showingPrompt then
                    showingPrompt = true
                    exports["qb-core"]:DrawText('[E] '..v.shopName)
                end
                if IsControlJustReleased(0, 38) then
                    local userJob = QBCore.Functions.GetPlayerData().job.name
                    local isInJobs = false
                    
                    if v.sellJob ~= nil then
                        for kJ, vJ in pairs(v.sellJob) do
                            if vJ == userJob then
                                isInJobs = true
                            end
                        end
                    end

                    if v.sellOnly and v.sellJob ~= nil and not isInJobs then
                        QBCore.Functions.Notify(Config.Locales[Config.Locale].IncorrectJob, "error")
                    else
                        print(v.openingTime, v.closingTime, GlobalState.currentHour)
                        if GlobalState.currentHour < v.openingTime and GlobalState.currentHour > v.closingTime then
                            QBCore.Functions.Notify((Config.Locales[Config.Locale].ClosedShop, "error")
                        else 
                            QBCore.Functions.TriggerCallback('k5_shops:getInitalData', function(open, shopData, itemsWithInventoryCount, playerJob)
                                if open then
                                    local shopData = v
                                    shopData.items = itemsWithInventoryCount
                                    shopData.playerJob = playerJob
                                    shopData.shopId = k
                                    openShop = k
                                    TriggerServerEvent("k5_shops:lockShop", openShop)
                                    SetNuiFocus(true, true)
                                    SendNUIMessage({
                                        action = "open",
                                        data = shopData
                                    })
                                else
                                    QBCore.Functions.Notify(Config.Locales[Config.Locale].AlreadyOpen, "error")
                                end
                            end, k)
                        end
                    end
                end
            end
            if distance > 2.0 then 
                showingPrompt = false
                exports["qb-core"]:HideText()
            end
            if distance > 2.0 and openShop == k then
                closeUI()

            end
        end
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    for k, v in pairs(Config.Shops) do
        if v.blip then
            local blip = AddBlipForCoord(v.coords)

            SetBlipSprite(blip, v.blip.sprite)
            SetBlipScale(blip, v.blip.scale)
            SetBlipColour(blip, v.blip.color)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v.shopName)
            EndTextCommandSetBlipName(blip)
        end

        if v.cashierPed then
            SpawnPed(v.cashierPed)
        end
    end
end)

function SpawnPed(data)
    RequestModel(data.ped)
    while not HasModelLoaded(data.ped)  do
        Wait(100)
    end
    
    local ped = CreatePed(1, data.ped, data.coords[1], data.coords[2], data.coords[3], data.heading, false, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
  
    table.insert(loadedPeds, ped)
end

RegisterNetEvent('k5_shops:resetUI')
AddEventHandler('k5_shops:resetUI', function(shopName)
    QBCore.Functions.TriggerCallback('k5_shops:getInitalData', function(shopData, itemsWithInventoryCount, playerJob)
        local shopData = Config.Shops[shopName]
        shopData.items = itemsWithInventoryCount
        shopData.playerJob = playerJob
        shopData.shopId = shopName
        SendNUIMessage({
            action = "reset",
            data = shopData
        })
    end, shopName)
end)

RegisterNUICallback("action", function(data, cb)
	if data.action == "close" then
		closeUI()
    elseif data.action == "buyItems" then
        TriggerServerEvent("k5_shops:checkMoney", data.data)
    elseif data.action == "sellItems" then
        TriggerServerEvent("k5_shops:sellItems", data.data)
    end
end)

function closeUI()
    SendNUIMessage({
        action = "close"
    })
    SetNuiFocus(false, false)
    TriggerServerEvent("k5_shops:unlockShop", openShop)
    openShop = nil
end

RegisterNetEvent('k5_shops:closeUI')
AddEventHandler('k5_shops:closeUI', function()
    closeUI()
end)
