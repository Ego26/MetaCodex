local _, ns = ...

ns.RegisterLocale("enUS", {
    ["TITLE"]              = "MetaCodex",
    ["SLOGAN"]             = "From real fights, not from guides.",

    -- Slots
    ["SLOT_helm"]          = "Head",
    ["SLOT_shoulders"]     = "Shoulders",
    ["SLOT_chest"]         = "Chest",
    ["SLOT_legs"]          = "Legs",
    ["SLOT_boots"]         = "Feet",
    ["SLOT_ring"]          = "Rings",
    ["SLOT_weapon"]        = "Weapon",
    ["SLOT_gems"]          = "Gems",

    -- Kennwerte
    ["STAT_crit"]          = "Critical Strike",
    ["STAT_haste"]         = "Haste",
    ["STAT_mastery"]       = "Mastery",
    ["STAT_vers"]          = "Versatility",
    ["STAT_speed"]         = "Speed",
    ["STAT_leech"]         = "Leech",
    ["STAT_avoid"]         = "Avoidance",
    ["STAT_primary"]       = "Primary stat",
    ["STAT_agi"]           = "Agility",
    ["STAT_str"]           = "Strength",
    ["STAT_int"]           = "Intellect",
    ["STAT_proc"]          = "Effect",
    ["STAT_legs"]          = "Leg armor",
    ["STAT_unknown"]       = "Unknown",

    -- Kopf
    ["LBL_MAIN_STAT"]      = "Main stat",
    ["LBL_SECOND_STAT"]    = "Second stat",
    ["LBL_TERTIARY"]       = "Tertiary",
    ["LBL_RANK"]           = "Rank",
    ["RANK_BEST"]          = "Highest",
    ["RANK_CHEAP"]         = "Cheaper",
    ["DATA_AS_OF"]         = "Catalog %s, built %s",
    ["PICK_HINT"]          = "Pick your stats - MetaCodex does the rest.",

    -- Zeilen
    ["ALREADY_DONE"]       = "already applied",
    ["OWNED"]              = "%d in bags",
    ["OWNED_HIGHER"] = "%d owned in higher quality",
    ["OWNED_LOWER"] = "%d owned in lower quality",
    ["GEAR_WORN"] = "equipped",
    ["CHARBTN_CLICK"] = "Click to open or close MetaCodex",
    ["MINIMAP_CLICK"] = "Click to open or close MetaCodex  ·  right-click for settings",
    ["MINIMAP_DRAG"] = "Drag to move it around the minimap",
    ["SET_GROUP_OPEN"] = "Where to open it",
    ["SET_GROUP_WINDOW"] = "Window",
    ["SET_MINIMAP"] = "Minimap button",
    ["SET_CHARBTN"] = "Button on the character frame",
    ["SET_SCALE"] = "Text size",
    ["SET_LANG"] = "Language",
    ["SET_LANG_AUTO"] = "Follows the client",
    ["SET_LANG_EN"] = "English",
    ["SET_LANG_DE"] = "Deutsch",
    ["SET_LANG_RELOAD"] = "Labels already on screen change after /reload.",
    ["SET_HINT"] = "The reminder has its own settings, next to what they control.",
    ["SET_GROUP_START"] = "When it opens",
    ["SET_RESET"] = "Window position and size",
    ["SET_RESET_DO"] = "reset",
    ["SET_START"] = "Start on",
    ["SET_START_LAST"] = "Whatever was open last",
    ["CHARBTN_MOVE"] = "Shift-drag to move  ·  Shift-right-click to reset",
    ["REMIND_LOWER"] = "%s (only lower quality: %d)",
    ["NEED"]               = "need %d",
    ["EMPTY_SOCKETS"]      = "%d empty sockets",
    ["NO_EMPTY_SOCKETS"]   = "No empty sockets on your gear.",
    ["CHOOSE"]             = "choose",
    ["STRONG"]             = "strong",
    ["CHEAP"]              = "budget",

    -- Knoepfe
    ["BTN_CREATE_LIST"]    = "Create shopping list",
    ["BTN_SEARCH"]         = "Search now",
    ["BTN_ONLY_MISSING"]   = "Only what I'm missing",
    ["BTN_REFRESH"]        = "Rescan gear",

    -- Meldungen
    ["NO_AUCTIONATOR"]     = "Auctionator is not loaded - the list is shown, but cannot be handed over.",
    ["LIST_CREATED"]       = "%d entries written to the list \"%s\".",
    ["LIST_FAILED"]        = "Auctionator refused the list: %s",
    ["NOTHING_TO_BUY"]     = "Nothing to buy - everything is enchanted and socketed.",
    ["NAMES_PENDING"]      = "Loading item names, one moment...",
    ["NO_CATALOG"]         = "Data/Catalog.lua is missing or empty. Run tools/build-catalog.js.",

    -- Slash
    ["SLASH_HELP"]         = "Commands:",
    ["SLASH_OPEN"]         = "/mc - open the window",
    ["SLASH_PROBE"]        = "/mc probe - check what this client and Auctionator actually offer",
    ["SLASH_LANG"]         = "/mc lang de|en|auto - language of the interface",
    ["SLASH_SCALE"]        = "/mc scale 0.6-1.6 - text size in the window (1 = normal)",
    ["SCALE_SET"]          = "Text size: %s",
    ["SLASH_RESET"]        = "/mc reset - forget saved choices",
    ["RESET_DONE"]         = "Saved choices cleared.",
    ["LANG_SET"]           = "Language: %s",

    -- Probe
    ["PROBE_HEADER"]       = "Probe (%s, catalog %s):",
    ["PROBE_YES"]          = "|cff40d070yes|r",
    ["PROBE_NO"]           = "|cffd04040no|r",
    ["PROBE_AUCTIONATOR"]  = "Auctionator loaded",
    ["PROBE_API"]          = "Auctionator.API.v1.CreateShoppingList",
    ["PROBE_SEARCH"]       = "Auctionator.API.v1.MultiSearchExact",
    ["PROBE_CONVERT"]      = "Auctionator.API.v1.ConvertToSearchString (quantity in the list)",
    ["PROBE_NAMES"]        = "Item names resolved: %d of %d",
    ["PROBE_UNRESOLVED"]   = "Unresolved IDs: %s",
    ["PROBE_PRIMARY"]      = "Primary stat detected: %s",
    ["PROBE_SOCKETS"]      = "Empty sockets on equipped gear: %d",
})

-- Kurzformen fuer die Knopfleisten. Die langen Namen passen dort nicht.
ns.RegisterLocale("enUS", {
    ["STATSHORT_crit"]    = "Crit",
    ["STATSHORT_haste"]   = "Haste",
    ["STATSHORT_mastery"] = "Mastery",
    ["STATSHORT_vers"]    = "Vers",
    ["STATSHORT_speed"]   = "Speed",
    ["STATSHORT_leech"]   = "Leech",
    ["STATSHORT_avoid"]   = "Avoid",
    ["OPT_CHEAP"]         = "Cheaper rank",
    ["OPT_ONLY_MISSING"]  = "Only what is missing",
    ["PICK_WEAPON"]       = "Pick a weapon enchant",
    ["PICK_LEGS"]         = "Pick leg armor",
    ["PICK_TERTIARY"]     = "Pick a tertiary stat above",
    ["SLOT_COUNT"]        = "%d slot(s)",
})

-- Auswahl der Spezialisierung, dazugekommen mit dem Waehler im Kopf.
ns.RegisterLocale("enUS", {
    ["LBL_SPEC"]        = "Specialisation",
    ["SPEC_ACTIVE"]     = "Active specialisation",
    ["FOREIGN_CLASS"]   = "Another class: MetaCodex cannot read that character's gear, so it lists the full set instead of what is missing.",
    ["SHOW_ALL_HINT"]   = "Untick \"only what is missing\" to see the full set.",
    ["PROBE_SPEC"]      = "Specialisation shown: %s (%s)",
    ["PROBE_STAT_API"]  = "from the client",
    ["PROBE_STAT_CHAR"] = "from your character",
})

ns.RegisterLocale("enUS", {
    ["SOCKETS"] = "%d sockets, %d empty",
    ["IN_BAGS"] = "already in your bags",
})

ns.RegisterLocale("enUS", {
    ["SOURCE_LINE"]  = "Recommendations: %s, %s",
    ["NO_MODE_DATA"] = "No data for this game mode yet - pick the stats yourself below.",
})

-- Neues Fenster: Abschnitte der Seitenleiste und Kopfzeile.
ns.RegisterLocale("enUS", {
    ["GROUP_SHOPPING"]     = "Shopping",
    ["GROUP_PREP"]         = "Preparation",
    ["SECTION_all"]        = "Everything",
    ["SECTION_enchants"]   = "Enchants",
    ["SECTION_gems"]       = "Gems",
    ["SECTION_consumables"]= "Consumables",
    ["SECTION_remind"]     = "Reminder",
    ["SECTION_gear"]       = "Gear",
    ["SECTION_talents"]    = "Talents",
    ["SOON_CONSUMABLES"]   = "Not collected yet. Flasks, potions, food and runes are recorded in the same logs the enchant data comes from - they just are not read out yet.",
    ["SOON_GEAR"]          = "Not collected yet. The reports already carry the item per slot; what is missing is the evaluation, not the data.",
    ["SOON_TALENTS"]       = "Not collected yet. Talent loadouts are in the logs, per dungeon and per boss.",
    ["LBL_ACTIVITY"]       = "Activity",
    ["NO_DATA_SUFFIX"]     = "(no data)",
    ["COUNT_MISSING"]      = "%d to buy",
})

-- Plattformwahl und die neue Themenliste.
ns.RegisterLocale("enUS", {
    ["GROUP_KNOW"]         = "Knowledge",
    ["GROUP_GEAR"]         = "Gear",
    ["SECTION_settings"]   = "Settings",
    ["SECTION_guides"]     = "Guides & Rotation",
    ["SECTION_stats"]      = "Stat targets",
    ["SECTION_players"]    = "Top players",
    ["SECTION_folio"]      = "Omnium Folio",
    ["FOLIO_ROW"]          = "Row %d",
    ["FOLIO_HINT"]         = "Which runes the best carried at the pull — one choice per row.",
    ["LBL_HERO"]           = "Hero talents",
    ["HERO_ALL"]           = "All hero trees",
    ["HERO_ENTRY"]         = "%s · %d %%",
    ["SECTION_enchants"]   = "Enchants & Gems",
    ["LBL_SOURCE"]         = "Platform",
    ["SOURCE_ALL"]         = "All platforms",
    ["SOON_GUIDES"]        = "Not built yet. Rotations are written text, not measurable - they would come from Wowhead or Method.gg with attribution, and that is a different kind of data than everything else here.",
    ["SOON_STATS"]         = "Not built yet. The stat targets follow from the same gear the enchant data comes from - what is missing is the evaluation.",
})

ns.RegisterLocale("enUS", {
    ["GEARSLOT_Head"]     = "Head",
    ["GEARSLOT_Neck"]     = "Neck",
    ["GEARSLOT_Shoulders"]= "Shoulders",
    ["GEARSLOT_Back"]     = "Back",
    ["GEARSLOT_Chest"]    = "Chest",
    ["GEARSLOT_Wrist"]    = "Wrist",
    ["GEARSLOT_Hands"]    = "Hands",
    ["GEARSLOT_Waist"]    = "Waist",
    ["GEARSLOT_Legs"]     = "Legs",
    ["GEARSLOT_Feet"]     = "Feet",
    ["GEARSLOT_Rings"]    = "Rings",
    ["GEARSLOT_Trinkets"] = "Trinkets",
    ["GEARSLOT_MainHand"] = "Main Hand",
    ["GEARSLOT_OffHand"]  = "Off Hand",
})

ns.RegisterLocale("enUS", {
    ["PROBE_STAT_FALLBACK"] = "fallback - the client did not say",
})

ns.RegisterLocale("enUS", {
    ["LBL_LEVEL"] = "Minimum item level",
    ["LEVEL_ALL"] = "Any item level",
    ["LEVEL_MIN"] = "Item level %d+",
})

ns.RegisterLocale("enUS", { ["BADGE_SET"] = "Tier set", ["BADGE_CRAFT"] = "Crafted" })

ns.RegisterLocale("enUS", { ["ILVL"] = "Item level %d" })

ns.RegisterLocale("enUS", {
    -- Consumables. The group headings are the item classes the game
    -- itself uses, not names anyone made up.
    ["CONSUM_flask"]   = "Flasks",
    ["CONSUM_potion"]  = "Combat potions",
    ["CONSUM_food"]    = "Food",
    ["CONSUM_vantus"]  = "Vantus Runes",
    ["CONSUM_oil"]     = "Weapon buffs (oils, stones)",
    ["CONSUM_other"]   = "Runes & other",
    ["CONSUM_TARGET_MENU"] = "How many I want",
    ["CONSUM_USE_THIS"] = "I use this one",
    ["CONSUM_FROM_BAGS"] = "Pick from my bags",
    ["CONSUM_USE_MEASURED"] = "Back to what the best use",
    ["CONSUM_MINE"] = "your pick",
    ["CONSUM_TARGET"]  = "target %d",
    ["REMIND_TITLE"]   = "MetaCodex reminder",
    ["REMIND_MISSING"] = "Missing before you start: %s",
    ["REMIND_OK"]      = "Flask, food and runes are in your bags.",
    ["REMIND_NONE"]    = "%s: none in bags",
    ["REMIND_LOW"]     = "%s: only %d left",
    ["LBL_REMINDERS"]  = "Remind me",
    ["REMIND_HINT"]    = "What the reminder checks before you go in. Click a line to change its target; buy what is missing below.",
    ["REMIND_GROUP_STATUS"]   = "Right now",
    ["REMIND_GROUP_SETTINGS"] = "Settings",
    ["REMIND_HAVE"]    = "%d of %d",
    ["REMIND_STATE_OK"]   = "enough",
    ["REMIND_STATE_LOW"]  = "low",
    ["REMIND_STATE_NONE"] = "none",
    ["REMIND_OPT_ON"]  = "Reminders",
    ["REMIND_OPT_ENTER"] = "Remind on entering a dungeon or raid",
    ["REMIND_GROUP_WAYS"] = "How it tells you",
    ["REMIND_WAY_CHAT"] = "Chat line",
    ["REMIND_WAY_WINDOW"] = "Its own window",
    ["REMIND_WAY_WARNING"] = "Raid warning across the screen",
    ["REMIND_WAY_SOUND"] = "Sound",
    ["REMIND_OPEN_LIST"] = "Open in MetaCodex",
    ["REMIND_PREVIEW"] = "Show me what it looks like",
    ["REMIND_PREVIEW_DO"] = "preview",
    ["REMIND_PREVIEW_EMPTY"] = "Nothing missing - this is what a reminder would look like.",
    ["REMIND_STATE_NONE"] = "nothing in your bags",
    ["REMIND_STATE_LOW"] = "%d of %d",
    ["REMIND_STATE_LOWER"] = "%d in lower quality",
    ["REMIND_WINDOW_TITLE"] = "Before you go in",
    ["REMIND_OPT_AH"]  = "Remind at the auction house",
    ["REMIND_OPT_BELOW"] = "Counts as low when below this share of the target",
    ["REMIND_GROUP_ENCHANTS"] = "Enchants & gems still missing",
    ["REMIND_ENCHANTS_OK"] = "Everything enchanted and socketed",
    ["REMIND_ENCHANTS"] = "%d enchants or gems open",
    ["OPTION_CLICK"]   = "click to toggle",
    ["OPTION_PICK"]    = "click to choose",
    ["OPTION_ON"]      = "On",
    ["OPTION_OFF"]     = "Off",
})

ns.RegisterLocale("enUS", {
    ["SLASH_REMIND"] = "/mc remind - warn me about missing consumables when I enter a dungeon or raid",
    ["REMIND_ON"]    = "Reminder on.",
    ["REMIND_OFF"]   = "Reminder off.",
})

ns.RegisterLocale("enUS", {
    ["LBL_DUNGEON"] = "Dungeon",
    ["DUNGEON_ALL"] = "All dungeons",
    ["LBL_BOSS"]    = "Boss",
    ["BOSS_ALL"]    = "All bosses",
    -- The key range travels with the data instead of being a word. "High
    -- keys" means something different at every site; a number does not.
    ["KEY_RANGE"]   = "+%d to +%d",
    ["KEY_HIGH"]    = "High keys",
})

ns.RegisterLocale("enUS", {
    -- Two groups, because they answer two different questions.
    ["TALENT_BUILD"] = "Most common build  ·  %d%% run exactly this",
    ["LOADOUT_FROM_BASE"] = "string from all of M+",
    ["LOADOUT_FROM_SOURCE"] = "string from %s",
    ["TALENT_PICKS"] = "Single talents and how many take them",
    ["TALENT_PICKS_HINT"] = "Share of the top players who have this talent. Hover for what it does.",
    ["TALENT_SHARE"] = "%d%% of the best take it",
    ["TALENT_RANK"]  = "Rank %d",
})

ns.RegisterLocale("enUS", {
})

ns.RegisterLocale("enUS", {
    -- Guides are the one section that measures nothing. It names other
    -- people's work instead of showing it, which is the only clean way:
    -- the text on a guide site belongs to that site.
    ["GUIDE_GROUP"]       = "Written guides",
    ["GUIDE_COPY"]        = "click to copy the address",
    ["PLAYER_COPY"]       = "click to open the profile",
    ["PLAYER_HINT"]       = "Who is currently at the top on this specialisation. Click a line to open their profile: talent string, gear, address.",
    ["PLAYER_RANK"]       = "rank %d",
    ["ORIGIN_CONQUEST"]   = "Conquest vendor",
    ["ORIGIN_HONOR"]      = "Honor vendor",
    ["ORIGIN_PVPCRAFT"]   = "crafted (PvP)",
    ["ORIGIN_NONE"]       = "not an instance drop",
    ["ORIGIN_WORLD"]      = "world, quest or vendor",
    ["LBL_ORIGIN"]        = "Source",
    ["SOURCE_ANY"]        = "Any source",
    ["KEY_STEP_UPGRADE"]  = "%d  (upgrade)",
    ["KEY_STEP_VAULT"]    = "%d  (vault %s)",
    ["KEY_LABEL"]         = "%s %d · %d",
    ["PLAYER_ENCHANT"] = "Enchant on this piece",
    ["PLAYER_GEM"] = "Gem in this piece",
    ["PLAYER_BACK"]       = "Back to top players",
    ["PLAYER_VIEW_HINT"]  = "What this player wears and runs right now, per raider.io. Tooltips show each piece exactly as worn.",
    ["PLAYER_LOADOUT"]    = "Copy this player's talent string",
    ["PLAYER_VERIFIED"]   = "verified: talents match the activity",
    ["PLAYER_UNVERIFIED"] = "unverified: may be their build for another activity",
    ["PLAYER_PROFILE"]    = "Profile in the browser",
    ["PLAYER_ILVL"]       = "item level %d",
    ["PLAYER_NO_PROFILE"] = "No profile on file for this player",
    ["PLAYER_LOADING"]    = "Loading profiles …",
    ["TRACK_970"]         = "Explorer",
    ["TALENT_PVP"]        = "PvP talents",
    ["TRACK_971"]         = "Adventurer",
    ["TRACK_972"]         = "Veteran",
    ["TRACK_973"]         = "Champion",
    ["TRACK_974"]         = "Hero",
    ["TRACK_978"]         = "Myth",
    ["KEY_STEP_TRACK"]    = "%d · %s (%s %d)",
    ["LOADOUT_NO_STRING"] = "No source ships a ready-made string for this activity — the talents below still hold",
    ["NO_PLAYERS"]        = "No source ranks players for this activity.",
    ["GUIDE_BY"]          = "by %s — opens in your browser",
    ["GUIDE_WOWHEAD"]     = "Rotation, cooldowns and abilities",
    ["GUIDE_WOWHEAD_BIS"] = "Best in slot, explained",
    ["GUIDE_METHOD"]      = "Method guide",
    ["GUIDE_ARCHON_GEMS"]   = "Archon: enchants and gems",
    ["GUIDE_ARCHON_CONSUM"] = "Archon: consumables",
    ["GUIDE_MURLOK"]      = "Murlok.io: your spec’s page",
    ["GUIDE_HINT"]        = "MetaCodex measures; these sites explain. Click a line to copy its address.",
    ["LINK_TITLE"]        = "Copy this address",
    ["LINK_HINT"]         = "Ctrl+C to copy. An addon cannot open a browser itself.",
    ["LINK_CLOSE"]        = "Close",
})

ns.RegisterLocale("enUS", {
    -- One line, not an opening window. Someone at the auction house is
    -- usually there for something else.
    ["AH_OFFER"] = "%d things still missing. |cff4c8dff/mc|r opens the list.",
})

ns.RegisterLocale("enUS", {
    -- "Empty" almost never means "not built yet" any more. It means this
    -- platform does not measure this, or measures it and has not seen
    -- this spec often enough.
    ["NO_SOURCE_SECTION"] = "%s has nothing here for this activity. Try another platform, or all of them.",
    ["NO_SPEC_SECTION"]   = "No platform has enough runs of this spec in this activity yet.",
})

ns.RegisterLocale("enUS", {
    -- Auctionator's own error for this reads "Contact the maintainer of
    -- MetaCodex", which the player rightly reads as our fault. It is:
    -- we asked without looking.
    ["AH_CLOSED"] = "Open the auction house first — the search runs inside it. The shopping list can be created anywhere.",
})

ns.RegisterLocale("enUS", {
    -- The highest key it was still seen at. Answers what a percentage
    -- cannot: whether something holds up at the top or is merely common.
    ["MAX_KEY"] = "up to +%d",
})

ns.RegisterLocale("enUS", {
    -- Potions split the way Archon splits them, and the way they are
    -- actually used: one belongs in the rotation, one in an emergency.
    ["CONSUM_heal"] = "Health potions",
})

ns.RegisterLocale("enUS", {
    ["NO_DUNGEON_DATA"] = "The per-dungeon data is a separate addon (MetaCodex_Dungeons) and is not installed.",
})

ns.RegisterLocale("enUS", {
    -- The window shows one spec; the list may cover several. Saying so
    -- matters: otherwise someone presses the button and gets more than
    -- they can see.
    ["SPEC_ALSO_BUY"] = "Also buy for…",
    ["COUNT_SPECS"]   = "list covers %d specs",
})

ns.RegisterLocale("enUS", {
    -- A build is not a list of names — nobody types one in. What is
    -- wanted is the import string: one click, paste, done.
    ["LOADOUT_TITLE"]      = "Copy this build",
    ["LOADOUT_HINT"]       = "%d talents · paste into the talent window's import box",
    ["LOADOUT_DIFF_HINT"]  = "%d talents differ · paste into the talent window's import box",
})


ns.RegisterLocale("enUS", {
    -- What is missing belongs on the right, where the eye lands.
    -- The rank sat there and was the smaller answer: the order already
    -- shows it.
    ["STAT_SHARE"] = "%d%% of the budget",
    ["STAT_YOURS"] = "you have %d of %d",
    ["STAT_GAP"] = "−%d",
    ["STAT_DONE"] = "reached",
})

ns.RegisterLocale("enUS", {
    -- The test harness outside the game cannot confirm this format — it
    -- is my own rebuild of it. Only the client knows whether the encoder
    -- agrees with Blizzard.
    ["LOADOUT_NO_IMPORT"]    = "This client does not allow applying a loadout.",
    ["LOADOUT_IN_COMBAT"]    = "Not in combat.",
})

ns.RegisterLocale("enUS", {
    ["LBL_GEARSLOT"] = "Slot",
    ["SLOT_ALL"]     = "All slots",
})

ns.RegisterLocale("enUS", {
    ["LBL_CATEGORY"] = "Show",
    ["CATEGORY_ALL"] = "Everything",
})

ns.RegisterLocale("enUS", {
    ["GROUP_ABOUT"]   = "About",
    ["SECTION_info"]  = "Info",
    ["INFO_GROUP"]    = "Data",
    ["INFO_NEEDS"]    = "What this needs",
    ["INFO_VERSION"]  = "MetaCodex version",
    ["INFO_CATALOG"]  = "Catalog from the game files",
    ["INFO_AUCTIONATOR_OK"]      = "installed",
    ["INFO_AUCTIONATOR_MISSING"] = "not installed",
    -- The one line that was nowhere before: the handover needs it.
    ["INFO_AUCTIONATOR_GET"] = "Click to get the link to the addon",
    ["INFO_AUCTIONATOR_WHY"]     = "Needed only to hand the list to the auction house. Everything else works without it.",
})

ns.RegisterLocale("enUS", {
    ["SLOT_meta"] = "Special socket",
    -- An alternative carries no count: you buy one of them, not all.
    ["ALT_ROW"]   = "alternative",
})

ns.RegisterLocale("enUS", {
    -- Where an item comes from, in descending certainty. The last one is
    -- deliberately not a claim about the drop: world, vendor and delve
    -- loot are in no table we can read.
    ["ORIGIN_SET"]        = "Tier set — raid or vault",
    ["ORIGIN_CRAFT"]      = "Crafted",
    ["ORIGIN_SEEN"]       = "seen in %s",
    ["ORIGIN_MODE_mplus"] = "Mythic+",
    ["ORIGIN_MODE_raid"]  = "raid",
    ["ORIGIN_MODE_2v2"]   = "PvP",
    ["ORIGIN_MODE_3v3"]   = "PvP",
    ["ORIGIN_MODE_rbg"]   = "PvP",
    ["ORIGIN_MODE_solo"]  = "PvP",
    ["ORIGIN_MODE_blitz"] = "PvP",
})

ns.RegisterLocale("enUS", {
    -- Not a filter. The question is not "hide what is below", but "what
    -- do I get" — somebody running +10 cannot tell from a list of 334s
    -- that it becomes 311 for them.
    ["LBL_KEY"]   = "Your keystone",
    ["KEY_BEST"]  = "As the best run it",
    ["KEY_ROW"]   = "+%d  ·  %d  ·  vault %d",
    ["KEY_SHORT"] = "+%d  ·  %d",
    ["KEY_YOURS"] = "you would get %d",
    ["KEY_VAULT"] = "vault %d",
})

ns.RegisterLocale("enUS", {
})

ns.RegisterLocale("enUS", {
    ["KEY_GROUP_RUN"]   = "End of dungeon",
    ["KEY_GROUP_VAULT"] = "Great Vault",
    ["KEY_ENTRY"]       = "%d  (+%d)",
})

ns.RegisterLocale("enUS", {
    -- Quietly showing the right thing is good. Quietly showing something
    -- other than what the button says is not.
    ["SOURCE_FELL_BACK"] = "%s has nothing here — showing %s instead.",
})

ns.RegisterLocale("enUS", {
    -- "20% run exactly this" also means 80% do not. What the others
    -- change is the question behind every talent comparison.
    ["TALENT_OTHERS"] = "Other builds",
    ["TALENT_SWAP"]   = "%s instead of %s",
    ["TALENT_PLUS"]   = "additionally %s",
    ["TALENT_MINUS"]  = "without %s",
})

ns.RegisterLocale("enUS", {
    ["KEY_STEP"] = "%d  (%s)",
})

ns.RegisterLocale("enUS", {
    ["PROBE_LEVEL_HEADER"] = "Item level in the link:",
    ["PROBE_LEVEL_NONE"]   = "no gear with a level in this view",
    ["PROBE_LEVEL_BASE"]   = "base %s, wanted %s",
    ["PROBE_LEVEL_DELTA"]  = "delta %d, bonus id %s",
    ["PROBE_LEVEL_LINK"]   = "link %s",
    ["PROBE_LEVEL_RESULT"] = "the client reads %s, wanted %s",
})

ns.RegisterLocale("enUS", {
    ["TEXT_TITLE"] = "Copy this report",
    ["TEXT_HINT"]  = "Ctrl+A, Ctrl+C. The chat is for reading, not for getting text out of.",
})
