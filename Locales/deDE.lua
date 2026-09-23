local _, ns = ...

ns.RegisterLocale("deDE", {
    ["TITLE"]              = "MetaCodex",
    ["SLOGAN"]             = "Aus echten Kämpfen, nicht aus Guides.",

    -- Slots
    ["SLOT_helm"]          = "Kopf",
    ["SLOT_shoulders"]     = "Schultern",
    ["SLOT_chest"]         = "Brust",
    ["SLOT_legs"]          = "Beine",
    ["SLOT_boots"]         = "Füße",
    ["SLOT_ring"]          = "Ringe",
    ["SLOT_weapon"]        = "Waffe",
    ["SLOT_gems"]          = "Sockelsteine",

    -- Kennwerte
    ["STAT_crit"]          = "Kritische Trefferwertung",
    ["STAT_haste"]         = "Tempo",
    ["STAT_mastery"]       = "Meisterschaft",
    ["STAT_vers"]          = "Vielseitigkeit",
    ["STAT_speed"]         = "Geschwindigkeit",
    ["STAT_leech"]         = "Lebensraub",
    ["STAT_avoid"]         = "Vermeidung",
    ["STAT_primary"]       = "Hauptattribut",
    ["STAT_agi"]           = "Beweglichkeit",
    ["STAT_str"]           = "Stärke",
    ["STAT_int"]           = "Intelligenz",
    ["STAT_proc"]          = "Effekt",
    ["STAT_legs"]          = "Beinverstärkung",
    ["STAT_unknown"]       = "Unbekannt",

    -- Kopf
    ["LBL_MAIN_STAT"]      = "Hauptwert",
    ["LBL_SECOND_STAT"]    = "Zweitwert",
    ["LBL_TERTIARY"]       = "Drittwert",
    ["LBL_RANK"]           = "Stufe",
    ["RANK_BEST"]          = "Höchste",
    ["RANK_CHEAP"]         = "Günstigere",
    ["DATA_AS_OF"]         = "Katalog %s, erzeugt %s",
    ["PICK_HINT"]          = "Werte auswählen – den Rest macht MetaCodex.",

    -- Zeilen
    ["ALREADY_DONE"]       = "bereits drauf",
    ["OTHER_ENCHANT"]      = "etwas anderes ist drauf: %s",
    ["RUNEFORGE_NOTE"]     = "wird geschmiedet, nicht gekauft",
    ["RUNEFORGE_PICK"]     = "Rune auf deiner Waffe",
    ["OWNED"]              = "%d vorhanden",
    ["OWNED_HIGHER"] = "%d in höherer Qualität vorhanden",
    ["OWNED_LOWER"] = "%d in niedrigerer Qualität vorhanden",
    ["GEAR_WORN"] = "angelegt",
    ["CHARBTN_CLICK"] = "Klicken, um MetaCodex zu öffnen oder zu schließen",
    ["MINIMAP_CLICK"] = "Klicken zum Öffnen oder Schließen  ·  Rechtsklick für die Einstellungen",
    ["MINIMAP_DRAG"] = "Ziehen verschiebt ihn um die Minimap",
    ["SET_GROUP_OPEN"] = "Wo es aufgeht",
    ["SET_GROUP_WINDOW"] = "Fenster",
    ["SET_MINIMAP"] = "Knopf an der Minimap",
    ["SET_CHARBTN"] = "Knopf am Charakterfenster",
    ["SET_SCALE"] = "Schriftgröße",
    ["SET_LANG"] = "Sprache",
    ["SET_LANG_AUTO"] = "Folgt dem Client",
    ["SET_LANG_EN"] = "English",
    ["SET_LANG_DE"] = "Deutsch",
    ["SET_LANG_RELOAD"] = "Beschriftungen, die schon stehen, wechseln nach /reload.",
    ["SET_HINT"] = "Die Erinnerung hat ihre eigenen Einstellungen, direkt neben dem, was sie steuern.",
    ["SET_GROUP_START"] = "Beim Öffnen",
    ["SET_RESET"] = "Fensterlage und -größe",
    ["SET_RESET_DO"] = "zurücksetzen",
    ["SET_START"] = "Startet mit",
    ["SET_START_LAST"] = "Was zuletzt offen war",
    ["CHARBTN_MOVE"] = "Umschalt-Ziehen zum Verschieben  ·  Umschalt-Rechtsklick zum Zurücksetzen",
    ["REMIND_LOWER"] = "%s (nur niedrigere Qualität: %d)",
    ["NEED"]               = "%d fehlen",
    ["EMPTY_SOCKETS"]      = "%d leere Sockel",
    ["NO_EMPTY_SOCKETS"]   = "Keine leeren Sockel an deiner Ausrüstung.",
    ["CHOOSE"]             = "wählen",
    ["STRONG"]             = "stark",
    ["CHEAP"]              = "günstig",

    -- Knoepfe
    ["BTN_CREATE_LIST"]    = "Einkaufsliste anlegen",
    ["BTN_SEARCH"]         = "Jetzt suchen",
    ["BTN_ONLY_MISSING"]   = "Nur was mir fehlt",
    ["BTN_REFRESH"]        = "Ausrüstung neu lesen",

    -- Meldungen
    ["NO_AUCTIONATOR"]     = "Auctionator ist nicht geladen – die Liste steht da, lässt sich aber nicht übergeben.",
    ["LIST_TEMPORARY"] = "Nur für diesen Einkauf - beim Schließen des Auktionshauses geht sie wieder weg.",
    ["LIST_DROPPED"] = "Einkaufsliste entfernt: %s",
    ["LIST_CREATED"]       = "%d Einträge in die Liste \"%s\" geschrieben.",
    ["LIST_FAILED"]        = "Auctionator hat die Liste abgelehnt: %s",
    ["NOTHING_TO_BUY"]     = "Nichts zu kaufen – alles verzaubert und gesockelt.",
    ["NAMES_PENDING"]      = "Gegenstandsnamen werden geladen, einen Moment …",
    ["NO_CATALOG"]         = "Data/Catalog.lua fehlt oder ist leer. tools/build-catalog.js ausführen.",

    -- Slash
    ["SLASH_HELP"]         = "Befehle:",
    ["SLASH_OPEN"]         = "/mc – Fenster öffnen",
    ["SLASH_PROBE"]        = "/mc probe – prüfen, was dieser Client und Auctionator wirklich hergeben",
    ["SLASH_LANG"]         = "/mc lang de|en|auto – Sprache der Oberfläche",
    ["SLASH_SCALE"]        = "/mc scale 0.6–1.6 – Schriftgröße im Fenster (1 = normal)",
    ["SCALE_SET"]          = "Schriftgröße: %s",
    ["SLASH_RESET"]        = "/mc reset – gespeicherte Auswahl vergessen",
    ["RESET_DONE"]         = "Gespeicherte Auswahl gelöscht.",
    ["LANG_SET"]           = "Sprache: %s",

    -- Probe
    ["PROBE_HEADER"]       = "Sonde (%s, Katalog %s):",
    ["PROBE_YES"]          = "|cff40d070ja|r",
    ["PROBE_NO"]           = "|cffd04040nein|r",
    ["PROBE_AUCTIONATOR"]  = "Auctionator geladen",
    ["PROBE_API"]          = "Auctionator.API.v1.CreateShoppingList",
    ["PROBE_SEARCH"]       = "Auctionator.API.v1.MultiSearchExact",
    ["PROBE_CONVERT"]      = "Auctionator.API.v1.ConvertToSearchString (Stueckzahl in der Liste)",
    ["PROBE_NAMES"]        = "Aufgelöste Gegenstandsnamen: %d von %d",
    ["PROBE_UNRESOLVED"]   = "Nicht aufgelöste IDs: %s",
    ["PROBE_PRIMARY"]      = "Erkanntes Hauptattribut: %s",
    ["PROBE_SOCKETS"]      = "Leere Sockel an der Ausrüstung: %d",
})

-- Kurzformen fuer die Knopfleisten. Die langen Namen passen dort nicht.
ns.RegisterLocale("deDE", {
    ["STATSHORT_crit"]    = "Krit",
    ["STATSHORT_haste"]   = "Tempo",
    ["STATSHORT_mastery"] = "Meister",
    ["STATSHORT_vers"]    = "Viels.",
    ["STATSHORT_speed"]   = "Gesch.",
    ["STATSHORT_leech"]   = "Lebensraub",
    ["STATSHORT_avoid"]   = "Vermeid.",
    ["OPT_CHEAP"]         = "Günstigere Stufe",
    ["OPT_ONLY_MISSING"]  = "Nur was fehlt",
    ["PICK_WEAPON"]       = "Waffenverzauberung wählen",
    ["PICK_LEGS"]         = "Beinverstärkung wählen",
    ["PICK_TERTIARY"]     = "Drittwert oben wählen",
    ["SLOT_COUNT"]        = "%d Platz/Plätze",
})

-- Auswahl der Spezialisierung, dazugekommen mit dem Waehler im Kopf.
ns.RegisterLocale("deDE", {
    ["LBL_SPEC"]        = "Spezialisierung",
    ["SPEC_ACTIVE"]     = "Aktive Spezialisierung",
    ["FOREIGN_CLASS"]   = "Fremde Klasse: MetaCodex kann deren Ausrüstung nicht lesen und zeigt deshalb die vollständige Ausstattung statt des Fehlenden.",
    ["SHOW_ALL_HINT"]   = "Haken bei „Nur was fehlt“ entfernen, um alles zu sehen.",
    ["PROBE_SPEC"]      = "Gezeigte Spezialisierung: %s (%s)",
    ["PROBE_STAT_API"]  = "vom Client",
    ["PROBE_STAT_CHAR"] = "vom Charakter",
})

ns.RegisterLocale("deDE", {
    ["SOCKETS"] = "%d Sockel, davon %d leer",
    ["IN_BAGS"] = "liegt schon in der Tasche",
})

ns.RegisterLocale("deDE", {
    ["READY_ALL"] = "Startklar: verzaubert, gesockelt, eingedeckt.",
    ["READY_OPEN"] = "Noch offen: %s",
    ["READY_ENCHANTS"] = "%d Verzauberungen",
    ["READY_GEMS"] = "%d Steine",
    ["READY_CONSUM"] = "%d Arten Verbrauchsgut",
    ["SOURCE_LINE"]  = "Empfehlungen: %s, %s",
    ["NO_MODE_DATA"] = "Für diesen Spielmodus gibt es noch keine Daten – Werte unten selbst wählen.",
})

-- Neues Fenster: Abschnitte der Seitenleiste und Kopfzeile.
ns.RegisterLocale("deDE", {
    ["GROUP_SHOPPING"]     = "Einkauf",
    ["GROUP_PREP"]         = "Vorbereitung",
    ["SECTION_all"]        = "Alles",
    ["SECTION_enchants"]   = "Verzauberungen",
    ["SECTION_gems"]       = "Sockelsteine",
    ["SECTION_consumables"]= "Verbrauchsgüter",
    ["SECTION_remind"]     = "Erinnerung",
    ["SECTION_gear"]       = "Ausrüstung",
    ["SECTION_talents"]    = "Talente",
    ["SOON_CONSUMABLES"]   = "Noch nicht gesammelt. Fläschchen, Tränke, Essen und Runen stehen in denselben Logs wie die Verzauberungsdaten – sie werden nur noch nicht ausgelesen.",
    ["SOON_GEAR"]          = "Noch nicht gesammelt. Die Berichte tragen den Gegenstand je Platz bereits; es fehlt die Auswertung, nicht die Datenlage.",
    ["SOON_TALENTS"]       = "Noch nicht gesammelt. Talentbelegungen stehen in den Logs, je Dungeon und je Boss.",
    ["LBL_ACTIVITY"]       = "Aktivität",
    ["NO_DATA_SUFFIX"]     = "(keine Daten)",
    ["COUNT_MISSING"]      = "%d zu kaufen",
})

-- Plattformwahl und die neue Themenliste.
ns.RegisterLocale("deDE", {
    ["GROUP_KNOW"]         = "Wissen",
    ["GROUP_GEAR"]         = "Ausrüstung",
    ["SECTION_settings"]   = "Einstellungen",
    ["SECTION_guides"]     = "Guides & Rotation",
    ["SECTION_stats"]      = "Zielwerte",
    ["SECTION_players"]    = "Top-Spieler",
    ["SECTION_folio"]      = "Omnium Folio",
    ["FOLIO_GROUP"]        = "Omnium-Foliant",
    ["FOLIO_ROW"]          = "Zeile %d",
    ["FOLIO_UNMEASURED"]   = "-",
    ["FOLIO_HINT"]         = "Anteil der Besten, bei denen die Rune im Kampf ausgelöst hat. Rein passive Runen lösen nie aus und stehen ohne Zahl.",
    ["LBL_HERO"]           = "Held-Talente",
    ["HERO_ALL"]           = "Alle Held-Bäume",
    ["HERO_ENTRY"]         = "%s · %d %%",
    ["SECTION_enchants"]   = "Verzauberungen & Steine",
    ["LBL_SOURCE"]         = "Plattform",
    ["SOURCE_ALL"]         = "Alle Plattformen",
    ["SOON_GUIDES"]        = "Noch nicht gebaut. Rotationen sind geschriebener Text und nicht messbar – sie kämen mit Quellenangabe von Wowhead oder Method.gg, und das ist eine andere Art von Daten als alles andere hier.",
    ["SOON_STATS"]         = "Noch nicht gebaut. Die Zielwerte folgen aus derselben Ausrüstung, aus der auch die Verzauberungsdaten kommen – es fehlt die Auswertung.",
})

ns.RegisterLocale("deDE", {
    ["GEARSLOT_Head"]     = "Kopf",
    ["GEARSLOT_Neck"]     = "Hals",
    ["GEARSLOT_Shoulders"]= "Schultern",
    ["GEARSLOT_Back"]     = "Rücken",
    ["GEARSLOT_Chest"]    = "Brust",
    ["GEARSLOT_Wrist"]    = "Handgelenke",
    ["GEARSLOT_Hands"]    = "Hände",
    ["GEARSLOT_Waist"]    = "Taille",
    ["GEARSLOT_Legs"]     = "Beine",
    ["GEARSLOT_Feet"]     = "Füße",
    ["GEARSLOT_Rings"]    = "Ringe",
    ["GEARSLOT_Trinkets"] = "Schmuck",
    ["GEARSLOT_MainHand"] = "Waffenhand",
    ["GEARSLOT_OffHand"]  = "Nebenhand",
})

ns.RegisterLocale("deDE", {
    ["PROBE_STAT_FALLBACK"] = "Rückfall – der Client gab keine Auskunft",
})

ns.RegisterLocale("deDE", {
    ["LBL_LEVEL"] = "Mindeststufe",
    ["LEVEL_ALL"] = "Alle Stufen",
    ["LEVEL_MIN"] = "Stufe %d+",
})

ns.RegisterLocale("deDE", { ["BADGE_SET"] = "Set-Teil", ["BADGE_CRAFT"] = "Handwerk" })

ns.RegisterLocale("deDE", { ["ILVL"] = "Stufe %d" })

ns.RegisterLocale("deDE", {
    ["CONSUM_flask"]   = "Fläschchen",
    ["CONSUM_potion"]  = "Kampftränke",
    ["CONSUM_food"]    = "Speisen",
    ["CONSUM_vantus"]  = "Vantus-Runen",
    ["CONSUM_oil"]     = "Waffenbuffs (Öle, Wetzsteine)",
    ["CONSUM_other"]   = "Runen & Sonstiges",
    ["CONSUM_TARGET_MENU"] = "Wie viele ich will",
    ["CONSUM_TARGET_OWN"] = "Andere Zahl…",
    ["CONSUM_HINT"] = "Klick auf ein Verbrauchsgut: Menge festlegen oder sagen, welches du nimmst.",
    ["NUMBER_OK"] = "Übernehmen",
    ["CONSUM_USE_THIS"] = "Das nehme ich",
    ["CONSUM_FROM_BAGS"] = "Aus meinen Taschen wählen",
    ["CONSUM_USE_MEASURED"] = "Zurück zu dem, was die Besten nehmen",
    ["CONSUM_MINE"] = "deine Wahl",
    ["CONSUM_TARGET"]  = "Ziel %d",
    ["REMIND_TITLE"]   = "MetaCodex erinnert",
    ["REMIND_MISSING"] = "Fehlt vor dem Start: %s",
    ["REMIND_OK"]      = "Fläschchen, Speise und Runen sind in der Tasche.",
    ["REMIND_NONE"]    = "%s: nichts in der Tasche",
    ["REMIND_LOW"]     = "%s: nur noch %d",
    ["LBL_REMINDERS"]  = "Erinnern",
    ["REMIND_HINT"]    = "Was die Erinnerung prüft, bevor es losgeht. Klick auf eine Zeile ändert die Zielmenge; unten kaufst du, was fehlt.",
    ["REMIND_GROUP_STATUS"]   = "Stand jetzt",
    ["REMIND_GROUP_SETTINGS"] = "Einstellungen",
    ["REMIND_HAVE"]    = "%d von %d",
    ["REMIND_STATE_OK"]   = "reicht",
    ["REMIND_STATE_LOW"]  = "knapp",
    ["REMIND_STATE_NONE"] = "leer",
    ["REMIND_OPT_ON"]  = "Erinnerungen",
    ["REMIND_OPT_ENTER"] = "Beim Betreten von Dungeon oder Raid erinnern",
    ["REMIND_GROUP_WAYS"] = "Wie es sich meldet",
    ["REMIND_WAY_CHAT"] = "Chatzeile",
    ["REMIND_WAY_WINDOW"] = "Eigenes Fenster",
    ["REMIND_WAY_WARNING"] = "Schlachtzugswarnung über dem Bild",
    ["REMIND_WAY_SOUND"] = "Ton",
    ["REMIND_OPEN_LIST"] = "Im Addon öffnen",
    ["REMIND_PREVIEW"] = "Zeig mir, wie es aussieht",
    ["REMIND_PREVIEW_DO"] = "Vorschau",
    ["REMIND_PREVIEW_EMPTY"] = "Nichts fehlt - so sähe eine Erinnerung aus.",
    ["REMIND_WIN_NONE"] = "nichts in der Tasche",
    ["REMIND_WIN_LOW"] = "%d von %d",
    ["REMIND_WIN_LOWER"] = "%d in niedrigerer Qualität",
    ["REMIND_WINDOW_TITLE"] = "Bevor du reingehst",
    ["REMIND_OPT_AH"]  = "Am Auktionshaus an Fehlendes erinnern",
    ["REMIND_OPT_BELOW"] = "Als knapp gilt, was unter diesem Anteil des Ziels liegt",
    ["REMIND_GROUP_ENCHANTS"] = "Verzauberungen & Steine, die noch fehlen",
    ["REMIND_ENCHANTS_OK"] = "Alles verzaubert und gesockelt",
    ["REMIND_ENCHANTS"] = "%d Verzauberungen oder Steine offen",
    ["OPTION_PICK"]    = "klicken zum Auswählen",
    ["OPTION_CLICK"]   = "Klick zum Umschalten",
    ["OPTION_ON"]      = "An",
    ["OPTION_OFF"]     = "Aus",
})

ns.RegisterLocale("deDE", {
    ["SLASH_REMIND"] = "/mc remind - beim Betreten von Dungeon oder Raid vor fehlenden Verbrauchsgütern warnen",
    ["REMIND_ON"]    = "Erinnerung an.",
    ["REMIND_OFF"]   = "Erinnerung aus.",
})

ns.RegisterLocale("deDE", {
    ["LBL_DUNGEON"] = "Dungeon",
    ["DUNGEON_ALL"] = "Alle Dungeons",
    ["LBL_BOSS"]    = "Boss",
    ["BOSS_ALL"]    = "Alle Bosse",
    ["KEY_RANGE"]   = "+%d bis +%d",
    ["KEY_HIGH"]    = "Hohe Keys",
})

ns.RegisterLocale("deDE", {
    ["TALENT_BUILD"] = "Häufigster Build  ·  %d%% spielen genau diesen",
    ["LOADOUT_FROM_BASE"] = "String aus M+ gesamt",
    ["LOADOUT_FROM_SOURCE"] = "String von %s",
    ["TALENT_PICKS"] = "Einzelne Talente und wie viele sie nehmen",
    ["TALENT_PICKS_HINT"] = "Anteil der Top-Spieler, die dieses Talent haben. Zeiger drauf zeigt, was es tut.",
    ["TALENT_SHARE"] = "%d %% der Besten nehmen es",
    ["TALENT_RANK"]  = "Rang %d",
})

ns.RegisterLocale("deDE", {
})

ns.RegisterLocale("deDE", {
    ["GUIDE_GROUP"]       = "Geschriebene Guides",
    ["GUIDE_COPY"]        = "Klick kopiert die Adresse",
    ["PLAYER_COPY"]       = "Klick öffnet das Profil",
    ["PLAYER_HINT"]       = "Wer diese Spezialisierung gerade oben spielt. Klick auf eine Zeile öffnet ihr Profil: Talent-String, Ausrüstung, Adresse.",
    ["PLAYER_RANK"]       = "Platz %d",
    ["ORIGIN_CONQUEST"]   = "Eroberungspunkte-Händler",
    ["ORIGIN_HONOR"]      = "Ehre-Händler",
    ["ORIGIN_PVPCRAFT"]   = "Handwerk (PvP)",
    ["ORIGIN_NONE"]       = "kein Instanzdrop",
    ["ORIGIN_WORLD"]      = "Welt, Quest oder Händler",
    ["LBL_ORIGIN"]        = "Fundort",
    ["SOURCE_ANY"]        = "Alle Fundorte",
    ["KEY_STEP_UPGRADE"]  = "%d  (Aufwertung)",
    ["KEY_STEP_VAULT"]    = "%d  (Tresor %s)",
    ["KEY_LABEL"]         = "%s %d · %d",
    ["PLAYER_ENCHANT"] = "Verzauberung auf diesem Stück",
    ["PLAYER_GEM"] = "Stein in diesem Stück",
    ["PLAYER_BACK"]       = "Zurück zu Top-Spieler",
    ["PLAYER_VIEW_HINT"]  = "Was dieser Spieler gerade trägt und spielt, laut raider.io. Tooltips zeigen das Stück genau so, wie er es trägt.",
    ["PLAYER_LOADOUT"]    = "Talent-String dieses Spielers kopieren",
    ["PLAYER_VERIFIED"]   = "geprüft: Talente passen zur Aktivität",
    ["PLAYER_UNVERIFIED"] = "ungeprüft: könnte sein Build für eine andere Aktivität sein",
    ["PLAYER_PROFILE"]    = "Profil im Browser",
    ["PLAYER_ILVL"]       = "Gegenstandsstufe %d",
    ["PLAYER_NO_PROFILE"] = "Für diesen Spieler liegt kein Profil vor",
    ["PLAYER_LOADING"]    = "Profile werden geladen …",
    -- Die Aufwertungspfade, wie der Client sie nennt. Die Zahl ist die
    -- SharedString-ID aus den Spieldaten; der Name ist Blizzards Wort.
    ["TRACK_970"]         = "Entdecker",
    ["TALENT_PVP"]        = "PvP-Talente",
    ["TRACK_971"]         = "Abenteurer",
    ["TRACK_972"]         = "Veteran",
    ["TRACK_973"]         = "Champion",
    ["TRACK_974"]         = "Held",
    ["TRACK_978"]         = "Mythisch",
    ["KEY_STEP_TRACK"]    = "%d · %s (%s %d)",
    ["LOADOUT_NO_STRING"] = "Für diese Aktivität liefert keine Quelle einen fertigen String — die Talente unten stimmen trotzdem",
    ["NO_PLAYERS"]        = "Für diese Aktivität führt keine Quelle eine Rangliste.",
    ["GUIDE_BY"]          = "von %s — öffnet im Browser",
    ["GUIDE_WOWHEAD"]     = "Rotation, Abklingzeiten und Fähigkeiten",
    ["GUIDE_WOWHEAD_BIS"] = "Best in Slot, erklärt",
    ["GUIDE_METHOD"]      = "Method-Guide",
    ["GUIDE_ARCHON_GEMS"]   = "Archon: Verzauberungen und Steine",
    ["GUIDE_ARCHON_CONSUM"] = "Archon: Verbrauchsgüter",
    ["GUIDE_MURLOK"]      = "Murlok.io: Seite von deiner Spezialisierung",
    ["GUIDE_HINT"]        = "MetaCodex misst; diese Seiten erklären. Klick auf eine Zeile kopiert ihre Adresse.",
    ["LINK_TITLE"]        = "Diese Adresse kopieren",
    ["LINK_HINT"]         = "Strg+C zum Kopieren. Ein AddOn kann selbst keinen Browser öffnen.",
    ["LINK_CLOSE"]        = "Schließen",
})

ns.RegisterLocale("deDE", {
    ["AH_OFFER"] = "%d Dinge fehlen noch. |cff4c8dff/mc|r öffnet die Liste.",
})

ns.RegisterLocale("deDE", {
    ["NO_SOURCE_SECTION"] = "%s hat dazu nichts für diese Aktivität. Probier eine andere Plattform oder alle.",
    ["NO_SPEC_SECTION"]   = "Noch keine Plattform hat genug Läufe dieser Spec in dieser Aktivität.",
})

ns.RegisterLocale("deDE", {
    ["AH_CLOSED"] = "Erst das Auktionshaus öffnen — die Suche läuft darin. Die Einkaufsliste lässt sich überall anlegen.",
})

ns.RegisterLocale("deDE", {
    ["MAX_KEY"] = "bis +%d",
})

ns.RegisterLocale("deDE", {
    ["CONSUM_heal"] = "Heiltränke",
})

ns.RegisterLocale("deDE", {
    ["NO_DUNGEON_DATA"] = "Die Auswertung je Dungeon ist ein eigenes AddOn (MetaCodex_Dungeons) und fehlt.",
})

ns.RegisterLocale("deDE", {
    ["SPEC_ALSO_BUY"] = "Mit einkaufen für…",
    ["COUNT_SPECS"]   = "Liste deckt %d Speccs",
})

ns.RegisterLocale("deDE", {
    ["LOADOUT_TITLE"]      = "Diesen Build kopieren",
    ["LOADOUT_HINT"]       = "%d Talente · im Talentfenster bei „Importieren“ einfügen",
    ["LOADOUT_DIFF_HINT"]  = "%d Talente anders · im Talentfenster bei „Importieren“ einfügen",
})


ns.RegisterLocale("deDE", {
    ["STAT_SHARE"] = "%d%% des Gesamtwerts",
    ["STAT_YOURS"] = "du hast %d von %d",
    ["STAT_GAP"] = "−%d",
    ["STAT_DONE"] = "erreicht",
})

ns.RegisterLocale("deDE", {
    ["LOADOUT_NO_IMPORT"]    = "Dieser Client erlaubt kein direktes Setzen.",
    ["LOADOUT_IN_COMBAT"]    = "Nicht im Kampf.",
})

ns.RegisterLocale("deDE", {
    ["LBL_GEARSLOT"] = "Platz",
    ["SLOT_ALL"]     = "Alle Plätze",
})

ns.RegisterLocale("deDE", {
    ["LBL_CATEGORY"] = "Anzeigen",
    ["CATEGORY_ALL"] = "Alles",
})

ns.RegisterLocale("deDE", {
    ["GROUP_ABOUT"]   = "Über",
    ["SECTION_info"]  = "Info",
    ["INFO_GROUP"]    = "Daten",
    ["INFO_NEEDS"]    = "Was dafür nötig ist",
    ["INFO_VERSION"]  = "MetaCodex-Version",
    ["INFO_CATALOG"]  = "Katalog aus den Spieldateien",
    ["INFO_AUCTIONATOR_OK"]      = "installiert",
    ["INFO_AUCTIONATOR_MISSING"] = "nicht installiert",
    ["INFO_AUCTIONATOR_GET"] = "Klick, um den Link zum Addon zu bekommen",
    ["INFO_AUCTIONATOR_WHY"]     = "Nur für die Übergabe ans Auktionshaus nötig. Alles andere läuft ohne.",
})

ns.RegisterLocale("deDE", {
    ["SLOT_meta"] = "Besonderer Sockel",
    ["ALT_ROW"]   = "Alternative",
})

ns.RegisterLocale("deDE", {
    ["ORIGIN_SET"]        = "Set-Teil — Schlachtzug oder Tresor",
    ["ORIGIN_CRAFT"]      = "Handwerk",
    ["ORIGIN_SEEN"]       = "gesehen in %s",
    ["ORIGIN_MODE_mplus"] = "Mythisch+",
    ["ORIGIN_MODE_raid"]  = "Schlachtzug",
    ["ORIGIN_MODE_2v2"]   = "PvP",
    ["ORIGIN_MODE_3v3"]   = "PvP",
    ["ORIGIN_MODE_rbg"]   = "PvP",
    ["ORIGIN_MODE_solo"]  = "PvP",
    ["ORIGIN_MODE_blitz"] = "PvP",
})

ns.RegisterLocale("deDE", {
    ["LBL_KEY"]   = "Dein Schlüsselstein",
    ["KEY_BEST"]  = "Wie die Besten spielen",
    ["KEY_ROW"]   = "+%d  ·  %d  ·  Tresor %d",
    ["KEY_SHORT"] = "+%d  ·  %d",
    ["KEY_YOURS"] = "du bekämst %d",
    ["KEY_VAULT"] = "Tresor %d",
})

ns.RegisterLocale("deDE", {
})

ns.RegisterLocale("deDE", {
    ["KEY_GROUP_RUN"]   = "Ende des Dungeons",
    ["KEY_GROUP_VAULT"] = "Große Schatzkammer",
    ["KEY_ENTRY"]       = "%d  (+%d)",
})

ns.RegisterLocale("deDE", {
    ["SOURCE_FELL_BACK"] = "%s führt dazu nichts — gezeigt wird %s.",
})

ns.RegisterLocale("deDE", {
    ["TALENT_OTHERS"] = "Weitere Builds",
    ["TALENT_SWAP"]   = "%s statt %s",
    ["TALENT_PLUS"]   = "zusätzlich %s",
    ["TALENT_MINUS"]  = "ohne %s",
})

ns.RegisterLocale("deDE", {
    ["KEY_STEP"] = "%d  (%s)",
})

ns.RegisterLocale("deDE", {
    ["PROBE_LEVEL_HEADER"] = "Gegenstandsstufe im Link:",
    ["PROBE_LEVEL_NONE"]   = "keine Ausrüstung mit Stufe in dieser Ansicht",
    ["PROBE_LEVEL_BASE"]   = "Grundstufe %s, gewollt %s",
    ["PROBE_LEVEL_DELTA"]  = "Differenz %d, Bonus-ID %s",
    ["PROBE_LEVEL_LINK"]   = "Link %s",
    ["PROBE_LEVEL_RESULT"] = "der Client liest %s, gewollt %s",
})

ns.RegisterLocale("deDE", {
    ["TEXT_TITLE"] = "Diesen Bericht kopieren",
    ["TEXT_HINT"]  = "Strg+A, Strg+C. Der Chat ist zum Lesen, nicht zum Herausholen.",
})
