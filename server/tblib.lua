-- ============================================================
-- server/tblib.lua — TB namespace proxy for tb-mdt
-- Globals do NOT cross resources in FiveM, so the `TB` table
-- defined inside tb-lib is not visible here. This proxy
-- forwards TB.<fn>(...) to exports['tb-lib']:<fn>(...).
-- Must load before any other tb-mdt server script.
-- ============================================================

TB = setmetatable({
    --- tb-lib exports `Webhook(url, title, message, color, fields, tags, footer)`
    --- (positional). Adapt the table-style call used throughout tb-mdt.
    SendWebhook = function(url, data)
        data = data or {}
        return exports['tb-lib']:Webhook(url, data.title, data.message, data.color, data.fields, nil, data.footer)
    end,
}, {
    __index = function(self, fnName)
        local fn = function(...)
            return exports['tb-lib'][fnName](exports['tb-lib'], ...)
        end
        rawset(self, fnName, fn) -- cache so the closure is built once
        return fn
    end,
})
