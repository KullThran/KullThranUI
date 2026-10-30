local fs = require('lfs')
local io = require('io')

local file = io.open('c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/KullThranUI/Options.lua', 'r')
local content = file:read('*all')
file:close()

local vars = {
    'PAGE_ICON_MAP',
    'MENU_CATEGORIES',
    'PAGE_CATEGORY_MAP',
    'HIDDEN_OPTION_PAGES',
    'MODULE_ICON_MAP',
    'CATEGORY_DESCRIPTION_MAP',
    'MODULE_DESCRIPTION_MAP',
    'CATEGORY_OVERVIEW_PREFIX',
    'CATEGORY_OVERVIEW_TEXTURE',
    'activePageId',
    'openCategoryIds',
    'navButtons',
    'categoryButtons',
    'pages',
    'MENU_ICON_PRESERVE_COLOR',
    'OPTIONS_RECYCLER',
    'PAGE_ICON_STYLE_MAP',
}

for _, v in ipairs(vars) do
    content = content:gsub('local ' .. v .. ' =', 'ns.' .. v .. ' =')
    content = content:gsub('local ' .. v .. '(%s)', 'ns.' .. v .. '%1')
    content = content:gsub('([^%.%w])' .. v .. '([^%w])', '%1ns.' .. v .. '%2')
end

local file = io.open('c:/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/KullThranUI/Options.lua', 'w')
file:write(content)
file:close()
print('Replaced variables')
