-- Loaded after every other locale file. Many translations were written with
-- an escaped newline ("\\n" in the source), which the UI printed as the two
-- characters "\n". Turn them into real line breaks in every language.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local done = {}
for _, target in pairs(locales) do
    if type(target) == "table" and not done[target] then
        done[target] = true
        for key, value in pairs(target) do
            if type(value) == "string" and value:find("\\n", 1, true) then
                target[key] = value:gsub("\\n", "\n")
            end
        end
    end
end
