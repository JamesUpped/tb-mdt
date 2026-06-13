Config = {}

-----------------------------------------------------------
-- Allowed Jobs (any job listed can open the MDT)
-----------------------------------------------------------
Config.AllowedJobs = { 'police', 'bcso' }

-----------------------------------------------------------
-- Physical MDT Terminal Locations
-----------------------------------------------------------
Config.MDTStations = {
    vec3(441.2, -982.0, 30.7),   -- Mission Row PD
    vec3(1853.9, 3686.8, 34.3),  -- Sandy Shores Sheriff
    vec3(-448.5, 6013.6, 31.7),  -- Paleto Bay Sheriff
}
Config.UsePhysicalTerminals = true
Config.TerminalInteractDist = 2.0  -- metres to interact
Config.TerminalScanDist     = 50.0 -- metres before fast-loop activates

-----------------------------------------------------------
-- Permissions based on job grades
-----------------------------------------------------------
Config.Permissions = {
    ['police'] = {
        minimumGrade = 0, -- All police can access
        features = {
            dashboard = true,
            dispatch = { view = true, create = true, assign = 2 }, -- grade 2+ can assign
            citizens = { view = true, edit = 3, delete = 4 },
            vehicles = { view = true, flag = 1 },
            incidents = { view = true, create = 2, close = 3 },
            warrants = { view = true, create = 3, execute = 4 },
            bolos = { view = true, create = 2, remove = 3 },
            evidence = { view = true, add = 2, manage = 3 },
            charges = { view = true, process = 1 },         -- process = charge & fine/jail citizens
            weapons = { view = true, register = 1, flag = 2 },
            roster = { view = true, manage = 3 },           -- manage = edit callsigns
            announcements = { view = true, create = 3, remove = 4 },
            licenses = { view = true, manage = 2 },         -- manage = grant/revoke licenses
            profiles = { view = true, edit = 1 },           -- edit = mugshot, notes, flags
            admin = 4 -- grade 4+ for admin features
        }
    },
    ['bcso'] = {
        minimumGrade = 0,
        features = {
            dashboard = true,
            dispatch = { view = true, create = true, assign = 2 },
            citizens = { view = true, edit = 3 },
            vehicles = { view = true, flag = 1 },
            incidents = { view = true, create = 2, close = 3 },
            warrants = { view = true, create = 3 },
            bolos = { view = true, create = 2 },
            evidence = { view = true, add = 2 },
            charges = { view = true, process = 1 },
            weapons = { view = true, register = 1, flag = 2 },
            roster = { view = true, manage = 3 },
            announcements = { view = true, create = 3, remove = 4 },
            licenses = { view = true, manage = 2 },
            profiles = { view = true, edit = 1 },
            admin = 4
        }
    }
}

-- UI Configuration
Config.UI = {
    PrimaryColor = '#3B82F6',
    BackgroundColor = '#0f172a',
    CardColor = '#1e293b',
    TextColor = '#e2e8f0',
    FontFamily = 'Inter',
    BorderRadius = '12px',
    AnimationSpeed = 300
}

-- Dispatch Priority Settings
Config.DispatchPriority = {
    [1] = { color = '#10B981', label = 'Low', responseTime = 1800 },
    [2] = { color = '#3B82F6', label = 'Medium', responseTime = 1200 },
    [3] = { color = '#F59E0B', label = 'High', responseTime = 600 },
    [4] = { color = '#EF4444', label = 'Critical', responseTime = 300 },
    [5] = { color = '#DC2626', label = 'Emergency', responseTime = 120 }
}

-- Database Table Names
Config.DatabaseTables = {
    calls = 'mdt_calls',
    incidents = 'mdt_incidents',
    warrants = 'mdt_warrants',
    bolos = 'mdt_bolos',
    evidence = 'mdt_evidence',
    officers = 'mdt_officers',
    penalties = 'mdt_penalties'
}

-- Keybinds
Config.Keybinds = {
    OpenMDT = { key = 'F5', command = 'openmdt', description = 'Open Police MDT' },
    QuickDispatch = { key = 'F6', command = 'quickdispatch', description = 'Quick Dispatch Menu' }
}

-- Real-time Update Intervals (ms)
Config.UpdateIntervals = {
    dispatch = 5000,
    officers = 10000,
    calls = 3000
}

-- Search Settings
Config.Search = {
    minCharacters = 2,
    maxResults = 50,
    timeout = 5000
}

-- Notification Settings
Config.Notifications = {
    sound = true,
    position = 'top-right',
    duration = 5000
}

-- Department Settings
Config.Departments = {
    police = { name = 'Los Santos Police Department', short = 'LSPD', theme = 'blue' },
    bcso = { name = 'Blaine County Sheriff Office', short = 'BCSO', theme = 'green' }
}

-- Offense Categories (from reference image)
Config.OffenseCategories = {
    traffic = { label = 'Traffic Violations', color = '#3B82F6' },
    misdemeanor = { label = 'Misdemeanors', color = '#F59E0B' },
    felony = { label = 'Felonies', color = '#EF4444' },
    warrant = { label = 'Warrants', color = '#DC2626' },
    citation = { label = 'Citations', color = '#10B981' }
}

-- Evidence Types
Config.EvidenceTypes = {
    photo = { label = 'Photograph', icon = 'camera' },
    note = { label = 'Note', icon = 'document-text' },
    weapon = { label = 'Weapon', icon = 'shield-exclamation' },
    drug = { label = 'Drugs', icon = 'beaker' },
    other = { label = 'Other', icon = 'archive' }
}

-- Automatic Archiving
Config.Archiving = {
    closedIncidents = 30, -- days before archiving
    resolvedCalls = 7,
    executedWarrants = 14
}

-- Rate Limiting
Config.RateLimits = {
    search = { count = 10, time = 30 },
    create = { count = 5, time = 60 },
    update = { count = 20, time = 30 }
}

-----------------------------------------------------------
-- Webhook (Discord audit logging via tb-lib)
-----------------------------------------------------------
Config.WebhookURL = '' -- set your Discord webhook URL here

-----------------------------------------------------------
-- Penal Code
-- Each charge has a fine range and jail range (minutes).
-- Officers pick the exact value with a slider when processing.
-----------------------------------------------------------
Config.PenalCode = {
    traffic = {
        { id = 'T01', title = 'Speeding',                   fineMin = 250,   fineMax = 1000,  jailMin = 0,  jailMax = 0,   points = 1 },
        { id = 'T02', title = 'Reckless Driving',           fineMin = 500,   fineMax = 2000,  jailMin = 0,  jailMax = 5,   points = 2 },
        { id = 'T03', title = 'Running a Red Light',        fineMin = 150,   fineMax = 500,   jailMin = 0,  jailMax = 0,   points = 1 },
        { id = 'T04', title = 'Driving Without a License',  fineMin = 500,   fineMax = 1200,  jailMin = 0,  jailMax = 0,   points = 2 },
        { id = 'T05', title = 'Illegal Parking',            fineMin = 100,   fineMax = 300,   jailMin = 0,  jailMax = 0,   points = 0 },
        { id = 'T06', title = 'Evading Police (Vehicle)',   fineMin = 1500,  fineMax = 5000,  jailMin = 5,  jailMax = 15,  points = 3 },
        { id = 'T07', title = 'DUI / Impaired Driving',     fineMin = 1000,  fineMax = 3000,  jailMin = 0,  jailMax = 10,  points = 3 },
    },
    misdemeanor = {
        { id = 'M01', title = 'Disorderly Conduct',         fineMin = 250,   fineMax = 1000,  jailMin = 0,  jailMax = 10,  points = 0 },
        { id = 'M02', title = 'Trespassing',                fineMin = 400,   fineMax = 1200,  jailMin = 0,  jailMax = 10,  points = 0 },
        { id = 'M03', title = 'Vandalism',                  fineMin = 500,   fineMax = 2000,  jailMin = 5,  jailMax = 15,  points = 0 },
        { id = 'M04', title = 'Petty Theft',                fineMin = 500,   fineMax = 2000,  jailMin = 5,  jailMax = 15,  points = 0 },
        { id = 'M05', title = 'Assault',                    fineMin = 1000,  fineMax = 3500,  jailMin = 10, jailMax = 20,  points = 0 },
        { id = 'M06', title = 'Possession of Illegal Item', fineMin = 750,   fineMax = 2500,  jailMin = 5,  jailMax = 15,  points = 0 },
        { id = 'M07', title = 'Resisting Arrest',           fineMin = 1000,  fineMax = 3000,  jailMin = 10, jailMax = 20,  points = 0 },
        { id = 'M08', title = 'Obstruction of Justice',     fineMin = 750,   fineMax = 2500,  jailMin = 5,  jailMax = 15,  points = 0 },
    },
    felony = {
        { id = 'F01', title = 'Grand Theft Auto',           fineMin = 2500,  fineMax = 8000,  jailMin = 20, jailMax = 40,  points = 0 },
        { id = 'F02', title = 'Armed Robbery',              fineMin = 4000,  fineMax = 12000, jailMin = 30, jailMax = 60,  points = 0 },
        { id = 'F03', title = 'Assault with Deadly Weapon', fineMin = 5000,  fineMax = 15000, jailMin = 40, jailMax = 80,  points = 0 },
        { id = 'F04', title = 'Attempted Murder',           fineMin = 8000,  fineMax = 20000, jailMin = 60, jailMax = 120, points = 0 },
        { id = 'F05', title = 'First Degree Murder',        fineMin = 15000, fineMax = 40000, jailMin = 90, jailMax = 240, points = 0 },
        { id = 'F06', title = 'Drug Trafficking',           fineMin = 10000, fineMax = 30000, jailMin = 40, jailMax = 90,  points = 0 },
        { id = 'F07', title = 'Kidnapping',                 fineMin = 6000,  fineMax = 18000, jailMin = 40, jailMax = 90,  points = 0 },
        { id = 'F08', title = 'Terrorism',                  fineMin = 25000, fineMax = 75000, jailMin = 120, jailMax = 360, points = 0 },
        { id = 'F09', title = 'Bank Robbery',               fineMin = 8000,  fineMax = 25000, jailMin = 40, jailMax = 90,  points = 0 },
        { id = 'F10', title = 'Possession of Class A Drug', fineMin = 5000,  fineMax = 15000, jailMin = 30, jailMax = 60,  points = 0 },
    },
}

-----------------------------------------------------------
-- Charge processing — fines & jail
-----------------------------------------------------------
Config.Fines = {
    -- 'bank_then_record' = deduct from bank if online & affordable,
    --                      otherwise store an unpaid fine record.
    -- 'record_only'      = never auto-deduct, always create an unpaid record.
    method  = 'bank_then_record',
    account = 'bank',
}

Config.Jail = {
    enabled  = true,
    -- 'event'  = fire Config.Jail.event with (targetSrc, minutes) — works with
    --            qb-policejob/qb-prison style handlers out of the box.
    -- 'export' = call Config.Jail.export(targetSrc, minutes) if you use a
    --            custom prison resource; edit the function below.
    -- 'none'   = record sentence on the rap sheet only (no teleport).
    mode  = 'event',
    event = 'police:server:JailPlayer', -- (source, timeMinutes) — qb-prison compatible
    -- Used when mode = 'export'. Adapt to your prison resource:
    export = function(targetSrc, minutes, charges)
        -- e.g. exports['xt-prison']:JailPlayer(targetSrc, minutes)
        TriggerEvent('police:server:JailPlayer', targetSrc, minutes)
    end,
}

-- Driver's license points: auto-revoke at the limit.
Config.LicensePoints = {
    enabled    = true,
    limit      = 12,        -- accumulated points that trigger revocation
    license    = 'driver',  -- metadata licence key to revoke
}

-----------------------------------------------------------
-- Panic button
-----------------------------------------------------------
Config.Panic = {
    enabled      = true,
    command      = 'panic',
    key          = 'F9',
    cooldown     = 30,   -- seconds between presses per officer
    blipDuration = 60,   -- seconds the panic blip stays on the map
    blipSprite   = 161,
    blipColor    = 1,
    blipScale    = 1.2,
}