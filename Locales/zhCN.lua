local _, ns = ...

ns.RegisterLocale("zhCN", {
	["TITLE"]              = "MetaCodex",
	["SLOGAN"]             = "来自真实战斗，而非攻略。",

	-- Slots
	["SLOT_helm"]          = "头部",
	["SLOT_shoulders"]     = "肩部",
	["SLOT_chest"]         = "胸部",
	["SLOT_legs"]          = "腿部",
	["SLOT_boots"]         = "脚部",
	["SLOT_ring"]          = "戒指",
	["SLOT_weapon"]        = "武器",
	["SLOT_gems"]          = "宝石",

	-- Kennwerte
	["CARD_TARGET"] = "最常见搭配",
	["TIP_TOP"]     = "该部位穿着率最高（%d%%）",
	["TIP_RANK"]    = "该部位第 %d 名，共 %d 个（%d%%）",
	["SET_TOOLTIP"] = "添加到物品提示",
	["SET_TOOLTIP_HINT"] = "显示每条副属性的排名，以及该物品在部位中的位置",
	["STAT_crit"]          = "爆击",
	["STAT_haste"]         = "急速",
	["STAT_mastery"]       = "精通",
	["STAT_vers"]          = "全能",
	["STAT_SHORT_crit"]    = "爆击",
	["STAT_SHORT_haste"]   = "急速",
	["STAT_SHORT_mastery"] = "精通",
	["STAT_SHORT_vers"]    = "全能",
	["STAT_speed"]         = "加速",
	["STAT_leech"]         = "吸血",
	["STAT_avoid"]         = "闪避",
	["STAT_primary"]       = "主属性",
	["STAT_agi"]           = "敏捷",
	["STAT_str"]           = "力量",
	["STAT_int"]           = "智力",
	["STAT_proc"]          = "效果",
	["STAT_legs"]          = "腿部护甲",
	["STAT_unknown"]       = "未知",

	-- Kopf
	["LBL_MAIN_STAT"]      = "主属性",
	["LBL_SECOND_STAT"]    = "副属性",
	["LBL_TERTIARY"]       = "第三属性",
	["LBL_RANK"]           = "排名",
	["RANK_BEST"]          = "最高",
	["RANK_CHEAP"]         = "更便宜",
	["DATA_AS_OF"]         = "目录 %s，构建于 %s",
	["PICK_HINT"]          = "选择你的属性——剩下的交给 MetaCodex。",

	-- Zeilen
	["ALREADY_DONE"]       = "已应用",
	["OTHER_ENCHANT"]      = "已附魔其他：%s",
	["RUNEFORGE_NOTE"]     = "符文熔炉，无需购买",
	["RUNEFORGE_PICK"]     = "为武器符文熔炉",
	["OWNED"]              = "背包中 %d 个",
	["OWNED_HIGHER"] = "拥有 %d 个更高品质",
	["OWNED_LOWER"] = "拥有 %d 个更低品质",
	["GEAR_WORN"] = "已装备",
	["GEAR_MORE"] = "另有 %d 件",
	["GEAR_LESS"] = "更少",
	["CHARBTN_CLICK"] = "点击打开或关闭 MetaCodex",
	["MINIMAP_CLICK"] = "点击打开或关闭 MetaCodex  ·  右键设置",
	["MINIMAP_DRAG"] = "拖动以移动小地图按钮",
	["SET_GROUP_OPEN"] = "打开位置",
	["SET_GROUP_WINDOW"] = "窗口",
	["SET_MINIMAP"] = "小地图按钮",
	["SET_CHARBTN"] = "角色界面按钮",
	["SET_TALENTBTN"] = "天赋界面建造按钮",
	["SET_SCALE"] = "文字大小",
	["SET_LANG"] = "语言",
	["SET_LANG_AUTO"] = "跟随客户端",
	["SET_LANG_EN"] = "English",
	["SET_LANG_DE"] = "Deutsch",
	["SET_LANG_RELOAD"] = "屏幕上已有的文字会在 /reload 后改变。",
	["SET_HINT"] = "提醒有自己的设置，就在它所控制的内容旁边。",
	["SET_GROUP_START"] = "打开时",
	["SET_RESET"] = "窗口位置和大小",
	["SET_RESET_DO"] = "重置",
	["SET_START"] = "启动时显示",
	["SET_START_LAST"] = "上次打开的内容",
	["CHARBTN_MOVE"] = "Shift-拖动移动  ·  Shift-右键重置",
	["NEED"]               = "需要 %d",
	["EMPTY_SOCKETS"]      = "%d 个空插槽",
	["NO_EMPTY_SOCKETS"]   = "你的装备上没有空插槽。",
	["CHOOSE"]             = "选择",
	["STRONG"]             = "强力",
	["CHEAP"]              = "经济",

	-- Knoepfe
	["BTN_CREATE_LIST"]    = "创建购物清单",
	["BTN_SEARCH"]         = "立即搜索",
	["HINT_CREATE_LIST"] = "将缺少的物品写入 Auctionator 购物清单。拍卖行关闭时也可使用。",
	["HINT_SEARCH"] = "一次性在拍卖行搜索所有缺少的物品。",
	["HINT_SEARCH_CLOSED"] = "需要先打开拍卖行。",
	["BTN_ONLY_MISSING"]   = "仅显示缺少的",
	["BTN_REFRESH"]        = "重新扫描装备",

	-- Meldungen
	["NO_AUCTIONATOR"]     = "Auctionator 未加载——清单已显示，但无法移交。",
	["LIST_TEMPORARY"] = "本次使用——关闭拍卖行后移除。",
	["LIST_STAYS"] = "你的 Auctionator 无法删除清单，因此该清单会保留——名称不变，下次会被替换。",
	["LIST_DROPPED"] = "已移除购物清单：%s",
	["LIST_CREATED"]       = "已写入 %d 条到清单“%s”。",
	["LIST_FAILED"]        = "Auctionator 拒绝了清单：%s",
	["NOTHING_TO_BUY"]     = "没有需要购买的——所有附魔和插槽都已处理。",
	["NAMES_PENDING"]      = "正在加载物品名称，请稍候……",
	["NO_CATALOG"]         = "Data/Catalog.lua 缺失或为空。请运行 tools/build-catalog.js。",

	-- Slash
	["SLASH_HELP"]         = "命令：",
	["SLASH_OPEN"]         = "/mc - 打开窗口",
	["SLASH_PROBE"]        = "/mc probe - 检查当前客户端和 Auctionator 实际提供的内容",
	["SLASH_LANG"]         = "/mc lang de|en|auto - 界面语言",
	["SLASH_SCALE"]        = "/mc scale 0.6-1.6 - 窗口文字大小（1 = 正常）",
	["SCALE_SET"]          = "文字大小：%s",
	["SLASH_RESET"]        = "/mc reset - 清除已保存的选择",
	["RESET_DONE"]         = "已清除保存的选择。",
	["LANG_SET"]           = "语言：%s",

	-- Probe
	["PROBE_HEADER"]       = "Probe（%s，目录 %s）：",
	["PROBE_YES"]          = "|cff40d070是|r",
	["PROBE_NO"]           = "|cffd04040否|r",
	["PROBE_AUCTIONATOR"]  = "Auctionator 已加载",
	["PROBE_API"]          = "Auctionator.API.v1.CreateShoppingList",
	["PROBE_SEARCH"]       = "Auctionator.API.v1.MultiSearchExact",
	["PROBE_CONVERT"]      = "Auctionator.API.v1.ConvertToSearchString（清单中的数量）",
	["PROBE_NAMES"]        = "已解析物品名称：%d / %d",
	["PROBE_UNRESOLVED"]   = "未解析的 ID：%s",
	["PROBE_PRIMARY"]      = "检测到的主属性：%s",
	["PROBE_AGAIN"] = "刚刚请求了名称。请稍后再运行一次 /mc probe。",
	["PROBE_MEMORY"] = "收集后内存：%.1f MB（%s，单位 MB）",
	["PROBE_BAGS"] = "客户端已知背包：%s",
	["PROBE_STOCK"] = "统计背包、银行和战团银行：",
	["PROBE_SOCKETS"]      = "已装备物品上的空插槽：%d",
})

-- Kurzformen fuer die Knopfleisten. Die langen Namen passen dort nicht.
ns.RegisterLocale("zhCN", {
	["STATSHORT_crit"]    = "爆击",
	["STATSHORT_haste"]   = "急速",
	["STATSHORT_mastery"] = "精通",
	["STATSHORT_vers"]    = "全能",
	["STATSHORT_speed"]   = "加速",
	["STATSHORT_leech"]   = "吸血",
	["STATSHORT_avoid"]   = "闪避",
	["OPT_CHEAP"]         = "更便宜的排名",
	["OPT_ONLY_MISSING"]  = "仅缺少的",
	["PICK_WEAPON"]       = "选择武器附魔",
	["PICK_LEGS"]         = "选择腿部护甲",
	["PICK_TERTIARY"]     = "在上方选择第三属性",
	["SLOT_COUNT"]        = "%d 个部位",
	["SLOT_COUNT_ONE"]    = "1 个部位",
})

-- Auswahl der Spezialisierung, dazugekommen mit dem Waehler im Kopf.
ns.RegisterLocale("zhCN", {
	["LBL_SPEC"]        = "专精",
	["SPEC_ACTIVE"]     = "当前专精",
	["FOREIGN_CLASS"]   = "其他职业：MetaCodex 无法读取该角色的装备，因此会列出完整套装而不是缺少的部分。",
	["SHOW_ALL_HINT"]   = "取消勾选“仅缺少的”以查看完整套装。",
	["PROBE_SPEC"]      = "显示的专精：%s（%s）",
	["PROBE_STAT_API"]  = "来自客户端",
	["PROBE_STAT_CATALOG"] = "来自游戏数据表",
	["PROBE_STAT_CHAR"] = "来自你的角色",
})

ns.RegisterLocale("zhCN", {
	["SOCKET_COUNT"] = "%d 个插槽",
	["SOCKET_COUNT_ONE"] = "1 个插槽",
	["SOCKETS"] = "%s，%d 个空",
	["SOCKETS_OTHER"] = "%s · %d 个使用了不同宝石",
	["SOCKETS_BOTH"] = "%s · %d 个空 · %d 个使用了不同宝石",
	["IN_BAGS"] = "已在背包中",
})

ns.RegisterLocale("zhCN", {
	["CREDIT"] = "作者：Ego26",
	["SOURCE_LINE"]  = "推荐来源：%s，%s",
	["SOURCE_SAMPLE"] = "· %d 次统计",
	["SHARE_GEAR"]   = "百分比 = 穿着该物品的统计玩家占比。",
	["SET_BONUS_FOR"] = "%s 的套装效果",
	["SET_BONUS_PIECES"] = "套装（%d）：%s",
	["SET_BONUS_PLAYED"] = "上方显示的是 %s 的效果——你正在使用的专精。",
	["SHARE_TALENTS"] = "百分比 = 使用该天赋的统计玩家占比。每个字符串都来自真实玩家的客户端。",
	["SHARE_CONSUM"] = "百分比 = 统计玩家占比。",
	["SHARE_ENCHANTS"] = "百分比：附魔为该部位中出现过的占比；宝石为所有佩戴宝石中的占比。",
	["SOURCE_KEYS"]  = "来自 +%d 至 +%d 的战斗记录",
	["NO_MODE_DATA"] = "此游戏模式暂无数据——请在下方自行选择属性。",
})

-- Neues Fenster: Abschnitte der Seitenleiste und Kopfzeile.
ns.RegisterLocale("zhCN", {
	["GROUP_SHOPPING"]     = "购物",
	["GROUP_PREP"]         = "进本前",
	["SECTION_all"]        = "全部",
	["LBL_CRAFTLEVEL"]     = "物品等级",
	["CRAFTLEVEL_BEST"]    = "统计到的最高",
	["LBL_CRAFTSTATS"]      = "属性",
	["CRAFTSTATS_MEASURED"] = "按统计",
	["CRAFTSTATS_SHARE"]    = "（%d%%）",
	["SECTION_embellish"]  = "美化",
	["EMBELLISH_TWICE"] = "%s  x2",
	["EMBELLISH_ONE"]      = "一个美化",
	["EMBELLISH_TWO"]      = "两个美化",
	["EMBELLISH_HINT"]     = "可以佩戴两个。百分比 = 使用完全相同组合的统计玩家占比。",
	["SECTION_tier"]       = "套装",
	["SECTION_crafted"]    = "制造与美化",
	["SECTION_enchants"]   = "附魔与宝石",
	["SECTION_gems"]       = "宝石",
	["SECTION_consumables"]= "消耗品",
	["SECTION_remind"]     = "提醒",
	["SECTION_gear"]       = "热门",
	["SECTION_talents"]    = "天赋",
	["SECTION_folio"]      = "万奥宝典",
	["SECTION_drops"]      = "来源",
	["DROPS_HINT"]         = "你专精的顶尖玩家所穿装备，按掉落地点排序。你已经穿着的框会打勾。",
	["DROPS_OPEN"]         = "%d / %d 仍开放",
	["DROPS_ALL_WORN"]     = "你已拥有全部 %d 件",
	["DROPS_FAV"]          = "关注它",
	["DROPS_IGNORE"]       = "忽略",
	["DROPS_IGNORED_N"]    = "已忽略 %d 个",
	["DROPS_HL_FAV"]       = "已关注",
	["DROPS_HL"]           = "高亮",
	["DROPS_HL_NONE"]      = "无副属性",
	["DROPS_HL_COMBINE"]   = "必须全部拥有",
	["DROPS_SORT_SUM_S"]   = "最多未获得",
	["DROPS_SORT_BEST_S"]  = "最佳",
	["DROPS_SORT"]         = "排序",
	["DROPS_SORT_SUM"]     = "最多仍开放",
	["DROPS_SORT_BEST"]    = "最佳",
	["DROPS_ROW"]          = "%d 开放 · 最佳 %d %%",
	["DROPS_TOP_SUM"]      = "你最多未获得的：%s。",
	["DROPS_TOP_BEST"]     = "你缺少的穿着率最高物品掉落于：%s。",
	["DROPS_PLACE_boe"]    = "拍卖行",
	["DROPS_E_BOE"]        = "%d 可购买",
	["DROPS_PLACE_dungeon"] = "地下城",
	["DROPS_PLACE_raid"]   = "团队副本",
	["DROPS_PLACE_craft"]  = "制造",
	["DROPS_PLACE_set"]    = "套装部件",
	["DROPS_PLACE_pvp"]    = "PvP",
	["DROPS_PLACE_world"]  = "未知来源",
	["DROPS_GROUP_DUNGEON"] = "地下城",
	["DROPS_GROUP_RAID"]   = "团队副本",
	["DROPS_HAVE_BETTER"]  = "你已有更好的 %d 件",
	["DROPS_BETTER_N"]     = "你已超越 %d 件",
	["DROPS_WORN"]         = "你正在装备此物品",
	["DROPS_ELSEWHERE"]    = "%d / %d 件不掉落于任何副本：%s。",
	["DROPS_ELSEWHERE_1"]  = "%d / %d 件不掉落于任何副本：%s。",
	["DROPS_E_CRAFT"]      = "%d 件制造",
	["DROPS_E_SET"]        = "%d 件套装",
	["DROPS_E_PVP"]        = "%d 件来自 PvP",
	["DROPS_E_WORLD"]      = "%d 件未知来源",
	["DROPS_FROM"]         = "掉落自 %s",
	["DROPS_NOTHING"]      = "此活动中该专精没有测量数据。",
	["FOLIO_HINT"]         = "顶尖玩家在每行万奥宝典中选择的符文。",
	["FOLIO_ROW"]          = "第 %d 行 - 在 %d 名玩家上测量",
	["FOLIO_ROW_ONE"]      = "第 %d 行 - 此处无选择",
	["FOLIO_ONLY"]         = "此行唯一符文",
	["FOLIO_DERIVED"]      = "推算得出，非实测",
	["SOON_CONSUMABLES"]   = "尚未收集。合剂、药水、食物和符文记录在与附魔数据相同的日志中——只是尚未读取出来。",
	["SOON_GEAR"]          = "尚未收集。报告已包含每个部位的物品；缺少的是评估，而不是数据。",
	["SOON_TALENTS"]       = "尚未收集。天赋配置在日志中，按地下城和首领记录。",
	["LBL_ACTIVITY"]       = "活动",
	["NO_DATA_SUFFIX"]     = "（无数据）",
	["COUNT_MISSING"]      = "%d 件待购买",
})

-- Plattformwahl und die neue Themenliste.
ns.RegisterLocale("zhCN", {
	["GROUP_OVERVIEW"]     = "概览",
	["GROUP_TALENTS"]      = "天赋",
	["GROUP_GEAR"]         = "装备",
	["SECTION_settings"]   = "通用",
	["SECTION_guides"]     = "攻略与循环",
	["SECTION_stats"]      = "属性目标",
	["SECTION_players"]    = "顶尖玩家",
	["LBL_HERO"]           = "英雄天赋",
	["HERO_ALL"]           = "所有英雄树",
	["HERO_ENTRY"]         = "%s · %d %%",
	["LBL_SOURCE"]         = "网站",
	["SOURCE_ALL"]         = "所有网站",
	["SOON_GUIDES"]        = "尚未创建。循环是文字内容，无法测量——它们会来自 Wowhead 或 Method.gg 并注明出处，而那是与此处所有其他数据不同的一类数据。",
	["SOON_STATS"]         = "尚未创建。属性目标来自与附魔数据相同的装备——缺少的是评估。",
})

ns.RegisterLocale("zhCN", {
	["GEARSLOT_Head"]     = "头部",
	["GEARSLOT_Neck"]     = "颈部",
	["GEARSLOT_Shoulders"]= "肩部",
	["GEARSLOT_Back"]     = "背部",
	["GEARSLOT_Chest"]    = "胸部",
	["GEARSLOT_Wrist"]    = "腕部",
	["GEARSLOT_Hands"]    = "手部",
	["GEARSLOT_Waist"]    = "腰部",
	["GEARSLOT_Legs"]     = "腿部",
	["GEARSLOT_Feet"]     = "脚部",
	["GEARSLOT_Rings"]    = "戒指",
	["GEARSLOT_Trinkets"] = "饰品",
	["GEARSLOT_MainHand"] = "主手",
	["GEARSLOT_OffHand"]  = "副手",
})

ns.RegisterLocale("zhCN", {
	["PROBE_STAT_FALLBACK"] = "回退 - 客户端未说明",
})

ns.RegisterLocale("zhCN", {
	["LBL_LEVEL"] = "最低物品等级",
	["LEVEL_ALL"] = "任意物品等级",
	["LEVEL_MIN"] = "物品等级 %d+",
})

ns.RegisterLocale("zhCN", { ["BADGE_SET"] = "套装", ["BADGE_CRAFT"] = "制造" })

ns.RegisterLocale("zhCN", { ["ILVL"] = "物品等级 %d" })

ns.RegisterLocale("zhCN", {
	-- Consumables. The group headings are the item classes the game
	-- itself uses, not names anyone made up.
	["CONSUM_flask"]   = "合剂",
	["CONSUM_potion"]  = "战斗药水",
	["CONSUM_food"]    = "食物",
	["CONSUM_vantus"]  = "凡图斯符文",
	["CONSUM_oil"]     = "武器增益（油、石）",
	["CONSUM_other"]   = "符文及其他",
	["CONSUM_TARGET_MENU"] = "我想要多少",
	["CONSUM_TARGET_OWN"] = "其他数量…",
	["CONSUM_HINT"] = "点击物品设置你想要的数量，或说明你使用哪一个。",
	["NUMBER_OK"] = "应用",
	["CONSUM_USE_THIS"] = "我使用这个",
	["CONSUM_FROM_BAGS"] = "从我的背包中选择",
	["CONSUM_USE_MEASURED"] = "回到顶尖玩家使用的",
	["CONSUM_MINE"] = "你的选择",
	["CONSUM_TARGET"]  = "目标 %d",
	["REMIND_TITLE"]   = "MetaCodex 提醒",
	["REMIND_MISSING"] = "进本前缺少：%s",
	["REMIND_MISSING_HEAD"] = "进本前缺少：",
	["REMIND_BULLET"]  = "    • %s",
	["REMIND_OK"]      = "背包中已有合剂、食物和符文。",
	["LBL_REMINDERS"]  = "提醒我",
	["REMIND_HINT"]    = "进本前提醒检查的内容。点击一行可更改其目标；在下方购买缺少的物品。",
	["REMIND_GROUP_STATUS"]   = "当前状态",
	["REMIND_GROUP_SETTINGS"] = "设置",
	["REMIND_HAVE"]    = "%d / %d",
	["REMIND_STATE_OK"]   = "足够",
	["REMIND_STATE_QUIET"] = "无警告",
	["REMIND_STATE_LOW"]  = "不足",
	["REMIND_STATE_NONE"] = "没有",
	["REMIND_OPT_ON"]  = "提醒",
	["REMIND_OPT_ENTER"] = "进入地下城或团队副本时提醒",
	["REMIND_GROUP_WAYS"] = "提醒方式",
	["REMIND_WAY_CHAT"] = "聊天栏提示",
	["REMIND_WAY_WINDOW"] = "独立窗口",
	["REMIND_WAY_WARNING"] = "团队警告横跨屏幕",
	["REMIND_WAY_SOUND"] = "声音",
	["REMIND_OPEN_LIST"] = "在 MetaCodex 中打开",
	["REMIND_PREVIEW"] = "预览效果",
	["REMIND_PREVIEW_DO"] = "预览",
	["REMIND_PREVIEW_EMPTY"] = "没有缺少——这就是提醒的样子。",
	["REMIND_WIN_NONE"] = "背包中没有",
	["REMIND_WIN_LOW"] = "%d / %d",
	["REMIND_WIN_LOWER"] = "%d 个更低品质",
	["REMIND_WINDOW_TITLE"] = "进本前",
	["REMIND_OPT_AH_PANEL"] = "拍卖行旁的购物清单",
	["REMIND_OPT_BELOW"] = "低于目标此比例时视为不足",
	["REMIND_GROUP_ENCHANTS"] = "仍缺少的附魔与宝石",
	["IGNORE_ON"] = "忽略",
	["IGNORE_OFF"] = "停止忽略",
	["IGNORE_HINT"] = "开怪前不再提醒",
	["REMIND_GROUP_IGNORED"] = "已忽略",
	["REMIND_ENCHANTS_OK"] = "所有附魔和插槽都已处理",
	["REMIND_ENCHANTS"] = "%d 个附魔或宝石未处理",
	["REMIND_ENCHANTS_MORE"] = "另有 %d 个附魔或宝石",
	["REMIND_WIN_GEAR"] = "仍开放",
	["OPTION_CLICK"]   = "点击切换",
	["OWN_ADD"]        = "添加你自己的",
	["OWN_ADD_ID"]     = "物品 ID",
	["OWN_ADD_HINT"]    = "物品 Wowhead 地址中的数字。",
	["OWN_ADD_NONE"]   = "还没有数字",
	["OWN_ADD_WAIT"]   = "未知——你的客户端不认识此物品",
	["OWN_REMOVE"]     = "从提醒中移除",
	["REMIND_GROUP_OWN"] = "由你添加",
	["OPTION_PICK"]    = "点击选择",
	["OPTION_ON"]      = "开",
	["OPTION_OFF"]     = "关",
})

ns.RegisterLocale("zhCN", {
	["SLASH_REMIND"] = "/mc remind - 进入地下城或团队副本时提醒缺少的消耗品",
	["REMIND_ON"]    = "提醒已开启。",
	["REMIND_OFF"]   = "提醒已关闭。",
})

ns.RegisterLocale("zhCN", {
	["LBL_DUNGEON"] = "地下城",
	["DUNGEON_ALL"] = "所有地下城",
	["LBL_BOSS"]    = "首领",
	["BOSS_ALL"]    = "所有首领",
	-- The key range travels with the data instead of being a word. "High
	-- keys" means something different at every site; a number does not.
	["KEY_RANGE"]   = "+%d 至 +%d",
	["KEY_HIGH"]    = "高层钥石",
})

ns.RegisterLocale("zhCN", {
	-- Two groups, because they answer two different questions.
	["TP_BUTTON"]          = "天赋",
	["TP_COMBAT"]          = "战斗中不可用——游戏不允许在战斗中更换天赋。",
	["TP_NO_IMPORT"]       = "此客户端无法直接加载天赋。字符串在复制框中。",
	["TP_IMPORT_FAILED"]   = "加载失败（%s）。字符串在复制框中。",
	["TP_LOADED"]          = "已加载：%s",
	["TP_HINT2"]           = "点击加载天赋 · Shift-点击复制字符串",
	["TP_DRAG"]            = "拖动以移动",
	["TP_PIN"]             = "固定此预览",
	["TP_PVP_SHARE"]       = "%d %% 的统计玩家",
	["TP_PVP_HINT"]        = "三个部位，在 PvP 按钮处选择——没有天赋会包含它们。",
	["TP_PIN_HINT"]        = "框架保留在天赋树中，因此你可以向上查看天赋效果。",
	["TP_TOOLTIP"]         = "你专精的顶尖玩家使用的天赋",
	["TP_TITLE"]           = "天赋",
	["TP_NODES"]           = "%d 个天赋",
	["TP_OTHER"]           = "替代 · %d %%",
	["TP_HINT"]            = "点击复制字符串。在天赋窗口的导入下粘贴。",
	["TP_EMPTY"]           = "此活动中该专精没有统计数据。",
	["TALENT_BUILD"] = "最常见  ·  %d%% 的统计玩家",
	["CARD_SHARE"]   = "%d%% 的统计玩家使用完全相同的天赋",
	["CARD_RANK"]    = "第 %d 名  ·  %s",
	["LOADOUT_FROM_BASE"] = "字符串来自 %s",
	["LOADOUT_FROM_SOURCE"] = "字符串来自 %s",
	["TALENT_PICKS"] = "单个天赋及选择人数",
	["TALENT_PICKS_HINT"] = "顶尖玩家拥有此天赋的比例。悬停查看效果。",
	["TALENT_SHARE"] = "%d%% 的顶尖玩家选择",
	["TALENT_RANK"]  = "等级 %d",
})

ns.RegisterLocale("zhCN", {
})

ns.RegisterLocale("zhCN", {
	-- Guides are the one section that measures nothing. It names other
	-- people's work instead of showing it, which is the only clean way:
	-- the text on a guide site belongs to that site.
	["GUIDE_GROUP"]       = "文字攻略",
	["GUIDE_COPY"]        = "点击复制地址",
	["PLAYER_COPY"]       = "点击打开个人资料",
	["PLAYER_HINT"]       = "当前该专精排名最高的玩家。点击一行打开其个人资料：天赋字符串、装备、地址。",
	["PLAYER_RANK"]       = "第 %d 名",
	["ORIGIN_CONQUEST"]   = "征服商人",
	["ORIGIN_HONOR"]      = "荣誉商人",
	["ORIGIN_PVPCRAFT"]   = "制造（PvP）",
	["ORIGIN_NONE"]       = "不是副本掉落",
	["ORIGIN_EMPTY"]      = "统计中没有人穿戴这些。",
	["ORIGIN_ALL_BOSSES"] = "所有首领",
	["ORIGIN_G_dungeon"]    = "地下城",
	["ORIGIN_G_raid"]       = "团队副本",
	["ORIGIN_G_other"]      = "其他",
	["ORIGIN_GALL_dungeon"] = "所有地下城",
	["ORIGIN_GALL_raid"]    = "所有团队副本",
	["ORIGIN_GALL_other"]   = "其他所有",
	["ORIGIN_WORLD"]      = "不在日志中：世界、任务或商人",
	["LBL_ORIGIN"]        = "来源",
	["SOURCE_ANY"]        = "任意来源",
	["KEY_STEP_UPGRADE"]  = "%s  （物品升级）",
	["KEY_STEP_VAULT"]    = "%s  （宝库 %s）",
	["KEY_LEVEL_ONLY"]     = "物品等级 %d",
	["KEY_ALL"]           = "所有等级",
	["KEY_LABEL"]         = "%s %d · %d",
	["PLAYER_ENCHANT"] = "此装备上的附魔",
	["PLAYER_GEM"] = "此装备上的宝石",
	["PLAYER_BACK"]       = "返回顶尖玩家",
	["PLAYER_VIEW_HINT"]  = "该玩家当前穿戴和使用的，来自 raider.io。提示会按实际穿戴显示每件装备。",
	["PLAYER_LOADOUT"]    = "复制该玩家的天赋字符串",
	["PLAYER_VERIFIED"]   = "已验证：天赋与活动匹配",
	["PLAYER_UNVERIFIED"] = "未验证：可能是其用于其他活动的建造",
	["PLAYER_PROFILE_GROUP"] = "个人资料",
	["PLAYER_PROFILE"]    = "个人资料链接",
	["PLAYER_ILVL"]       = "物品等级 %d",
	["PLAYER_NO_PROFILE"] = "没有该玩家的个人资料",
	["PLAYER_LOADING"]    = "正在加载个人资料 …",
	["TRACK_970"]         = "探索者",
	["TALENT_PVP"]        = "PvP 天赋",
	["TRACK_971"]         = "冒险者",
	["TRACK_972"]         = "老兵",
	["TRACK_973"]         = "勇士",
	["TRACK_974"]         = "英雄",
	["TRACK_978"]         = "神话",
	["KEY_STEP_TRACK"]    = "%d · %s（%s %d）",
	["LOADOUT_NO_STRING"] = "此活动没有来源提供现成字符串——下方天赋仍然有效",
	["NO_PLAYERS"]        = "此活动没有来源对玩家排名。",
	["GUIDE_BY"]          = "作者 %s — 在浏览器中打开",
	["GUIDE_WOWHEAD"]     = "循环、冷却与技能",
	["GUIDE_WOWHEAD_BIS"] = "最佳装备，附解释",
	["GUIDE_METHOD"]      = "Method 攻略",
	["GUIDE_ARCHON_GEMS"]   = "Archon：附魔与宝石",
	["GUIDE_ARCHON_CONSUM"] = "Archon：消耗品",
	["GUIDE_MURLOK"]      = "Murlok.io：你的专精页面",
	["GUIDE_HINT"]        = "MetaCodex 测量；这些网站解释。点击一行复制其地址。",
	["LINK_TITLE"]        = "复制此地址",
	["LINK_HINT"]         = "Ctrl+C 复制。插件无法自行打开浏览器。",
	["LINK_CLOSE"]        = "关闭",
})

ns.RegisterLocale("zhCN", {
	-- One line, not an opening window. Someone at the auction house is
	-- usually there for something else.
	["AH_PANEL_TITLE"] = "购物清单",
	["AH_PANEL_COUNT_1"] = "缺少 1 件——点击搜索",
	["AH_PANEL_LIST"] = "创建清单",
	["AH_PANEL_SEARCH"] = "搜索",
	-- KURZ GENUG FUER DIE PANEELBREITE.
	--
	-- "click one to search for it" lief ueber den Rand und stand im
	-- Spiel als "click one to search for" da - ein Satz, der mitten im
	-- Wort aufhoert, sieht aus wie ein Fehler und ist einer.
	["AH_PANEL_COUNT"] = "缺少 %d 件——点击搜索",
	["AH_PANEL_EMPTY"] = "没有缺少。你都有了。",
	["AH_PANEL_OF"] = "%d / %d",
	["AH_PANEL_MORE"] = "另有 %d 件",
	["AH_PANEL_SEARCH_FALLBACK"] = "未找到搜索框。请查找：%s",
})

ns.RegisterLocale("zhCN", {
	-- "Empty" almost never means "not built yet" any more. It means this
	-- platform does not measure this, or measures it and has not seen
	-- this spec often enough.
	["NO_SOURCE_SECTION"] = "%s 在此活动中没有内容。试试其他网站，或全部网站。",
	["NO_SPEC_SECTION"]   = "还没有网站在此活动中拥有足够的该专精记录。",
})

ns.RegisterLocale("zhCN", {
	-- Auctionator's own error for this reads "Contact the maintainer of
	-- MetaCodex", which the player rightly reads as our fault. It is:
	-- we asked without looking.
	["AH_CLOSED"] = "请先打开拍卖行——搜索在其中进行。购物清单可在任何地方创建。",
})

ns.RegisterLocale("zhCN", {
	-- The highest key it was still seen at. Answers what a percentage
	-- cannot: whether something holds up at the top or is merely common.
	["MAX_KEY"] = "最高 +%d",
})

ns.RegisterLocale("zhCN", {
	-- Potions split the way Archon splits them, and the way they are
	-- actually used: one belongs in the rotation, one in an emergency.
	["CONSUM_heal"] = "治疗药水",
})

ns.RegisterLocale("zhCN", {
	["NO_DUNGEON_DATA"] = "按地下城的数据是独立插件（MetaCodex_Dungeons），未安装。",
})

ns.RegisterLocale("zhCN", {
	-- The window shows one spec; the list may cover several. Saying so
	-- matters: otherwise someone presses the button and gets more than
	-- they can see.
	["SPEC_ALSO_BUY"] = "还要为以下专精购买…",
	["COUNT_SPECS"]   = "清单涵盖 %d 个专精",
})

ns.RegisterLocale("zhCN", {
	-- A build is not a list of names — nobody types one in. What is
	-- wanted is the import string: one click, paste, done.
	["LOADOUT_TITLE"]      = "复制此天赋",
	["LOADOUT_HINT"]       = "%d 个天赋 · 粘贴到天赋窗口的导入框",
	["LOADOUT_PASTE"]      = "在天赋窗口的导入下粘贴",
	["LOADOUT_DIFF_HINT"]  = "%d 个天赋不同 · 粘贴到天赋窗口的导入框",
})


ns.RegisterLocale("zhCN", {
	-- What is missing belongs on the right, where the eye lands.
	-- The rank sat there and was the smaller answer: the order already
	-- shows it.
	["STAT_HINT"]  = "统计玩家的中位数，一次一个属性——评分点，而不是角色面板显示的效果。",
	["STAT_HINT_N"] = "%d 名统计玩家的中位数，一次一个属性——评分点，而不是角色面板显示的效果。",
	["STAT_SHARE"] = "占所有副属性评分的 %d%%",
	["STAT_YOURS"] = "你有 %d / %d",
	["STAT_GAP"] = "−%d",
	["STAT_DONE"] = "已达成",
})

ns.RegisterLocale("zhCN", {
	-- The test harness outside the game cannot confirm this format — it
	-- is my own rebuild of it. Only the client knows whether the encoder
	-- agrees with Blizzard.
	["LOADOUT_NO_IMPORT"]    = "此客户端不允许应用配置。",
	["LOADOUT_IN_COMBAT"]    = "战斗中不可用。",
})

ns.RegisterLocale("zhCN", {
	["LBL_GEARSLOT"] = "部位",
	["SLOT_ALL"]     = "所有部位",
})

ns.RegisterLocale("zhCN", {
	["LBL_CATEGORY"] = "显示",
	["CATEGORY_ALL"] = "全部",
})

ns.RegisterLocale("zhCN", {
	["GROUP_ABOUT"]   = "设置",
	["SECTION_info"]  = "信息",
	["INFO_GROUP"]    = "数据",
	["INFO_NEEDS"]    = "所需条件",
	["INFO_VERSION"]  = "MetaCodex 版本",
	["INFO_CATALOG"]  = "来自游戏文件的目录",
	["INFO_AUCTIONATOR_OK"]      = "已安装",
	["INFO_AUCTIONATOR_MISSING"] = "未安装",
	-- The one line that was nowhere before: the handover needs it.
	["INFO_AUCTIONATOR_GET"] = "点击获取插件链接",
	["INFO_AUCTIONATOR_WHY"]     = "仅用于将清单移交给拍卖行。其他功能无需它即可使用。",
})

ns.RegisterLocale("zhCN", {
	["SLOT_meta"] = "特殊插槽",
	-- An alternative carries no count: you buy one of them, not all.
	["ALT_ROW"]   = "替代",
})

ns.RegisterLocale("zhCN", {
	-- Where an item comes from, in descending certainty. The last one is
	-- deliberately not a claim about the drop: world, vendor and delve
	-- loot are in no table we can read.
	["ORIGIN_SET"]        = "套装 — 团队副本或宝库",
	["ORIGIN_CRAFT"]      = "制造",
	["ORIGIN_SEEN"]       = "见于 %s",
	["ORIGIN_MODE_mplus"] = "史诗钥石",
	["ORIGIN_MODE_raid"]  = "团队副本",
	["ORIGIN_MODE_2v2"]   = "PvP",
	["ORIGIN_MODE_3v3"]   = "PvP",
	["ORIGIN_MODE_rbg"]   = "PvP",
	["ORIGIN_MODE_solo"]  = "PvP",
	["ORIGIN_MODE_blitz"] = "PvP",
})

ns.RegisterLocale("zhCN", {
	-- Not a filter. The question is not "hide what is below", but "what
	-- do I get" — somebody running +10 cannot tell from a list of 334s
	-- that it becomes 311 for them.
	["LBL_KEY"]   = "你的钥石",
	["KEY_ROW"]   = "+%d  ·  %d  ·  宝库 %d",
	["KEY_SHORT"] = "+%d  ·  %d",
	["KEY_YOURS"] = "你会获得 %d",
	["KEY_VAULT"] = "宝库 %d",
})

ns.RegisterLocale("zhCN", {
})

ns.RegisterLocale("zhCN", {
	["KEY_GROUP_RUN"]   = "地下城结束",
	["KEY_GROUP_VAULT"] = "宏伟宝库",
	["KEY_ENTRY"]       = "%d  (+%d)",
})

ns.RegisterLocale("zhCN", {
	-- Quietly showing the right thing is good. Quietly showing something
	-- other than what the button says is not.
	["SOURCE_FELL_BACK"] = "%s 在此没有内容——改为显示 %s。",
})

ns.RegisterLocale("zhCN", {
	-- "20% run exactly this" also means 80% do not. What the others
	-- change is the question behind every talent comparison.
	["TALENT_OTHERS"] = "其他版本",
	["TALENT_SWAP"]   = "%s 而非 %s",
	["SWAP_TAKES"]    = "选择",
	["SWAP_DROPS"]    = "替代",
	["TREE_PREVIEW"]  = "天赋树中：%d 个绿色选择，%d 个红色放弃",
	["TREE_OTHER_HERO"] = "此天赋使用 %s 英雄树：%s",
	["TREE_NOT_DRAWN"]  = "此树中未绘制：%s",
	["TALENT_PLUS"]   = "额外 %s",
	["TALENT_MINUS"]  = "不含 %s",
})

ns.RegisterLocale("zhCN", {
	["KEY_STEP"] = "%s  （%s）",
})

ns.RegisterLocale("zhCN", {
	["PROBE_LEVEL_HEADER"] = "链接中的物品等级：",
	["PROBE_LEVEL_NONE"]   = "此视图中没有带等级的装备",
	["PROBE_LEVEL_BASE"]   = "基础 %s，期望 %s",
	["PROBE_LEVEL_DELTA"]  = "差值 %d，奖励 ID %s",
	["PROBE_LEVEL_LINK"]   = "链接 %s",
	["PROBE_LEVEL_RESULT"] = "客户端读取 %s，期望 %s",
})

ns.RegisterLocale("zhCN", {
	["TEXT_TITLE"] = "复制此报告",
	["TEXT_HINT"]  = "Ctrl+A、Ctrl+C。聊天栏是用来阅读的，不是用来提取文本的。",
})
