-- ============================================================
-- shared/framework.lua – Framework detection
-- Auto-detects Qbox (qbx_core) vs QBCore (qb-core) at runtime.
-- ============================================================

Framework = {}

if GetResourceState('qbx_core') == 'started' then
    Framework.name = 'qbox'
    Framework.core = 'qbx_core'
elseif GetResourceState('qb-core') == 'started' then
    Framework.name = 'qbcore'
    Framework.core = 'qb-core'
else
    CreateThread(function()
        Wait(500)
        print('^1[tb-mdt] FATAL: Neither qbx_core nor qb-core is running!^0')
    end)
end

if IsDuplicityVersion() then
    CreateThread(function()
        Wait(1000)
        local deps = {
            { name = 'ox_lib',   label = 'ox_lib' },
            { name = 'oxmysql',  label = 'oxmysql' },
            { name = 'tb-lib',   label = 'tb-lib' },
        }
        for _, dep in ipairs(deps) do
            if GetResourceState(dep.name) ~= 'started' then
                print(('^3[tb-mdt] WARNING: %s is not running — some features may not work.^0'):format(dep.label))
            end
        end
        if Framework.name then
            print(('^2[tb-mdt]^0 Framework detected: ^3%s^0 (%s)'):format(
                Framework.name == 'qbox' and 'Qbox' or 'QBCore',
                Framework.core
            ))
        end
    end)
end
