-- Guides: der eine Abschnitt, der nichts misst.
--
-- Alles andere in MetaCodex ist gezaehlt. Rotationen und geschriebene
-- Erklaerungen sind es nicht - sie sind Arbeit von Menschen, die dafuer
-- eine Seite betreiben. Also wird hier NICHT abgeschrieben, sondern
-- verwiesen: Adresse, Name der Quelle, fertig.
--
-- Das ist keine Bequemlichkeit, sondern die einzige saubere Loesung. Der
-- Text einer Guide-Seite gehoert der Seite. Ihn in ein Addon zu kopieren
-- waere eine Urheberrechtsfrage, und die Antwort waere nein.

local _, ns = ...

local Guides = {}
ns.Guides = Guides

-- Woher die Adressen kommen. Jede Zeile nennt ihre Quelle, und die wird
-- im Fenster auch angezeigt - wer hier klickt, soll wissen, wessen Arbeit
-- er gleich liest.
local SITES = {
    -- Wowheads Rotationsseite: die Adresse endet auf die ROLLE.
    --
    -- .../rotation-cooldowns-pve-dps, -healer, -tank. Am 9. Oktober 2026
    -- fuer alle vierzig Speccs nachgemessen, je drei Rollen durchprobiert:
    -- jede Spec hat genau eine Seite, 27 dps, 7 Heiler, 6 Tanks, keine
    -- mehrdeutig.
    --
    -- Vorher stand hier /overview-pve-<rolle>. Das war die Uebersicht,
    -- nicht die Rotation - sie laedt zwar, beantwortet aber die Frage
    -- nicht, die in der Zeile steht ("Rotation, Abklingzeiten und
    -- Faehigkeiten"). Ein Link, der irgendwo richtig landet, ist noch
    -- kein richtiger Link.
    --
    -- Ohne bekannte Rolle bleibt /overview der Rueckfall: lieber die
    -- Uebersicht als eine 404.
    {
        key = "wowhead",
        name = "Wowhead",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
        url = function(cls, spec, role) return
            ("https://www.wowhead.com/guide/classes/%s/%s/%s")
                :format(cls, spec,
                    role and ("rotation-cooldowns-pve-" .. role) or "overview")
        end,
    },
    {
        key = "wowhead_bis",
        name = "Wowhead",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
        url = function(cls, spec) return
            ("https://www.wowhead.com/guide/classes/%s/%s/bis-gear"):format(cls, spec)
        end,
    },
    {
        key = "method",
        name = "Method",
        icon = "Interface\\Icons\\INV_Misc_Book_07",
        url = function(cls, spec) return
            ("https://www.method.gg/guides/%s-%s"):format(spec, cls)
        end,
    },
    -- Archons Adressen haben mehr Teile, als ich angenommen hatte.
    --
    -- Meine Fassung war /<spec>/<class>/mythic-plus/high-keys/overview und
    -- ergab 404. Richtig ist:
    --     /<spec>/<class>/<inhalt>/<seite>/<keys>/<dungeon>/<zeitraum>
    -- Die Seitennamen und die 10 sind belegt: beide Adressen standen in
    -- der Adresszeile eines Browsers, in dem die Seite offen war. Die 10
    -- ist die Mindest-Schluesselstufe - "high-keys" steht dort NICHT,
    -- obwohl die Seite es so beschriftet. Geraten wird nichts: eine
    -- Adresse ins Leere ist schlimmer als eine fehlende.
    {
        key = "archon_gems",
        name = "Archon",
        icon = "Interface\\Icons\\INV_Misc_Book_17",
        url = function(cls, spec) return
            ("https://www.archon.gg/wow/builds/%s/%s/mythic-plus/"
                .. "enchants-and-gems/10/all-dungeons/this-week")
                :format(spec, cls)
        end,
    },
    {
        key = "archon_consum",
        name = "Archon",
        icon = "Interface\\Icons\\INV_Misc_Book_17",
        url = function(cls, spec) return
            ("https://www.archon.gg/wow/builds/%s/%s/mythic-plus/"
                .. "consumables/10/all-dungeons/this-week")
                :format(spec, cls)
        end,
    },
    {
        key = "murlok",
        name = "murlok.io",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        url = function(cls, spec) return
            ("https://murlok.io/%s/%s/m%%2B"):format(cls, spec)
        end,
    },
}

---Die Verweise fuer eine Spec.
---@param specID number
---@return table[] { key, site, url }
function Guides.For(specID)
    local cls, spec = ns.Catalog.SpecSlug(specID)
    if not cls or not spec then return {} end
    -- Erst der Client, dann der Katalog: der Client weiss die Rolle
    -- auch dann, wenn die Daten von gestern sind.
    local role = ns.Compat.SpecRole and ns.Compat.SpecRole(specID) or nil

    local out = {}
    for _, site in ipairs(SITES) do
        out[#out + 1] = {
            key = site.key,
            site = site.name,
            icon = site.icon,
            url = site.url(cls, spec, role),
        }
    end
    return out
end
