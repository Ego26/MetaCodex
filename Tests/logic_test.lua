-- Prueft den Katalogzugriff gegen die wirklich erzeugten Daten.
local ns = {}
local chunk = assert(loadfile(BASE .. "/MetaCodex_Data/Catalog.lua"))
chunk()
local core = assert(loadfile(BASE .. "/Core/Catalog.lua"))
core("MetaCodex", ns)

local fails = 0
local function check(name, condition, detail)
  if condition then
    print("  ok   " .. name .. (detail and ("  -> " .. detail) or ""))
  else
    fails = fails + 1
    print("  FAIL " .. name .. (detail and ("  -> " .. detail) or ""))
  end
end

check("Katalog geladen", ns.Catalog.Ready())
local build, builtOn = ns.Catalog.Stamp()
check("Stempel", build ~= "?" and builtOn > 0, build .. " / " .. builtOn)

-- Ringe: zwei Zeilen je Kennwert, die staerkere muss gewinnen.
local ring = ns.Catalog.Enchant("ring", "haste")
check("Ring/Tempo gefunden", ring ~= nil, ring and ring.name)
local weakest = nil
for _, e in ipairs(ns.Catalog.EnchantsFor("ring")) do
  if e.stat == "haste" and (not weakest or e.power < weakest.power) then weakest = e end
end
check("staerkere Ringzeile gewinnt", ring and weakest and ring.power > weakest.power,
  ring and weakest and (ring.power .. " > " .. weakest.power))
check("Ring hat guenstigere Stufe", ring and ring.alt ~= nil, ring and tostring(ring.alt))

-- Brust: die Zeile fuer alle drei Attribute ist staerker als die einzelne.
for _, primary in ipairs({ "agi", "str", "int" }) do
  local chest = ns.Catalog.ChestEnchant(primary)
  check("Brust/" .. primary, chest ~= nil and chest.stat == "primary", chest and chest.name)
end

-- Steine: gleicher Haupt- und Nebenwert ist der reine Stein.
local pure = ns.Catalog.Gem("haste", "haste")
check("reiner Tempostein", pure ~= nil and pure.q == 3, pure and (pure.name .. " ilvl " .. pure.ilvl))
local mixed = ns.Catalog.Gem("mastery", "crit")
check("Mischstein Meister/Krit ist Amethyst (Farbe = Hauptwert)", mixed ~= nil and mixed.name:find("Amethyst") ~= nil, mixed and mixed.name)
local cheap = ns.Catalog.CheapGem("haste", "haste")
check("guenstiger Tempostein", cheap ~= nil and cheap.q == 2, cheap and cheap.name)
check("guenstig ist nicht teuer", pure and cheap and pure.id ~= cheap.id)

-- Alle vier Kennwerte muessen in jeder Kombination einen Stein haben.
local stats = { "crit", "haste", "mastery", "vers" }
local missing = {}
for _, a in ipairs(stats) do
  for _, b in ipairs(stats) do
    if not ns.Catalog.Gem(a, b) then missing[#missing + 1] = a .. "/" .. b end
  end
end
check("16 Steinkombinationen vollstaendig", #missing == 0, table.concat(missing, ", "))

-- Jeder Platz, den das Addon kennt, muss auch im Katalog stehen.
for _, slot in ipairs({ "helm", "shoulders", "chest", "legs", "boots", "ring", "weapon" }) do
  check("Platz " .. slot, #ns.Catalog.EnchantsFor(slot) > 0,
    #ns.Catalog.EnchantsFor(slot) .. " Eintraege")
end

check("IDs zum Vorladen", #ns.Catalog.AllIDs() > 100, #ns.Catalog.AllIDs() .. " IDs")

print(fails == 0 and "\nalles gruen" or ("\n" .. fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
