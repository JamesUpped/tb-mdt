local cooldowns = {}

-- ─── Database table creation ────────────────────────────────
CreateThread(function()
    Wait(1000)

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_calls` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `caller` VARCHAR(50),
        `location` TEXT,
        `description` TEXT,
        `priority` INT DEFAULT 1,
        `status` VARCHAR(20) DEFAULT 'pending',
        `assigned` VARCHAR(50),
        `created_by` VARCHAR(50),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_incidents` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `case_number` VARCHAR(20) UNIQUE,
        `title` VARCHAR(100),
        `description` TEXT,
        `location` TEXT,
        `suspects` TEXT,
        `officers` TEXT,
        `charges` TEXT,
        `status` VARCHAR(20) DEFAULT 'open',
        `created_by` VARCHAR(50),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `closed_at` TIMESTAMP NULL
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_warrants` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `warrant_number` VARCHAR(20) UNIQUE,
        `suspect_cid` VARCHAR(50),
        `suspect_name` VARCHAR(100),
        `charges` TEXT,
        `issuing_officer` VARCHAR(50),
        `issued_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `status` VARCHAR(20) DEFAULT 'active',
        `executed_by` VARCHAR(50) NULL,
        `executed_at` TIMESTAMP NULL
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_bolos` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `type` VARCHAR(20),
        `description` TEXT,
        `plate` VARCHAR(10) NULL,
        `model` VARCHAR(50) NULL,
        `suspect` VARCHAR(100) NULL,
        `location` TEXT,
        `created_by` VARCHAR(50),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `status` VARCHAR(20) DEFAULT 'active'
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_evidence` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `incident_id` INT,
        `type` VARCHAR(20),
        `description` TEXT,
        `officer` VARCHAR(50),
        `added_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `metadata` TEXT
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_officers` (
        `citizenid` VARCHAR(50) PRIMARY KEY,
        `name` VARCHAR(100),
        `callsign` VARCHAR(10),
        `department` VARCHAR(20),
        `rank` INT,
        `status` VARCHAR(20) DEFAULT 'available',
        `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    print('^2[tb-mdt] Database tables initialised^0')
end)

-- ─── Helpers ────────────────────────────────────────────────

--- Rate-limit guard.
---@return boolean  true if allowed
local function CheckRateLimit(src, action)
    local key = src .. ':' .. action
    local limit = Config.RateLimits[action] or { count = 5, time = 30 }

    if not cooldowns[key] then
        cooldowns[key] = { count = 0, time = os.time() }
    end

    if os.time() - cooldowns[key].time > limit.time then
        cooldowns[key] = { count = 0, time = os.time() }
    end

    cooldowns[key].count = cooldowns[key].count + 1
    return cooldowns[key].count <= limit.count
end

--- Validate that source is an allowed-job officer.
---@return boolean
local function IsOfficer(src)
    return TB.BridgeHasJob(src, Config.AllowedJobs, 0)
end

--- Get the officer's full display name from charinfo.
local function OfficerName(src)
    local ci = TB.BridgeGetPlayerCharInfo(src)
    if not ci then return 'Unknown' end
    return ci.firstname .. ' ' .. ci.lastname
end

--- Send a webhook audit log if configured.
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

-- Clean up cooldowns on player drop
AddEventHandler('playerDropped', function()
    local src = source
    for key in pairs(cooldowns) do
        if key:find(tostring(src) .. ':') then
            cooldowns[key] = nil
        end
    end
end)

-- ─── Callbacks (ox_lib) ─────────────────────────────────────

--- Initial data payload when the MDT opens.
lib.callback.register('tb-mdt:server:getInitialData', function(src)
    if not IsOfficer(src) then return nil end
    local job = TB.BridgeGetPlayerJob(src)
    if not job or not job.onduty then return nil end

    local calls     = MySQL.query.await('SELECT * FROM mdt_calls WHERE status != ? ORDER BY priority DESC, created_at DESC LIMIT 20', { 'closed' })
    local officers  = MySQL.query.await('SELECT * FROM mdt_officers WHERE last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE) ORDER BY department, name', {})
    local incidents = MySQL.query.await('SELECT * FROM mdt_incidents WHERE status = ? ORDER BY created_at DESC LIMIT 10', { 'open' })
    local warrants  = MySQL.query.await('SELECT * FROM mdt_warrants WHERE status = ? ORDER BY issued_at DESC LIMIT 10', { 'active' })
    local bolos     = MySQL.query.await('SELECT * FROM mdt_bolos WHERE status = ? ORDER BY created_at DESC LIMIT 10', { 'active' })

    local warrantAlertCount = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_warrants WHERE status = ? AND issued_at > DATE_SUB(NOW(), INTERVAL 1 DAY)', { 'active' }) or 0
    local callAlertCount    = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_calls WHERE status = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)', { 'pending' }) or 0

    return {
        calls     = calls or {},
        officers  = officers or {},
        incidents = incidents or {},
        warrants  = warrants or {},
        bolos     = bolos or {},
        alerts    = { warrants = warrantAlertCount, calls = callAlertCount },
        penalCode = Config.PenalCode,
    }
end)

--- Active calls polling.
lib.callback.register('tb-mdt:server:getActiveCalls', function(src)
    if not IsOfficer(src) then return {} end
    return MySQL.query.await('SELECT * FROM mdt_calls WHERE status != ? ORDER BY priority DESC, created_at DESC LIMIT 30', { 'closed' }) or {}
end)

--- Online officers polling.
lib.callback.register('tb-mdt:server:getOnlineOfficers', function(src)
    if not IsOfficer(src) then return {} end
    return MySQL.query.await('SELECT * FROM mdt_officers WHERE last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE) ORDER BY department, name', {}) or {}
end)

--- Dashboard stats.
lib.callback.register('tb-mdt:server:getDashboardStats', function(src)
    if not IsOfficer(src) then return {} end
    return GetDashboardStats()
end)

--- Search (citizen or vehicle).
lib.callback.register('tb-mdt:server:search', function(src, searchType, query)
    if not IsOfficer(src) then return {} end
    if not CheckRateLimit(src, 'search') then return { error = 'Rate limit exceeded' } end

    if type(query) ~= 'string' or #query < Config.Search.minCharacters then return {} end

    if searchType == 'citizen' then
        local results = MySQL.query.await(
            'SELECT citizenid, charinfo, metadata FROM players WHERE charinfo LIKE ? LIMIT ?',
            { '%' .. query .. '%', Config.Search.maxResults }
        ) or {}
        local formatted = {}
        for _, row in ipairs(results) do
            local ok1, charinfo = pcall(json.decode, row.charinfo)
            local ok2, metadata = pcall(json.decode, row.metadata)
            if ok1 and charinfo then
                formatted[#formatted + 1] = {
                    citizenid = row.citizenid,
                    name      = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),
                    dob       = charinfo.birthdate,
                    phone     = charinfo.phone,
                    licenses  = ok2 and metadata and metadata.licences or {},
                }
            end
        end
        return formatted
    elseif searchType == 'vehicle' then
        return MySQL.query.await(
            'SELECT * FROM player_vehicles WHERE plate LIKE ? OR citizenid = ? LIMIT ?',
            { '%' .. query .. '%', query, Config.Search.maxResults }
        ) or {}
    end

    return {}
end)

--- Get full profile (citizen or vehicle).
lib.callback.register('tb-mdt:server:getProfile', function(src, profileType, id)
    if not IsOfficer(src) then return nil end

    if profileType == 'citizen' then
        return GetCitizenProfile(id)
    elseif profileType == 'vehicle' then
        return GetVehicleProfile(id)
    end

    return nil
end)

--- Create dispatch call.
lib.callback.register('tb-mdt:server:createCall', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not CheckRateLimit(src, 'create') then return { success = false, error = 'Rate limit' } end

    if type(data) ~= 'table' or not data.caller or not data.location or not data.description then
        return { success = false, error = 'Missing required fields' }
    end

    local priority = tonumber(data.priority)
    if not priority or priority < 1 or priority > 5 then priority = 1 end

    local officerName = OfficerName(src)

    local insertId = MySQL.insert.await(
        'INSERT INTO mdt_calls (caller, location, description, priority, created_by) VALUES (?, ?, ?, ?, ?)',
        { data.caller, data.location, data.description, priority, officerName }
    )

    if insertId then
        local call = MySQL.single.await('SELECT * FROM mdt_calls WHERE id = ?', { insertId })
        TriggerClientEvent('tb-mdt:client:newCall', -1, call)
        return { success = true, call = call }
    end

    return { success = false }
end)

--- Assign an officer to a call.
lib.callback.register('tb-mdt:server:assignCall', function(src, callId, officerId)
    if not IsOfficer(src) then return { success = false } end

    local job = TB.BridgeGetPlayerJob(src)
    local perms = Config.Permissions[job and job.name]
    local requiredGrade = perms and perms.features and perms.features.dispatch and perms.features.dispatch.assign
    if type(requiredGrade) == 'number' and (job.grade.level < requiredGrade) then
        return { success = false, error = 'Insufficient rank' }
    end

    local officer = MySQL.single.await('SELECT * FROM mdt_officers WHERE citizenid = ?', { officerId })
    if not officer then return { success = false, error = 'Officer not found' } end

    local affected = MySQL.update.await(
        'UPDATE mdt_calls SET assigned = ?, status = ? WHERE id = ?',
        { officer.name, 'assigned', callId }
    )

    if affected > 0 then
        local targetSrc = TB.BridgeGetSrcByCitizenId(officerId)
        if targetSrc then
            TriggerClientEvent('tb-mdt:client:callAssigned', targetSrc, callId, officer.name)
        end
        TriggerClientEvent('tb-mdt:client:callAssigned', -1, callId, officer.name)
        return { success = true }
    end

    return { success = false }
end)

--- Create incident report.
lib.callback.register('tb-mdt:server:createIncident', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not CheckRateLimit(src, 'create') then return { success = false, error = 'Rate limit' } end

    local job = TB.BridgeGetPlayerJob(src)
    local perms = Config.Permissions[job and job.name]
    local requiredGrade = perms and perms.features and perms.features.incidents and perms.features.incidents.create
    if type(requiredGrade) == 'number' and (job.grade.level < requiredGrade) then
        return { success = false, error = 'Insufficient rank' }
    end

    if type(data) ~= 'table' or not data.title or not data.description then
        return { success = false, error = 'Missing required fields' }
    end

    local officerName = OfficerName(src)
    local result = CreateIncident(data, officerName)

    if result.success then
        TriggerClientEvent('tb-mdt:client:newIncident', -1, {
            caseNumber = result.caseNumber,
            title      = data.title,
            createdBy  = officerName,
        })
        AuditLog('Incident Created', ('Case %s by %s'):format(result.caseNumber, officerName), {
            { name = 'Title',    value = data.title, inline = true },
            { name = 'Location', value = data.location or 'N/A', inline = true },
        }, 'blue')
    end

    return result
end)

--- Close an incident.
lib.callback.register('tb-mdt:server:closeIncident', function(src, incidentId)
    if not IsOfficer(src) then return { success = false } end

    local job = TB.BridgeGetPlayerJob(src)
    local perms = Config.Permissions[job and job.name]
    local requiredGrade = perms and perms.features and perms.features.incidents and perms.features.incidents.close
    if type(requiredGrade) == 'number' and (job.grade.level < requiredGrade) then
        return { success = false, error = 'Insufficient rank' }
    end

    return CloseIncident(incidentId)
end)

--- Issue a warrant.
lib.callback.register('tb-mdt:server:issueWarrant', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not CheckRateLimit(src, 'create') then return { success = false, error = 'Rate limit' } end

    local job = TB.BridgeGetPlayerJob(src)
    local perms = Config.Permissions[job and job.name]
    local requiredGrade = perms and perms.features and perms.features.warrants and perms.features.warrants.create
    if type(requiredGrade) == 'number' and (job.grade.level < requiredGrade) then
        return { success = false, error = 'Insufficient rank' }
    end

    if type(data) ~= 'table' or not data.suspectCid or not data.suspectName or not data.charges then
        return { success = false, error = 'Missing required fields' }
    end

    local officerName = OfficerName(src)
    local warrantNumber = GenerateWarrantNumber()

    local insertId = MySQL.insert.await(
        'INSERT INTO mdt_warrants (warrant_number, suspect_cid, suspect_name, charges, issuing_officer) VALUES (?, ?, ?, ?, ?)',
        { warrantNumber, data.suspectCid, data.suspectName, json.encode(data.charges), officerName }
    )

    if insertId then
        local warrant = MySQL.single.await('SELECT * FROM mdt_warrants WHERE id = ?', { insertId })
        TriggerClientEvent('tb-mdt:client:newWarrant', -1, warrant)
        AuditLog('Warrant Issued', ('%s — %s'):format(warrantNumber, data.suspectName), {
            { name = 'Officer', value = officerName, inline = true },
        }, 'red')
        return { success = true, warrant = warrant }
    end

    return { success = false }
end)

--- Execute a warrant.
lib.callback.register('tb-mdt:server:executeWarrant', function(src, warrantId)
    if not IsOfficer(src) then return { success = false } end

    local job = TB.BridgeGetPlayerJob(src)
    local perms = Config.Permissions[job and job.name]
    local requiredGrade = perms and perms.features and perms.features.warrants and perms.features.warrants.execute
    if type(requiredGrade) == 'number' and (job.grade.level < requiredGrade) then
        return { success = false, error = 'Insufficient rank' }
    end

    local officerName = OfficerName(src)
    return ExecuteWarrant(warrantId, officerName)
end)

--- Create BOLO.
lib.callback.register('tb-mdt:server:createBOLO', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not CheckRateLimit(src, 'create') then return { success = false, error = 'Rate limit' } end

    local job = TB.BridgeGetPlayerJob(src)
    local perms = Config.Permissions[job and job.name]
    local requiredGrade = perms and perms.features and perms.features.bolos and perms.features.bolos.create
    if type(requiredGrade) == 'number' and (job.grade.level < requiredGrade) then
        return { success = false, error = 'Insufficient rank' }
    end

    if type(data) ~= 'table' or not data.type or not data.description then
        return { success = false, error = 'Missing required fields' }
    end

    local officerName = OfficerName(src)

    local insertId = MySQL.insert.await(
        'INSERT INTO mdt_bolos (type, description, plate, model, suspect, location, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { data.type, data.description, data.plate or '', data.model or '', data.suspect or '', data.location or '', officerName }
    )

    if insertId then
        local bolo = MySQL.single.await('SELECT * FROM mdt_bolos WHERE id = ?', { insertId })
        TriggerClientEvent('tb-mdt:client:newBOLO', -1, bolo)
        return { success = true, bolo = bolo }
    end

    return { success = false }
end)

--- Deactivate BOLO.
lib.callback.register('tb-mdt:server:deactivateBOLO', function(src, boloId)
    if not IsOfficer(src) then return { success = false } end

    local affected = MySQL.update.await('UPDATE mdt_bolos SET status = ? WHERE id = ? AND status = ?', { 'inactive', boloId, 'active' })
    return { success = affected > 0 }
end)

--- Add evidence to an incident.
lib.callback.register('tb-mdt:server:addEvidence', function(src, data)
    if not IsOfficer(src) then return { success = false } end
    if not CheckRateLimit(src, 'create') then return { success = false, error = 'Rate limit' } end

    if type(data) ~= 'table' or not data.incidentId or not data.type or not data.description then
        return { success = false, error = 'Missing required fields' }
    end

    local officerName = OfficerName(src)

    local insertId = MySQL.insert.await(
        'INSERT INTO mdt_evidence (incident_id, type, description, officer, metadata) VALUES (?, ?, ?, ?, ?)',
        { data.incidentId, data.type, data.description, officerName, json.encode(data.metadata or {}) }
    )

    return { success = insertId ~= nil }
end)

--- Get evidence for a specific incident.
lib.callback.register('tb-mdt:server:getEvidence', function(src, incidentId)
    if not IsOfficer(src) then return {} end
    return MySQL.query.await('SELECT * FROM mdt_evidence WHERE incident_id = ? ORDER BY added_at DESC', { incidentId }) or {}
end)

--- Update call status (respond / close).
lib.callback.register('tb-mdt:server:updateCallStatus', function(src, callId, status)
    if not IsOfficer(src) then return { success = false } end
    if not status or (status ~= 'assigned' and status ~= 'responding' and status ~= 'closed') then
        return { success = false, error = 'Invalid status' }
    end
    local affected = MySQL.update.await('UPDATE mdt_calls SET status = ? WHERE id = ?', { status, callId })
    return { success = affected > 0 }
end)

-- ─── Officer registration events ────────────────────────────

RegisterNetEvent('tb-mdt:server:registerOfficer', function()
    local src = source
    if not IsOfficer(src) then return end

    local ci = TB.BridgeGetPlayerCharInfo(src)
    local job = TB.BridgeGetPlayerJob(src)
    if not ci or not job then return end

    local name     = ci.firstname .. ' ' .. ci.lastname
    local callsign = TB.BridgeGetPlayerMetadata(src, 'callsign') or ('NO-' .. math.random(100, 999))

    MySQL.insert.await(
        'INSERT INTO mdt_officers (citizenid, name, callsign, department, rank) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), callsign = VALUES(callsign), department = VALUES(department), rank = VALUES(rank), last_seen = CURRENT_TIMESTAMP',
        { ci.citizenid, name, callsign, job.name, job.grade.level }
    )
end)

RegisterNetEvent('tb-mdt:server:updateOfficerJob', function()
    local src = source
    if not IsOfficer(src) then return end

    local ci  = TB.BridgeGetPlayerCharInfo(src)
    local job = TB.BridgeGetPlayerJob(src)
    if not ci or not job then return end

    MySQL.update.await('UPDATE mdt_officers SET department = ?, rank = ? WHERE citizenid = ?', { job.name, job.grade.level, ci.citizenid })
end)

RegisterNetEvent('tb-mdt:server:removeOfficer', function()
    local src = source
    local cid = TB.BridgeGetCitizenId(src)
    if not cid then return end

    MySQL.query.await('DELETE FROM mdt_officers WHERE citizenid = ?', { cid })
end)

RegisterNetEvent('tb-mdt:server:updateStatus', function(status)
    local src = source
    if not IsOfficer(src) then return end
    if type(status) ~= 'string' then return end

    local cid = TB.BridgeGetCitizenId(src)
    if not cid then return end

    MySQL.update.await('UPDATE mdt_officers SET status = ? WHERE citizenid = ?', { status, cid })
end)

-- ─── Archiving cron ─────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(60 * 60 * 1000) -- every hour
        pcall(ArchiveOldRecords)
    end
end)

-- ─── Resource cleanup ───────────────────────────────────────
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('^2[tb-mdt] Cleaning up...^0')
end)