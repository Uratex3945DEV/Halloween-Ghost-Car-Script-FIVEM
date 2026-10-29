local ESX = exports['SpinFramework'] and exports['SpinFramework']:getSharedObject()
if not ESX then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end

local function notify(msg, type)
    ESX.ShowNotification(msg, type or 'info', 5000)
end

local active = false
local ghostCar, ghostDriver = nil, nil

local function loadModel(model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() - t > 5000 then return false end
    end
    return true
end

-- Cherche un point de route à ~distance du centre donné
local function getRoadSpawn(center, distance)
    for _ = 1, 15 do
        local angle = math.random() * 2 * math.pi
        local x = center.x + math.cos(angle) * distance
        local y = center.y + math.sin(angle) * distance
        local found, pos = GetClosestVehicleNodeWithHeading(x, y, center.z, 1, 3.0, 0)
        if found and #(vector3(pos.x, pos.y, pos.z) - center) > distance * 0.5 then
            return vector3(pos.x, pos.y, pos.z)
        end
    end
    return GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, -distance, 0.0)
end

local function cleanup()
    if ghostDriver and DoesEntityExist(ghostDriver) then
        SetEntityAsMissionEntity(ghostDriver, true, true)
        DeletePed(ghostDriver)
    end
    if ghostCar and DoesEntityExist(ghostCar) then
        SetEntityAsMissionEntity(ghostCar, true, true)
        DeleteVehicle(ghostCar)
    end
    ghostCar, ghostDriver = nil, nil
    AnimpostfxStop('Rampage')
end

-- Spawn de la voiture fantôme (locale : visible uniquement par le joueur ciblé)
local function spawnGhost(center)
    local model = Config.CarModels[math.random(#Config.CarModels)]
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return nil end
    if not loadModel(model) or not loadModel(Config.DriverModel) then return nil end

    local pos = getRoadSpawn(center, Config.SpawnDistance)
    local heading = GetHeadingFromVector_2d(center.x - pos.x, center.y - pos.y)

    local car = CreateVehicle(model, pos.x, pos.y, pos.z, heading, false, false)
    SetModelAsNoLongerNeeded(model)
    if not car or car == 0 then return nil end

    SetEntityAsMissionEntity(car, true, true)
    SetVehicleOnGroundProperly(car)
    SetVehicleEngineOn(car, true, true, false)
    SetVehicleLights(car, 2)
    SetVehicleFullbeam(car, true)
    SetEntityInvincible(car, true)
    SetVehicleCanBeVisiblyDamaged(car, false)
    SetVehicleDoorsLocked(car, 2)
    SetVehicleCustomPrimaryColour(car, Config.GhostColor[1], Config.GhostColor[2], Config.GhostColor[3])
    SetVehicleCustomSecondaryColour(car, Config.GhostColor[1], Config.GhostColor[2], Config.GhostColor[3])
    SetEntityAlpha(car, Config.GhostAlpha, false)
    ModifyVehicleTopSpeed(car, Config.TopSpeedBoost)
    SetEntityMaxSpeed(car, Config.TargetSpeed + 10.0)
    SetVehicleEnginePowerMultiplier(car, Config.EnginePower)

    -- conducteur invisible
    local driver = CreatePedInsideVehicle(car, 26, Config.DriverModel, -1, false, false)
    SetModelAsNoLongerNeeded(Config.DriverModel)
    SetEntityVisible(driver, false, false)
    SetEntityInvincible(driver, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedCanBeDraggedOut(driver, false)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 1.0)
    SetPedKeepTask(driver, true)

    return car, driver
end

-- Choc : projette le joueur (éjecté s'il est en véhicule), sans dégâts
local function impact(car, pPed, pVeh)
    SetPlayerInvincible(PlayerId(), true)
    local dir = GetEntityForwardVector(car)
    if pVeh ~= 0 then
        ApplyForceToEntity(pVeh, 1, dir.x * Config.VehicleForce, dir.y * Config.VehicleForce, Config.VehicleForce * 0.3, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        if not Config.EjectOnImpact then return end
        TaskLeaveVehicle(pPed, pVeh, 16)  -- 16 = sortie instantanée
        Wait(100)
        pPed = PlayerPedId()
    end
    SetPedToRagdoll(pPed, 3000, 3000, 0, false, false, false)
    ApplyForceToEntity(pPed, 1, dir.x * Config.PedForce, dir.y * Config.PedForce, Config.PedForce * 0.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
end

-- KO : le joueur reste au sol, contrôles bloqués, écran noir
local function knockOut()
    local koEnd = GetGameTimer() + Config.KODuration
    if Config.KOFade then DoScreenFadeOut(400) end
    while GetGameTimer() < koEnd do
        Wait(0)
        local pPed = PlayerPedId()
        if IsEntityDead(pPed) then break end
        DisableAllControlActions(0)
        if not IsPedRagdoll(pPed) then
            SetPedToRagdoll(pPed, 1000, 1000, 0, false, false, false)
        end
    end
    if Config.KOFade then DoScreenFadeIn(1000) end
end

local function startGhostCar()
    if active then return end
    active = true

    local pPed = PlayerPedId()
    if IsEntityDead(pPed) then active = false return end

    local car, driver = spawnGhost(GetEntityCoords(pPed))
    if not car then
        active = false
        return
    end
    ghostCar, ghostDriver = car, driver

    notify('🎃 Une voiture fantôme te fonce dessus !', 'error')
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    AnimpostfxPlay('Rampage', 0, true)

    local endTime = GetGameTimer() + Config.Duration * 1000
    local lastTask, lastFlicker, lastHorn, stuckSince = 0, 0, 0, 0
    local result = 'survived'
    local wasInvincible = GetPlayerInvincible(PlayerId())

    while active do
        Wait(0)
        pPed = PlayerPedId()
        local now = GetGameTimer()

        if IsEntityDead(pPed) then result = 'killed' break end
        if now >= endTime then break end
        if not DoesEntityExist(car) or not DoesEntityExist(driver) then break end

        local pCoords = GetEntityCoords(pPed)
        local pVeh = GetVehiclePedIsIn(pPed, false)
        local dist = #(GetEntityCoords(car) - pCoords)
        local speed = GetEntitySpeed(car)

        -- protection : le joueur ne peut pas mourir pendant l'approche de la voiture
        if dist < Config.ProtectDistance then
            SetPlayerInvincible(PlayerId(), true)
        elseif dist > Config.ProtectDistance + 10.0 then
            SetPlayerInvincible(PlayerId(), wasInvincible)
        end

        -- poursuite (relancée régulièrement)
        if now - lastTask > 2000 then
            lastTask = now
            TaskVehicleChase(driver, pPed)
            SetTaskVehicleChaseIdealPursuitDistance(driver, 1.0)
            SetDriveTaskCruiseSpeed(driver, Config.TargetSpeed)
        end

        -- accélération forcée : la voiture roule vite jusqu'à la vitesse visée
        if speed > 3.0 and speed < Config.TargetSpeed and IsVehicleOnAllWheels(car)
            and GetEntitySpeedVector(car, true).y > 0.0 then
            SetVehicleForwardSpeed(car, math.min(speed + Config.Acceleration * GetFrameTime(), Config.TargetSpeed))
        end

        -- effet fantôme : transparence qui clignote
        if now - lastFlicker > 150 then
            lastFlicker = now
            local a = math.max(30, math.min(255, Config.GhostAlpha + math.random(-50, 50)))
            SetEntityAlpha(car, a, false)
        end

        -- klaxon quand elle approche
        if dist < 35.0 and now - lastHorn > 1500 then
            lastHorn = now
            StartVehicleHorn(car, 700, `HELDDOWN`, false)
        end

        -- bloquée : on la replace sur une route autour du joueur
        if speed < 2.0 and dist > Config.ImpactDistanceVehicle + 5.0 then
            if stuckSince == 0 then
                stuckSince = now
            elseif now - stuckSince > Config.StuckTimeout then
                local pos = getRoadSpawn(pCoords, Config.SpawnDistance)
                SetEntityCoordsNoOffset(car, pos.x, pos.y, pos.z, false, false, false)
                SetEntityHeading(car, GetHeadingFromVector_2d(pCoords.x - pos.x, pCoords.y - pos.y))
                SetVehicleOnGroundProperly(car)
                stuckSince = 0
                lastTask = 0
            end
        else
            stuckSince = 0
        end

        -- impact
        local hitDist = pVeh ~= 0 and Config.ImpactDistanceVehicle or Config.ImpactDistance
        if dist <= hitDist and speed > 5.0 then
            impact(car, pPed, pVeh)
            result = 'hit'
            break
        end
    end

    cleanup()
    if result == 'hit' and Config.KnockOut then
        knockOut()
    end
    SetPlayerInvincible(PlayerId(), wasInvincible)
    active = false

    if result == 'survived' then
        notify('🎃 La voiture fantôme a disparu... tu as survécu !', 'success')
    elseif result == 'hit' and not IsEntityDead(PlayerPedId()) then
        notify('🎃 La voiture fantôme t\'a mis KO !', 'warning')
    end
end

RegisterNetEvent('halloween_ghostcar:start', startGhostCar)

RegisterNetEvent('halloween_ghostcar:stop', function()
    active = false
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then cleanup() end
end)
