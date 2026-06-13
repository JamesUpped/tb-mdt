-- ============================================================
-- server/database.lua — Query helpers for tb-mdt
-- Uses MySQL (oxmysql) .await pattern. No direct QBCore calls.
-- ============================================================

-- ─── Generators ─────────────────────────────────────────────

function GenerateCaseNumber()
    local date = os.date('%y%m%d')
    return 'CASE-' .. date .. '-' .. math.random(1000, 9999)
end

function GenerateWarrantNumber()
    local date = os.date('%y%m%d')
    return 'WARR-' .. date .. '-' .. math.random(100, 999)
end

-- ─── Citizen profile ────────────────────────────────────────

function GetCitizenProfile(citizenid)
    if type(citizenid) ~= 'string' or citizenid == '' then return nil end

    local result = MySQL.single.await('SELECT citizenid, charinfo, metadata FROM players WHERE citizenid = ?', { citizenid })
    if not result then return nil end

    local profile = { citizenid = result.citizenid }

    local ok1, charinfo = pcall(json.decode, result.charinfo)
    if ok1 and charinfo then
        profile.name        = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        profile.dob         = charinfo.birthdate
        profile.gender      = charinfo.gender
        profile.nationality = charinfo.nationality
        profile.phone       = charinfo.phone
    else
        profile.name = 'Unknown'
    end

    local ok2, metadata = pcall(json.decode, result.metadata)
    if ok2 and metadata then
        profile.licenses       = metadata.licences or {}
        profile.criminalRecord = metadata.criminal or {}
    else
        profile.licenses       = {}
        profile.criminalRecord = {}
    end

    profile.vehicles  = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { citizenid }) or {}
    profile.incidents = MySQL.query.await('SELECT * FROM mdt_incidents WHERE suspects LIKE ?', { '%' .. citizenid .. '%' }) or {}
    profile.warrants  = MySQL.query.await('SELECT * FROM mdt_warrants WHERE suspect_cid = ? AND status = ?', { citizenid, 'active' }) or {}

    -- Profile extras: mugshot, officer notes, flags
    local extras = MySQL.single.await('SELECT image, notes, flags, updated_by FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if extras then
        profile.image = extras.image
        profile.notes = extras.notes
        local ok, flags = pcall(json.decode, extras.flags or '[]')
        profile.flags = ok and flags or {}
    else
        profile.image = ''
        profile.notes = ''
        profile.flags = {}
    end

    -- Rap sheet summary
    profile.convictionCount = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_charges WHERE citizenid = ?', { citizenid }) or 0
    profile.unpaidFines     = MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM mdt_fines WHERE citizenid = ? AND status = ?', { citizenid, 'unpaid' }) or 0
    profile.licensePoints   = MySQL.scalar.await('SELECT COALESCE(SUM(points), 0) FROM mdt_charges WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)', { citizenid }) or 0

    return profile
end

-- ─── Vehicle profile ────────────────────────────────────────

function GetVehicleProfile(plate)
    if type(plate) ~= 'string' or plate == '' then return nil end

    local result = MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ?', { plate })
    if not result then return nil end

    local vehicle = {
        plate     = result.plate,
        model     = result.vehicle,
        citizenid = result.citizenid,
        state     = result.state,
    }

    local owner = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { result.citizenid })
    if owner then
        local ok, ci = pcall(json.decode, owner.charinfo)
        if ok and ci then
            vehicle.owner = (ci.firstname or '') .. ' ' .. (ci.lastname or '')
        end
    end

    vehicle.incidents = MySQL.query.await('SELECT * FROM mdt_incidents WHERE description LIKE ?', { '%' .. plate .. '%' }) or {}
    vehicle.bolos     = MySQL.query.await('SELECT * FROM mdt_bolos WHERE plate = ? AND status = ?', { plate, 'active' }) or {}

    -- Stolen flag & officer notes
    local flags = MySQL.single.await('SELECT stolen, notes, updated_by FROM mdt_vehicle_flags WHERE plate = ?', { plate })
    vehicle.stolen     = flags and flags.stolen == 1 or false
    vehicle.flagNotes  = flags and flags.notes or ''

    return vehicle
end

-- ─── Incident CRUD ──────────────────────────────────────────

function CreateIncident(data, createdBy)
    local caseNumber = GenerateCaseNumber()

    local suspects = json.encode(data.suspects or {})
    local officers = json.encode(data.officers or {})
    local charges  = json.encode(data.charges  or {})

    local insertId = MySQL.insert.await(
        'INSERT INTO mdt_incidents (case_number, title, description, location, suspects, officers, charges, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { caseNumber, data.title, data.description, data.location or '', suspects, officers, charges, createdBy }
    )

    if not insertId then return { success = false } end

    -- Attach evidence if provided inline
    if data.evidence and type(data.evidence) == 'table' then
        for _, ev in ipairs(data.evidence) do
            MySQL.insert.await(
                'INSERT INTO mdt_evidence (incident_id, type, description, officer, metadata) VALUES (?, ?, ?, ?, ?)',
                { insertId, ev.type, ev.description, createdBy, json.encode(ev.metadata or {}) }
            )
        end
    end

    -- Auto-create warrants if flagged
    if data.createWarrants and data.suspects then
        for _, suspect in ipairs(data.suspects) do
            if suspect.citizenid and suspect.name then
                MySQL.insert.await(
                    'INSERT INTO mdt_warrants (warrant_number, suspect_cid, suspect_name, charges, issuing_officer) VALUES (?, ?, ?, ?, ?)',
                    { GenerateWarrantNumber(), suspect.citizenid, suspect.name, charges, createdBy }
                )
            end
        end
    end

    return { success = true, caseNumber = caseNumber, id = insertId }
end

function CloseIncident(incidentId)
    if type(incidentId) ~= 'number' then incidentId = tonumber(incidentId) end
    if not incidentId then return { success = false } end

    local affected = MySQL.update.await(
        'UPDATE mdt_incidents SET status = ?, closed_at = NOW() WHERE id = ? AND status = ?',
        { 'closed', incidentId, 'open' }
    )
    return { success = affected and affected > 0 }
end

-- ─── Warrant helpers ────────────────────────────────────────

function ExecuteWarrant(warrantId, executedBy)
    if type(warrantId) ~= 'number' then warrantId = tonumber(warrantId) end
    if not warrantId then return { success = false } end

    local affected = MySQL.update.await(
        'UPDATE mdt_warrants SET status = ?, executed_by = ?, executed_at = NOW() WHERE id = ? AND status = ?',
        { 'executed', executedBy, warrantId, 'active' }
    )
    return { success = affected and affected > 0 }
end

-- ─── Archiving ──────────────────────────────────────────────

function ArchiveOldRecords()
    MySQL.update.await(
        'UPDATE mdt_incidents SET status = ? WHERE status = ? AND closed_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
        { 'archived', 'closed', Config.Archiving.closedIncidents }
    )
    MySQL.update.await(
        'UPDATE mdt_calls SET status = ? WHERE status = ? AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
        { 'archived', 'closed', Config.Archiving.resolvedCalls }
    )
    MySQL.update.await(
        'UPDATE mdt_warrants SET status = ? WHERE status = ? AND executed_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
        { 'archived', 'executed', Config.Archiving.executedWarrants }
    )
end

-- ─── Dashboard stats ────────────────────────────────────────

function GetDashboardStats()
    return {
        activeCalls    = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_calls WHERE status IN (?, ?)', { 'pending', 'assigned' }) or 0,
        onlineOfficers = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_officers WHERE last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE)', {}) or 0,
        openIncidents  = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_incidents WHERE status = ?', { 'open' }) or 0,
        activeWarrants = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_warrants WHERE status = ?', { 'active' }) or 0,
        activeBolos    = MySQL.scalar.await('SELECT COUNT(*) FROM mdt_bolos WHERE status = ?', { 'active' }) or 0,
    }
end

-- ─── Permission check (by source, not citizenid) ───────────

function HasPermission(src, feature, action)
    local job = TB.BridgeGetPlayerJob(src)
    if not job then return false end

    local perms = Config.Permissions[job.name]
    if not perms then return false end
    if job.grade.level < perms.minimumGrade then return false end

    local featureCfg = perms.features[feature]
    if not featureCfg then return false end

    if type(featureCfg) == 'boolean' then
        return featureCfg
    elseif type(featureCfg) == 'number' then
        return job.grade.level >= featureCfg
    elseif type(featureCfg) == 'table' then
        local req = featureCfg[action]
        if type(req) == 'boolean' then return req end
        if type(req) == 'number'  then return job.grade.level >= req end
    end

    return false
end

-- ─── Exports ────────────────────────────────────────────────

exports('GetCitizenProfile', GetCitizenProfile)
exports('GetVehicleProfile', GetVehicleProfile)
exports('CreateIncident', CreateIncident)
exports('CloseIncident', CloseIncident)
exports('ExecuteWarrant', ExecuteWarrant)
exports('HasPermission', HasPermission)
exports('GetDashboardStats', GetDashboardStats)