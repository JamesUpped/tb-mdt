-- ============================================================
-- server/records.lua — Premium record systems for tb-mdt
--   Charges & rap sheet · fines & jail · weapons registry ·
--   roster · announcements · license management · profile
--   extras (mugshot / notes / flags) · vehicle flags · panic
-- ============================================================

local panicCooldowns = {}

-- ─── Table creation ─────────────────────────────────────────
CreateThread(function()
    Wait(1500) -- after main.lua's core tables

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_charges` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `citizen_name` VARCHAR(100),
        `charge_id` VARCHAR(10),
        `charge_title` VARCHAR(100),
        `category` VARCHAR(20),
        `fine` INT DEFAULT 0,
        `jail` INT DEFAULT 0,
        `points` INT DEFAULT 0,
        `incident_id` INT NULL,
        `officer` VARCHAR(100),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_charges_citizen` (`citizenid`)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_fines` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `citizen_name` VARCHAR(100),
        `amount` INT NOT NULL,
        `charges` TEXT,
        `status` VARCHAR(10) DEFAULT 'unpaid',
        `officer` VARCHAR(100),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `paid_at` TIMESTAMP NULL,
        INDEX `idx_fines_citizen` (`citizenid`),
        INDEX `idx_fines_status` (`status`)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_weapons` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `serial` VARCHAR(50) NOT NULL UNIQUE,
        `model` VARCHAR(50),
        `owner_cid` VARCHAR(50),
        `owner_name` VARCHAR(100),
        `status` VARCHAR(15) DEFAULT 'registered',
        `notes` TEXT,
        `registered_by` VARCHAR(100),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_weapons_owner` (`owner_cid`)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_profiles` (
        `citizenid` VARCHAR(50) PRIMARY KEY,
        `image` TEXT,
        `notes` TEXT,
        `flags` TEXT,
        `updated_by` VARCHAR(100),
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_announcements` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(120) NOT NULL,
        `body` TEXT,
        `priority` VARCHAR(10) DEFAULT 'normal',
        `created_by` VARCHAR(100),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_vehicle_flags` (
        `plate` VARCHAR(20) PRIMARY KEY,
        `stolen` TINYINT(1) DEFAULT 0,
        `notes` TEXT,
        `updated_by` VARCHAR(100),
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    print('^2[tb-mdt] Record system tables initialised^0')
end)

-- ─── Local helpers ──────────────────────────────────────────

local function IsOfficer(src)
    return TB.BridgeHasJob(src, Config.AllowedJobs, 0)
end

local function OfficerName(src)
    local ci = TB.BridgeGetPlayerCharInfo(src)
    if not ci then return 'Unknown' end
    return ci.firstname .. ' ' .. ci.lastname
end

local function AuditLog(title, message, fields, color)
    if not Config.WebhookURL or Config.WebhookURL == '' then return end
    pcall(function()
        TB.SendWebhook(Config.WebhookURL, {
            title   = title,
            message = message,
            color   = color or 'blue',
            fields  = fields,
            footer  = 'tb-mdt',
        })
    end)
end

--- Find a penal code charge definition by its id.
local function FindCharge(chargeId)
    for category, list in pairs(Config.PenalCode) do
        for _, charge in ipairs(list) do
            if charge.id == chargeId then
                return charge, category
            end
        end
    end
    return nil
end

--- Set a licence flag on a player (online via framework, offline via DB).
---@return boolean success
local function SetLicenseStatus(citizenid, license, status)
    local targetSrc = TB.BridgeGetSrcByCitizenId(citizenid)

    if targetSrc then
        if Framework.name == 'qbox' then
            local player = exports.qbx_core:GetPlayer(targetSrc)
            if not player then return false end
            local licences = player.PlayerData.metadata.licences or {}
            licences[license] = status
            player.Functions.SetMetaData('licences', licences)
            return true
        else
            local QBCore = exports['qb-core']:GetCoreObject()
            local player = QBCore.Functions.GetPlayer(targetSrc)
            if not player then return false end
            local licences = player.PlayerData.metadata.licences or {}
            licences[license] = status
            player.Functions.SetMetaData('licences', licences)
            return true
        end
    end

    -- Offline: read-modify-write the metadata JSON.
    -- (JSON_SET with a bound param stores 1/0 numbers — 0 is truthy in Lua,
    --  and MariaDB lacks CAST AS JSON, so decode/encode in Lua instead.)
    local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ?', { citizenid })
    if not row or not row.metadata then return false end

    local ok, metadata = pcall(json.decode, row.metadata)
    if not ok or type(metadata) ~= 'table' then return false end

    metadata.licences = metadata.licences or {}
    metadata.licences[license] = status

    local affected = MySQL.update.await(
        'UPDATE players SET metadata = ? WHERE citizenid = ?',
        { json.encode(metadata), citizenid }
    )
    return affected and affected > 0
end

-- ════════════════════════════════════════════════════════════
--  CHARGES — process, rap sheet, license points
-- ════════════════════════════════════════════════════════════

--- Process a set of charges against a citizen.
--- data = { citizenid, name, incidentId?, charges = { { id, fine, jail }, ... } }
lib.callback.register('tb-mdt:server:processCharges', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'charges', 'process') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(data) ~= 'table' or type(data.citizenid) ~= 'string'
        or type(data.charges) ~= 'table' or #data.charges == 0 or #data.charges > 20 then
        return { success = false, error = 'Invalid charge data' }
    end

    local officerName = OfficerName(src)
    local totalFine, totalJail, totalPoints = 0, 0, 0
    local validated = {}

    -- Validate every charge against the penal code (server-authoritative clamping)
    for _, entry in ipairs(data.charges) do
        local def, category = FindCharge(entry.id)
        if not def then
            return { success = false, error = ('Unknown charge: %s'):format(tostring(entry.id)) }
        end
        local fine = math.floor(tonumber(entry.fine) or def.fineMin)
        local jail = math.floor(tonumber(entry.jail) or def.jailMin)
        fine = math.max(def.fineMin, math.min(def.fineMax, fine))
        jail = math.max(def.jailMin, math.min(def.jailMax, jail))

        totalFine   = totalFine + fine
        totalJail   = totalJail + jail
        totalPoints = totalPoints + (def.points or 0)
        validated[#validated + 1] = { def = def, category = category, fine = fine, jail = jail }
    end

    -- Record convictions on the rap sheet
    for _, v in ipairs(validated) do
        MySQL.insert.await(
            'INSERT INTO mdt_charges (citizenid, citizen_name, charge_id, charge_title, category, fine, jail, points, incident_id, officer) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { data.citizenid, data.name or '', v.def.id, v.def.title, v.category, v.fine, v.jail, v.def.points or 0, tonumber(data.incidentId), officerName }
        )
    end

    -- Collect fine: deduct from bank when possible, otherwise leave unpaid
    local targetSrc = TB.BridgeGetSrcByCitizenId(data.citizenid)
    local finePaid = false
    if totalFine > 0 and Config.Fines.method == 'bank_then_record' and targetSrc then
        finePaid = TB.BridgeRemoveMoney(targetSrc, Config.Fines.account, totalFine, 'mdt-fine') and true or false
    end

    local chargeTitles = {}
    for _, v in ipairs(validated) do chargeTitles[#chargeTitles + 1] = v.def.title end
    local chargesText = table.concat(chargeTitles, ', ')

    if totalFine > 0 then
        MySQL.insert.await(
            'INSERT INTO mdt_fines (citizenid, citizen_name, amount, charges, status, officer, paid_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { data.citizenid, data.name or '', totalFine, chargesText, finePaid and 'paid' or 'unpaid', officerName, finePaid and os.date('%Y-%m-%d %H:%M:%S') or nil }
        )
    end

    -- License points → auto-revoke
    local licenseRevoked = false
    if Config.LicensePoints.enabled and totalPoints > 0 then
        local accumulated = MySQL.scalar.await(
            'SELECT COALESCE(SUM(points), 0) FROM mdt_charges WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)',
            { data.citizenid }
        ) or 0
        if accumulated >= Config.LicensePoints.limit then
            licenseRevoked = SetLicenseStatus(data.citizenid, Config.LicensePoints.license, false)
        end
    end

    -- Jail sentence
    local jailed = false
    if totalJail > 0 and Config.Jail.enabled and Config.Jail.mode ~= 'none' and targetSrc then
        if Config.Jail.mode == 'export' and type(Config.Jail.export) == 'function' then
            pcall(Config.Jail.export, targetSrc, totalJail, chargesText)
            jailed = true
        elseif Config.Jail.event then
            TriggerEvent(Config.Jail.event, targetSrc, totalJail)
            jailed = true
        end
    end

    if targetSrc then
        TriggerClientEvent('tb-mdt:client:charged', targetSrc, {
            charges = chargesText,
            fine    = totalFine,
            jail    = totalJail,
            paid    = finePaid,
        })
    end

    AuditLog('Charges Processed', ('%s charged by %s'):format(data.name or data.citizenid, officerName), {
        { name = 'Charges', value = chargesText:sub(1, 1000), inline = false },
        { name = 'Fine',    value = ('$%d (%s)'):format(totalFine, finePaid and 'paid' or 'unpaid'), inline = true },
        { name = 'Jail',    value = ('%d min'):format(totalJail), inline = true },
    }, 'red')

    return {
        success        = true,
        totalFine      = totalFine,
        totalJail      = totalJail,
        finePaid       = finePaid,
        jailed         = jailed,
        licenseRevoked = licenseRevoked,
    }
end)

--- Rap sheet (convictions + fines) for a citizen.
lib.callback.register('tb-mdt:server:getRapSheet', function(src, citizenid)
    if not IsOfficer(src) then return nil end
    if type(citizenid) ~= 'string' or citizenid == '' then return nil end

    return {
        charges = MySQL.query.await('SELECT * FROM mdt_charges WHERE citizenid = ? ORDER BY created_at DESC LIMIT 100', { citizenid }) or {},
        fines   = MySQL.query.await('SELECT * FROM mdt_fines WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50', { citizenid }) or {},
        points  = MySQL.scalar.await('SELECT COALESCE(SUM(points), 0) FROM mdt_charges WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)', { citizenid }) or 0,
    }
end)

-- ════════════════════════════════════════════════════════════
--  LICENSES — grant / revoke
-- ════════════════════════════════════════════════════════════

lib.callback.register('tb-mdt:server:setLicense', function(src, citizenid, license, status)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'licenses', 'manage') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(citizenid) ~= 'string' or type(license) ~= 'string' or #license > 30
        or not license:match('^[%w_]+$') then
        return { success = false, error = 'Invalid license' }
    end

    local ok = SetLicenseStatus(citizenid, license, status == true)
    if ok then
        AuditLog('License ' .. (status and 'Granted' or 'Revoked'),
            ('%s — %s by %s'):format(citizenid, license, OfficerName(src)), nil, 'orange')
    end
    return { success = ok }
end)

-- ════════════════════════════════════════════════════════════
--  PROFILE EXTRAS — mugshot, notes, flags
-- ════════════════════════════════════════════════════════════

local ALLOWED_FLAGS = { violent = true, armed = true, gang = true, flight_risk = true, informant = true, mental_health = true }

lib.callback.register('tb-mdt:server:saveProfileExtras', function(src, citizenid, data)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'profiles', 'edit') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(citizenid) ~= 'string' or citizenid == '' or type(data) ~= 'table' then
        return { success = false, error = 'Invalid data' }
    end

    local image = type(data.image) == 'string' and data.image:sub(1, 500) or ''
    if image ~= '' and not (image:match('^https?://') ) then
        return { success = false, error = 'Image must be a http(s) URL' }
    end
    local notes = type(data.notes) == 'string' and data.notes:sub(1, 2000) or ''

    local flags = {}
    if type(data.flags) == 'table' then
        for _, flag in ipairs(data.flags) do
            if type(flag) == 'string' and ALLOWED_FLAGS[flag] then
                flags[#flags + 1] = flag
            end
        end
    end

    MySQL.query.await(
        'INSERT INTO mdt_profiles (citizenid, image, notes, flags, updated_by) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE image = VALUES(image), notes = VALUES(notes), flags = VALUES(flags), updated_by = VALUES(updated_by)',
        { citizenid, image, notes, json.encode(flags), OfficerName(src) }
    )
    return { success = true }
end)

-- ════════════════════════════════════════════════════════════
--  WEAPONS REGISTRY
-- ════════════════════════════════════════════════════════════

local WEAPON_STATUSES = { registered = true, stolen = true, seized = true, destroyed = true }

lib.callback.register('tb-mdt:server:searchWeapons', function(src, query)
    if not IsOfficer(src) then return {} end
    if type(query) ~= 'string' then return {} end
    query = query:sub(1, 50)

    if query == '' then
        return MySQL.query.await('SELECT * FROM mdt_weapons ORDER BY updated_at DESC LIMIT 50', {}) or {}
    end
    return MySQL.query.await(
        'SELECT * FROM mdt_weapons WHERE serial LIKE ? OR owner_name LIKE ? OR model LIKE ? OR owner_cid = ? ORDER BY updated_at DESC LIMIT 50',
        { '%' .. query .. '%', '%' .. query .. '%', '%' .. query .. '%', query }
    ) or {}
end)

lib.callback.register('tb-mdt:server:registerWeapon', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'weapons', 'register') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(data) ~= 'table' or type(data.serial) ~= 'string' or data.serial == ''
        or type(data.model) ~= 'string' or data.model == '' then
        return { success = false, error = 'Serial and model are required' }
    end

    local insertId = MySQL.insert.await(
        'INSERT IGNORE INTO mdt_weapons (serial, model, owner_cid, owner_name, notes, registered_by) VALUES (?, ?, ?, ?, ?, ?)',
        {
            data.serial:sub(1, 50), data.model:sub(1, 50),
            type(data.ownerCid) == 'string' and data.ownerCid:sub(1, 50) or '',
            type(data.ownerName) == 'string' and data.ownerName:sub(1, 100) or '',
            type(data.notes) == 'string' and data.notes:sub(1, 1000) or '',
            OfficerName(src),
        }
    )
    if not insertId or insertId == 0 then
        return { success = false, error = 'Serial already registered' }
    end

    local weapon = MySQL.single.await('SELECT * FROM mdt_weapons WHERE id = ?', { insertId })
    AuditLog('Weapon Registered', ('%s (%s) by %s'):format(data.serial, data.model, OfficerName(src)), nil, 'blue')
    return { success = true, weapon = weapon }
end)

lib.callback.register('tb-mdt:server:updateWeaponStatus', function(src, weaponId, status, notes)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'weapons', 'flag') then
        return { success = false, error = 'Insufficient rank' }
    end
    weaponId = tonumber(weaponId)
    if not weaponId or type(status) ~= 'string' or not WEAPON_STATUSES[status] then
        return { success = false, error = 'Invalid status' }
    end

    local affected = MySQL.update.await(
        'UPDATE mdt_weapons SET status = ?, notes = COALESCE(?, notes) WHERE id = ?',
        { status, type(notes) == 'string' and notes:sub(1, 1000) or nil, weaponId }
    )
    return { success = affected and affected > 0 }
end)

-- ════════════════════════════════════════════════════════════
--  VEHICLE FLAGS — stolen markers & notes
-- ════════════════════════════════════════════════════════════

lib.callback.register('tb-mdt:server:setVehicleFlags', function(src, plate, stolen, notes)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'vehicles', 'flag') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(plate) ~= 'string' or plate == '' or #plate > 20 then
        return { success = false, error = 'Invalid plate' }
    end

    MySQL.query.await(
        'INSERT INTO mdt_vehicle_flags (plate, stolen, notes, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE stolen = VALUES(stolen), notes = VALUES(notes), updated_by = VALUES(updated_by)',
        { plate, stolen and 1 or 0, type(notes) == 'string' and notes:sub(1, 1000) or '', OfficerName(src) }
    )

    if stolen then
        AuditLog('Vehicle Flagged Stolen', ('%s by %s'):format(plate, OfficerName(src)), nil, 'red')
    end
    return { success = true }
end)

-- ════════════════════════════════════════════════════════════
--  ROSTER — full department roster & callsign management
-- ════════════════════════════════════════════════════════════

lib.callback.register('tb-mdt:server:getRoster', function(src)
    if not IsOfficer(src) then return {} end
    return MySQL.query.await('SELECT * FROM mdt_officers ORDER BY department, rank DESC, name', {}) or {}
end)

lib.callback.register('tb-mdt:server:setCallsign', function(src, citizenid, callsign)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'roster', 'manage') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(citizenid) ~= 'string' or type(callsign) ~= 'string'
        or callsign == '' or #callsign > 10 or not callsign:match('^[%w%-]+$') then
        return { success = false, error = 'Invalid callsign' }
    end

    local affected = MySQL.update.await('UPDATE mdt_officers SET callsign = ? WHERE citizenid = ?', { callsign, citizenid })
    if not affected or affected == 0 then return { success = false, error = 'Officer not found' } end

    -- Push to live player metadata so other resources pick it up
    local targetSrc = TB.BridgeGetSrcByCitizenId(citizenid)
    if targetSrc then
        if Framework.name == 'qbox' then
            local player = exports.qbx_core:GetPlayer(targetSrc)
            if player then player.Functions.SetMetaData('callsign', callsign) end
        else
            local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(targetSrc)
            if player then player.Functions.SetMetaData('callsign', callsign) end
        end
    end
    return { success = true }
end)

-- ════════════════════════════════════════════════════════════
--  ANNOUNCEMENTS — department bulletins
-- ════════════════════════════════════════════════════════════

lib.callback.register('tb-mdt:server:getAnnouncements', function(src)
    if not IsOfficer(src) then return {} end
    return MySQL.query.await('SELECT * FROM mdt_announcements ORDER BY created_at DESC LIMIT 20', {}) or {}
end)

lib.callback.register('tb-mdt:server:createAnnouncement', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'announcements', 'create') then
        return { success = false, error = 'Insufficient rank' }
    end
    if type(data) ~= 'table' or type(data.title) ~= 'string' or data.title == '' then
        return { success = false, error = 'Title is required' }
    end

    local priority = data.priority
    if priority ~= 'normal' and priority ~= 'important' and priority ~= 'urgent' then priority = 'normal' end

    local insertId = MySQL.insert.await(
        'INSERT INTO mdt_announcements (title, body, priority, created_by) VALUES (?, ?, ?, ?)',
        { data.title:sub(1, 120), type(data.body) == 'string' and data.body:sub(1, 2000) or '', priority, OfficerName(src) }
    )
    if not insertId then return { success = false } end

    local announcement = MySQL.single.await('SELECT * FROM mdt_announcements WHERE id = ?', { insertId })
    TriggerClientEvent('tb-mdt:client:newAnnouncement', -1, announcement)
    return { success = true, announcement = announcement }
end)

lib.callback.register('tb-mdt:server:deleteAnnouncement', function(src, id)
    if not IsOfficer(src) then return { success = false } end
    if not HasPermission(src, 'announcements', 'remove') then
        return { success = false, error = 'Insufficient rank' }
    end
    local affected = MySQL.update.await('DELETE FROM mdt_announcements WHERE id = ?', { tonumber(id) })
    return { success = affected and affected > 0 }
end)

-- ════════════════════════════════════════════════════════════
--  PANIC BUTTON
-- ════════════════════════════════════════════════════════════

RegisterNetEvent('tb-mdt:server:panic', function(coords)
    local src = source
    if not Config.Panic.enabled then return end
    if not IsOfficer(src) then return end

    local now = os.time()
    if panicCooldowns[src] and now - panicCooldowns[src] < Config.Panic.cooldown then return end
    panicCooldowns[src] = now

    -- Server-side position (never trust the client blindly; clamp to actual ped position)
    local ped = GetPlayerPed(src)
    local actual = ped and GetEntityCoords(ped)
    local x, y, z
    if actual and actual.x then
        x, y, z = actual.x, actual.y, actual.z
    elseif type(coords) == 'table' or type(coords) == 'vector3' then
        x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    end
    if not x then return end

    local ci = TB.BridgeGetPlayerCharInfo(src)
    local callsign = TB.BridgeGetPlayerMetadata(src, 'callsign') or '???'
    local name = ci and (ci.firstname .. ' ' .. ci.lastname) or 'Unknown Officer'

    TriggerClientEvent('tb-mdt:client:panic', -1, {
        officer  = name,
        callsign = callsign,
        coords   = { x = x, y = y, z = z },
    })

    AuditLog('PANIC BUTTON', ('%s (%s) pressed panic'):format(name, callsign), {
        { name = 'Position', value = ('%.1f, %.1f, %.1f'):format(x, y, z), inline = true },
    }, 'red')
end)

AddEventHandler('playerDropped', function()
    panicCooldowns[source] = nil
end)

-- ─── Exports ────────────────────────────────────────────────
exports('SetLicenseStatus', SetLicenseStatus)
