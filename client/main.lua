-- ============================================================
-- client/main.lua — tb-mdt client
-- Uses ox_lib for callbacks, notifications, text UI.
-- Framework auto-detected via shared/framework.lua
-- ============================================================

local isMDTOpen  = false
local nearMDT    = false
local currentMDTStation = nil

--- Get QBCore PlayerData (works for both Qbox and QBCore).
local function GetPlayerData()
    if Framework.name == 'qbox' then
        return exports.qbx_core:GetPlayerData()
    else
        return exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
    end
end

--- Check if this player holds an allowed job.
local function IsAllowedJob()
    local pd = GetPlayerData()
    if not pd or not pd.job then return false end
    for _, name in ipairs(Config.AllowedJobs) do
        if pd.job.name == name then return true end
    end
    return false
end

-- ─── Two-loop proximity check for physical terminals ────────

if Config.UsePhysicalTerminals then
    -- Slow loop: scan for nearby stations
    CreateThread(function()
        while true do
            local coords = GetEntityCoords(PlayerPedId())
            local found = false
            for _, station in ipairs(Config.MDTStations) do
                if #(coords - station) < Config.TerminalScanDist then
                    found = true
                    currentMDTStation = station
                    break
                end
            end
            nearMDT = found
            Wait(1000)
        end
    end)

    -- Fast loop: interaction when close
    CreateThread(function()
        while true do
            if nearMDT and currentMDTStation then
                local coords = GetEntityCoords(PlayerPedId())
                if #(coords - currentMDTStation) < Config.TerminalInteractDist then
                    DrawMarker(2,
                        currentMDTStation.x, currentMDTStation.y, currentMDTStation.z + 1.0,
                        0.0, 0.0, 0.0,  0.0, 0.0, 0.0,
                        0.3, 0.3, 0.2,
                        66, 135, 245, 150,
                        false, true, 2, false, nil, nil, false
                    )
                    lib.showTextUI(Locales['mdt_open'])

                    if IsControlJustReleased(0, 38) then -- E key
                        lib.hideTextUI()
                        OpenMDT()
                    end
                    Wait(0)
                else
                    lib.hideTextUI()
                    Wait(200)
                end
            else
                Wait(1000)
            end
        end
    end)
end

-- ─── Keybinds ───────────────────────────────────────────────

RegisterCommand(Config.Keybinds.OpenMDT.command, function()
    if not IsAllowedJob() then
        lib.notify({ title = 'MDT', description = Locales['mdt_no_permission'], type = 'error' })
        return
    end

    local pd = GetPlayerData()
    if not pd.job.onduty then
        lib.notify({ title = 'MDT', description = Locales['mdt_not_on_duty'], type = 'error' })
        return
    end

    OpenMDT()
end, false)
RegisterKeyMapping(Config.Keybinds.OpenMDT.command, Config.Keybinds.OpenMDT.description, 'keyboard', Config.Keybinds.OpenMDT.key)

-- ─── Open / Close MDT ───────────────────────────────────────

function OpenMDT()
    if isMDTOpen then return end

    local data = lib.callback.await('tb-mdt:server:getInitialData', false)
    if not data then return end

    local pd = GetPlayerData()
    local dept = Config.Departments[pd.job.name] or Config.Departments.police

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMDT',
        data   = data,
        player = {
            name        = pd.charinfo.firstname .. ' ' .. pd.charinfo.lastname,
            callsign    = pd.metadata.callsign or 'NO CALLSIGN',
            department  = dept,
            rank        = pd.job.grade.name,
            gradeLevel  = pd.job.grade.level,
            permissions = Config.Permissions[pd.job.name] and Config.Permissions[pd.job.name].features or {},
        },
        config = {
            ui         = Config.UI,
            priority   = Config.DispatchPriority,
            offenses   = Config.OffenseCategories,
            evidence   = Config.EvidenceTypes,
            penalCode  = Config.PenalCode,
        },
    })

    isMDTOpen = true
    StartRealTimeUpdates()
end

function CloseMDT()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMDT' })
    isMDTOpen = false
end

-- ─── Real-time polling while MDT is open ────────────────────

function StartRealTimeUpdates()
    CreateThread(function()
        while isMDTOpen do
            local calls = lib.callback.await('tb-mdt:server:getActiveCalls', false)
            SendNUIMessage({ action = 'updateCalls', data = calls or {} })

            local officers = lib.callback.await('tb-mdt:server:getOnlineOfficers', false)
            SendNUIMessage({ action = 'updateOfficers', data = officers or {} })

            Wait(Config.UpdateIntervals.dispatch)
        end
    end)
end

-- ─── NUI Callbacks ──────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    CloseMDT()
    cb('ok')
end)

RegisterNUICallback('search', function(data, cb)
    local results = lib.callback.await('tb-mdt:server:search', false, data.type, data.query)
    cb(results or {})
end)

RegisterNUICallback('getProfile', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:getProfile', false, data.type, data.id)
    cb(result)
end)

RegisterNUICallback('createCall', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:createCall', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('assignCall', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:assignCall', false, data.callId, data.officerId)
    cb(result or { success = false })
end)

RegisterNUICallback('updateCallStatus', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:updateCallStatus', false, data.callId, data.status)
    cb(result or { success = false })
end)

RegisterNUICallback('createIncident', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:createIncident', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('closeIncident', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:closeIncident', false, data.incidentId)
    cb(result or { success = false })
end)

RegisterNUICallback('issueWarrant', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:issueWarrant', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('executeWarrant', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:executeWarrant', false, data.warrantId)
    cb(result or { success = false })
end)

RegisterNUICallback('createBOLO', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:createBOLO', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('deactivateBOLO', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:deactivateBOLO', false, data.boloId)
    cb(result or { success = false })
end)

RegisterNUICallback('addEvidence', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:addEvidence', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('getEvidence', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:getEvidence', false, data.incidentId)
    cb(result or {})
end)

RegisterNUICallback('updateStatus', function(data, cb)
    TriggerServerEvent('tb-mdt:server:updateStatus', data.status)
    cb('ok')
end)

RegisterNUICallback('getDashboardStats', function(_, cb)
    local result = lib.callback.await('tb-mdt:server:getDashboardStats', false)
    cb(result or {})
end)

-- ── Charges / rap sheet ──
RegisterNUICallback('processCharges', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:processCharges', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('getRapSheet', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:getRapSheet', false, data.citizenid)
    cb(result or { charges = {}, fines = {}, points = 0 })
end)

-- ── Licenses ──
RegisterNUICallback('setLicense', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:setLicense', false, data.citizenid, data.license, data.status)
    cb(result or { success = false })
end)

-- ── Profile extras (mugshot / notes / flags) ──
RegisterNUICallback('saveProfileExtras', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:saveProfileExtras', false, data.citizenid, data)
    cb(result or { success = false })
end)

-- ── Weapons registry ──
RegisterNUICallback('searchWeapons', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:searchWeapons', false, data.query or '')
    cb(result or {})
end)

RegisterNUICallback('registerWeapon', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:registerWeapon', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('updateWeaponStatus', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:updateWeaponStatus', false, data.weaponId, data.status, data.notes)
    cb(result or { success = false })
end)

-- ── Vehicle flags ──
RegisterNUICallback('setVehicleFlags', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:setVehicleFlags', false, data.plate, data.stolen, data.notes)
    cb(result or { success = false })
end)

-- ── Roster ──
RegisterNUICallback('getRoster', function(_, cb)
    local result = lib.callback.await('tb-mdt:server:getRoster', false)
    cb(result or {})
end)

RegisterNUICallback('setCallsign', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:setCallsign', false, data.citizenid, data.callsign)
    cb(result or { success = false })
end)

-- ── Announcements ──
RegisterNUICallback('getAnnouncements', function(_, cb)
    local result = lib.callback.await('tb-mdt:server:getAnnouncements', false)
    cb(result or {})
end)

RegisterNUICallback('createAnnouncement', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:createAnnouncement', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteAnnouncement', function(data, cb)
    local result = lib.callback.await('tb-mdt:server:deleteAnnouncement', false, data.id)
    cb(result or { success = false })
end)

-- ─── Framework event handlers ───────────────────────────────

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local pd = GetPlayerData()
    if pd and pd.job and IsAllowedJob() then
        TriggerServerEvent('tb-mdt:server:registerOfficer')
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    local isLaw = false
    for _, name in ipairs(Config.AllowedJobs) do
        if job.name == name then isLaw = true break end
    end

    if isLaw then
        TriggerServerEvent('tb-mdt:server:updateOfficerJob')
    else
        TriggerServerEvent('tb-mdt:server:removeOfficer')
    end
end)

-- ─── Real-time broadcast listeners ──────────────────────────

RegisterNetEvent('tb-mdt:client:newCall', function(call)
    if not isMDTOpen then
        lib.notify({ title = Locales['notification_new_call'], description = call and call.caller or '', type = 'info' })
        PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
    end
    SendNUIMessage({ action = 'newCall', data = call })
end)

RegisterNetEvent('tb-mdt:client:callAssigned', function(callId, officerName)
    local pd = GetPlayerData()
    if pd.metadata.callsign and officerName and officerName:find(pd.metadata.callsign) then
        lib.notify({ title = 'MDT', description = Locales['notification_call_assigned'], type = 'success' })
    end
    SendNUIMessage({ action = 'callAssigned', data = { callId = callId, officer = officerName } })
end)

RegisterNetEvent('tb-mdt:client:newWarrant', function(warrant)
    lib.notify({ title = Locales['notification_warrant_alert'], description = warrant and warrant.suspect_name or '', type = 'error' })
    SendNUIMessage({ action = 'newWarrant', data = warrant })
end)

RegisterNetEvent('tb-mdt:client:newBOLO', function(bolo)
    lib.notify({ title = Locales['notification_bolo_alert'], description = bolo and bolo.description and bolo.description:sub(1, 60) or '', type = 'warning' })
    SendNUIMessage({ action = 'newBOLO', data = bolo })
end)

RegisterNetEvent('tb-mdt:client:newIncident', function(data)
    lib.notify({ title = Locales['notification_incident'], description = data and data.caseNumber or '', type = 'info' })
    SendNUIMessage({ action = 'newIncident', data = data })
end)

RegisterNetEvent('tb-mdt:client:newAnnouncement', function(announcement)
    if not IsAllowedJob() then return end
    lib.notify({
        title = Locales['notification_announcement'],
        description = announcement and announcement.title or '',
        type = announcement and announcement.priority == 'urgent' and 'error' or 'info',
    })
    SendNUIMessage({ action = 'newAnnouncement', data = announcement })
end)

-- ─── Charged notification (received by the charged citizen) ──

RegisterNetEvent('tb-mdt:client:charged', function(data)
    if type(data) ~= 'table' then return end
    local desc = ('%s — Fine: $%d%s'):format(
        data.charges or '', data.fine or 0,
        (data.jail or 0) > 0 and (' · Jail: %d min'):format(data.jail) or ''
    )
    lib.notify({ title = Locales['notification_charged'], description = desc, type = 'error', duration = 10000 })
end)

-- ─── Panic button ───────────────────────────────────────────

if Config.Panic.enabled then
    local lastPanic = 0

    RegisterCommand(Config.Panic.command, function()
        if not IsAllowedJob() then return end
        local now = GetGameTimer()
        if now - lastPanic < Config.Panic.cooldown * 1000 then return end
        lastPanic = now

        TriggerServerEvent('tb-mdt:server:panic', GetEntityCoords(PlayerPedId()))
        lib.notify({ title = 'MDT', description = Locales['panic_sent'], type = 'error' })
    end, false)
    RegisterKeyMapping(Config.Panic.command, 'Officer panic button', 'keyboard', Config.Panic.key)

    RegisterNetEvent('tb-mdt:client:panic', function(data)
        if not IsAllowedJob() then return end
        if type(data) ~= 'table' or not data.coords then return end

        lib.notify({
            title = Locales['panic_alert_title'],
            description = ('%s (%s)'):format(data.officer or '?', data.callsign or '?'),
            type = 'error',
            duration = 10000,
        })
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)

        SendNUIMessage({ action = 'panicAlert', data = data })

        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, Config.Panic.blipSprite)
        SetBlipColour(blip, Config.Panic.blipColor)
        SetBlipScale(blip, Config.Panic.blipScale)
        SetBlipFlashes(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('PANIC: %s'):format(data.callsign or data.officer or 'Officer'))
        EndTextCommandSetBlipName(blip)

        SetTimeout(Config.Panic.blipDuration * 1000, function()
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end)
    end)
end

-- ─── Resource cleanup ───────────────────────────────────────

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    lib.hideTextUI()
    SetNuiFocus(false, false)
end)