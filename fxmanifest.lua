fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'tb-mdt'
author 'Toybox'
description 'Police MDT — premium SaaS-style mobile data terminal'
version '1.1.0'

ui_page {
    'web/dist/index.html',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/framework.lua',
    'config.lua',
    'locales/en.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/tblib.lua',
    'server/database.lua',
    'server/main.lua',
    'server/records.lua',
}

files {
    'web/dist/index.html',
    'web/dist/assets/*.*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'tb-lib',
}