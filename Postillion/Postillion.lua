-- Postillion: Post-Empfänger vervollständigen, auch für Battle.net-Freunde, die offline sind.
-- Idee: Der Charaktername eines Battle.net-Freundes ist nur sichtbar, solange er online ist.
-- Wir merken uns jeden Namen, den wir je gesehen haben (Freunde, Gilde, Gruppe, Flüstern,
-- Post-Absender, früher angeschriebene Empfänger) und bieten sie im Empfängerfeld der Post an.

local ADDON = "Postillion"
local NP = {}
_G.Postillion = NP

local DE = (GetLocale and GetLocale() == "deDE")
local function L(de, en) return DE and de or en end

local ROWS = 8          -- Zeilen im Vorschlagsfenster
local LIST_ROWS = 14    -- Zeilen in der vollständigen Liste

local db

local function lower(s) return (s or ""):lower() end
local function initDB()
  -- Umbenennung NevPost -> Postillion (0.5.0): alte gemerkte Namen einmalig übernehmen
  if not PostillionDB and NevPostDB then PostillionDB = NevPostDB end
  PostillionDB = PostillionDB or {}
  db = PostillionDB
  if (db.v or 1) < 2 then db.chars = {}; db.v = 2 end  -- 0.1.0 kannte weder Server noch Fraktion
  -- [kleingeschriebener Name|Server] = {name, realm, faction, src, tag, acc, class, level, seen}
  db.chars = db.chars or {}
  db.hide = db.hide or {}     -- vom Nutzer entfernte Namen (Name|Server)
end

-- Server und Fraktion vergleichbar machen
-- Forever-Servernamen wie "CAMWOWEU5Realm5PvE": Nummern (EU5, Realm5) sind nur Layer desselben
-- Servers. Verglichen wird allein der Typ hinter "RealmN" (pve, rppve, pvp ...).
local function normRealm(r)
  if not r or r == "" then return nil end
  r = (r:gsub("[%s%-']", "")):lower()
  local kind = r:match("realm%d+(.*)$")
  if kind and kind ~= "" then return kind end
  return r
end
local function normFaction(f)
  if not f or f == "" then return nil end
  local l = f:lower()
  if l == "horde" or (FACTION_HORDE and l == FACTION_HORDE:lower()) then return "Horde" end
  if l == "alliance" or (FACTION_ALLIANCE and l == FACTION_ALLIANCE:lower()) then return "Alliance" end
  return nil
end
local function myRealm() return normRealm(GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()) end
local function myFaction() return normFaction((UnitFactionGroup("player"))) end

-- verbundene Server (Post geht dorthin ebenfalls) gelten als gleicher Server
local function realmOk(r)
  if not r then return false end
  if r == myRealm() then return true end
  if GetAutoCompleteRealms then
    local ok, list = pcall(GetAutoCompleteRealms)
    if ok and type(list) == "table" then
      for _, x in ipairs(list) do if normRealm(x) == r then return true end end
    end
  end
  return false
end

-- passt der Eintrag zu meinem Charakter (gleicher Server, gleiche Fraktion)?
local function sameWorld(c)
  return c.realmKey ~= nil and c.faction ~= nil and realmOk(c.realmKey) and c.faction == myFaction()
end

local function worldLabel(c)
  return (c.realmKey or "?") .. ", " .. (c.faction or "?")
end

-- Quelle: höhere Zahl = vertrauenswürdiger bzw. wichtiger für die Sortierung
local SRC_RANK = { freund = 5, manuell = 4, post = 3, gilde = 2, gruppe = 2, fluestern = 2, liste = 3 }

-- Quellen im selben Spiel wie ich (Gilde, Gruppe, Flüstern, Post, Freundesliste): Server und
-- Fraktion sind bekannt oder gleich meiner. Battle.net-Freunde liefern beides selbst mit.
local function remember(name, src, tag, acc, class, level, realm, faction)
  if not name or not db then return end
  local n, r = name:match("^(.-)%-([^%- ]+)$")
  n = n or name
  realm = realm or r
  n = n:gsub("^%s+", ""):gsub("%s+$", "")
  if n == "" then return end
  if n == (UnitName and UnitName("player")) then return end
  local inherent = (src ~= "freund" and src ~= "manuell")
  if inherent then
    realm = realm or (GetRealmName and GetRealmName())
    faction = faction or (UnitFactionGroup and UnitFactionGroup("player"))
  end
  local rk, fk = normRealm(realm), normFaction(faction)
  local key = lower(n) .. "|" .. (rk or "?")
  if db.hide[key] and src ~= "manuell" then return end
  db.hide[key] = nil
  -- ein früherer Eintrag ohne Serverangabe wird durch den bekannten ersetzt
  if rk then db.chars[lower(n) .. "|?"] = nil end
  local c = db.chars[key]
  if not c then
    c = { name = n }
    db.chars[key] = c
  end
  if #n > #(c.name or "") then c.name = n end
  if not c.src or (SRC_RANK[src] or 0) >= (SRC_RANK[c.src] or 0) then c.src = src end
  if realm and realm ~= "" then c.realm = realm; c.realmKey = rk end
  if fk then c.faction = fk end
  if tag and tag ~= "" then c.tag = tag end
  if acc and acc ~= "" then c.acc = acc end
  if class and class ~= "" then c.class = class end
  if level and tonumber(level) and tonumber(level) > 0 then c.level = tonumber(level) end
  c.seen = time()
end

-- Alle Namen des Freundes (gleiche BattleTag) für die Anzeige "Alt von ..."
local function friendLabel(c)
  if c.acc and c.acc ~= "" then return c.acc end
  if c.tag then return (c.tag:gsub("#.*$", "")) end
  return nil
end

----------------------------------------------------------------------
-- Quellen einlesen
----------------------------------------------------------------------

local function scanBattleNet()
  local n = 0
  if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
    local num = BNGetNumFriends() or 0
    for i = 1, num do
      local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, i)
      if ok and info then
        local function take(g)
          if g and g.characterName and g.characterName ~= "" then
            -- nur WoW-Charaktere (andere Spiele haben keinen Post)
            if not g.clientProgram or g.clientProgram == "WoW" or g.clientProgram == "WoWC" then
              remember(g.characterName, "freund", info.battleTag, info.accountName, g.className, g.characterLevel,
                g.realmName or g.realmDisplayName, g.factionName)
              n = n + 1
            end
          end
        end
        take(info.gameAccountInfo)
        -- mehrere Spielkonten (z.B. zwei WoW-Instanzen gleichzeitig)
        if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
          local okn, ng = pcall(C_BattleNet.GetFriendNumGameAccounts, i)
          if okn and ng then
            for j = 1, ng do
              local okg, g = pcall(C_BattleNet.GetFriendGameAccountInfo, i, j)
              if okg then take(g) end
            end
          end
        end
      end
    end
  elseif BNGetNumFriends and BNGetFriendInfo then
    -- ältere API
    for i = 1, (BNGetNumFriends() or 0) do
      local _, accName, tag, _, toon, _, client, isOnline = BNGetFriendInfo(i)
      if isOnline and toon and toon ~= "" and (client == "WoW" or client == "WoWC" or client == nil) then
        remember(toon, "freund", tag, accName) -- alte API liefert Server/Fraktion nicht
        n = n + 1
      end
    end
  end
  return n
end

local function scanFriendList()
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, (C_FriendList.GetNumFriends() or 0) do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and info.name then remember(info.name, "liste", nil, nil, info.className, info.level) end
    end
  end
end

local function scanGuild()
  if not (IsInGuild and IsInGuild()) or not GetNumGuildMembers then return end
  for i = 1, (GetNumGuildMembers() or 0) do
    local name, _, _, level, class = GetGuildRosterInfo(i)
    if name then remember(name, "gilde", nil, nil, class, level) end
  end
end

local function scanGroup()
  local prefix, count
  if IsInRaid and IsInRaid() then prefix, count = "raid", GetNumGroupMembers()
  elseif IsInGroup and IsInGroup() then prefix, count = "party", GetNumGroupMembers() - 1
  else return end
  for i = 1, count or 0 do
    local u = prefix .. i
    if UnitExists(u) and UnitIsPlayer(u) then
      local nm = (GetUnitName and GetUnitName(u, true)) or UnitName(u)
      remember(nm, "gruppe", nil, nil, UnitClass(u), UnitLevel(u), nil, UnitFactionGroup(u))
    end
  end
end

local function scanInbox()
  if not GetInboxNumItems then return end
  for i = 1, (GetInboxNumItems() or 0) do
    local _, _, sender = GetInboxHeaderInfo(i)
    if sender then remember(sender, "post") end
  end
end

function NP.ScanAll()
  scanBattleNet(); scanFriendList(); scanGuild(); scanGroup()
end

----------------------------------------------------------------------
-- Suche
----------------------------------------------------------------------

-- Treffer, wenn der Suchtext Anfang des Namens, eines Namensteils (Nachname) oder des Freundesnamens ist
local function matches(c, q)
  if q == "" then return 1 end
  local nm = lower(c.name)
  if nm:sub(1, #q) == q then return 3 end
  for word in nm:gmatch("%S+") do
    if word:sub(1, #q) == q then return 2 end
  end
  local lab = lower(friendLabel(c))
  if lab ~= "" and lab:sub(1, #q) == q then return 2 end
  if #q >= 3 and nm:find(q, 1, true) then return 1 end
  return nil
end

function NP.Search(q, max, all)
  q = lower((q or ""):gsub("^%s+", ""):gsub("%s+$", ""))
  local out = {}
  for _, c in pairs(db.chars) do
    local score = matches(c, q)
    -- nur Namen von meinem Server und meiner Fraktion, sonst geht die Post an die falsche Person
    if score and (all or sameWorld(c)) then
      out[#out + 1] = { c = c, score = score * 10 + (SRC_RANK[c.src] or 0) }
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return lower(a.c.name) < lower(b.c.name)
  end)
  if max and #out > max then
    for i = #out, max + 1, -1 do out[i] = nil end
  end
  return out
end

----------------------------------------------------------------------
-- Oberfläche am Post-Fenster (flaches dunkles Design wie Kindergarten)
----------------------------------------------------------------------

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local C = {
  bg = { 0.07, 0.065, 0.11, 0.98 }, card = { 0.135, 0.125, 0.2, 1 }, cardHover = { 0.18, 0.165, 0.26, 1 },
  edge = { 0.24, 0.22, 0.34, 1 }, field = { 0.06, 0.055, 0.09, 1 },
  text = { 0.93, 0.92, 0.97 }, dim = { 0.62, 0.6, 0.72 }, sun = { 1, 0.8, 0.36 },
  red = { 1, 0.4, 0.4 }, sky = { 0.47, 0.74, 0.98 },
}

local box, sug, listFrame, rows, listRows

local function Flat(f, bg, edge)
  f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(edge or C.edge))
end

local function Text(parent, size, color)
  local t = parent:CreateFontString(nil, "OVERLAY")
  t:SetFont(FONT, size, "")
  t:SetTextColor(unpack(color or C.text))
  t:SetJustifyH("LEFT")
  return t
end

local function Panel(name, parent)
  local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
  Flat(f, C.bg)
  return f
end

local function FlatButton(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 22)
  Flat(b, C.card)
  b.label = Text(b, 12, C.text)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(label)
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(C.cardHover)); self:SetBackdropBorderColor(unpack(C.sun)) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.card)); self:SetBackdropBorderColor(unpack(C.edge)) end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Klasse (lokalisierter Name aus Battle.net oder Token) -> Token wie "PRIEST"
local classTokens
local function classToken(class)
  if not class or class == "" then return nil end
  if not classTokens then
    classTokens = {}
    for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
      for token, name in pairs(tbl) do classTokens[lower(name)] = token end
    end
  end
  return classTokens[lower(class)] or class:upper():gsub(" ", "")
end

local function classColor(class)
  local tok = classToken(class)
  local t = tok and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok]
  if t then return t.r, t.g, t.b end
  return unpack(C.text)
end

local function describe(c)
  local parts = {}
  local lab = friendLabel(c)
  if lab then parts[#parts + 1] = lab end
  if c.level then parts[#parts + 1] = L("Stufe ", "Lvl ") .. c.level end
  return table.concat(parts, " · ")
end

local function chooseName(c)
  if not box then return end
  if not sameWorld(c) then
    print("|cffffcc5cPostillion:|r |cffff5555" .. L("Achtung: ", "Warning: ") .. c.name .. " ("
      .. worldLabel(c) .. ") " .. L("ist auf einem anderen Server oder in einer anderen Fraktion als du.",
      "is on a different realm or faction than you.") .. "|r")
  end
  box:SetText(c.name)
  box:SetCursorPosition(#c.name)
  if sug then sug:Hide() end
  if listFrame then listFrame:Hide() end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus() end
end

local ROW_H = 26

-- Zeile: Klassensymbol, Name in Klassenfarbe, rechts Freund/Stufe, bei Fremden Server/Fraktion in Rot
local function makeRow(parent, i, onClick, top)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetHeight(ROW_H - 2)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -(top or 5) - (i - 1) * ROW_H)
  b:SetPoint("RIGHT", parent, "RIGHT", -5, 0)
  Flat(b, C.card, C.card)
  b.stripe = b:CreateTexture(nil, "OVERLAY")
  b.stripe:SetColorTexture(unpack(C.sun)); b.stripe:SetWidth(2)
  b.stripe:SetPoint("TOPLEFT", 0, 0); b.stripe:SetPoint("BOTTOMLEFT", 0, 0); b.stripe:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 7, 0)
  b.name = Text(b, 13)
  b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.info = Text(b, 11, C.dim)
  b.info:SetJustifyH("RIGHT"); b.info:SetPoint("RIGHT", -7, 0)
  b.name:SetPoint("RIGHT", b.info, "LEFT", -6, 0)
  b.name:SetWordWrap(false)
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(C.cardHover)); self:SetBackdropBorderColor(unpack(C.sky)) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.card)); self:SetBackdropBorderColor(unpack(C.card)) end)
  b:SetScript("OnClick", function(self) if self.c then onClick(self.c) end end)
  return b
end

local function fillRow(r, res, first)
  if not res then r.c = nil; r:Hide() return end
  local c = res.c
  r.c = c
  local ok = sameWorld(c)
  r.name:SetText(c.name)
  if ok then r.name:SetTextColor(classColor(c.class)) else r.name:SetTextColor(0.55, 0.55, 0.6) end
  local tok = classToken(c.class)
  local coords = tok and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[tok]
  if coords then
    r.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    r.icon:SetTexCoord(unpack(coords))
  else
    r.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  r.icon:SetDesaturated(not ok)
  if ok then
    r.info:SetText(describe(c)); r.info:SetTextColor(unpack(C.dim))
  else
    r.info:SetText(worldLabel(c)); r.info:SetTextColor(unpack(C.red))
  end
  if r.stripe then if first then r.stripe:Show() else r.stripe:Hide() end end
  r:Show()
end

local function showSuggestions()
  if not box or not sug then return end
  local q = box:GetText() or ""
  if #q < 1 then sug:Hide(); return end
  local res = NP.Search(q, ROWS)
  -- nichts anzeigen, wenn der Text schon genau ein Treffer ist
  if #res == 0 or (#res == 1 and lower(res[1].c.name) == lower(q)) then sug:Hide(); return end
  for i = 1, ROWS do fillRow(rows[i], res[i], i == 1) end
  sug:SetHeight(10 + math.min(#res, ROWS) * ROW_H + 18)
  sug:Show()
end

local listOffset = 0
local listResults = {}
local function refreshList()
  local q = listFrame.search:GetText() or ""
  listFrame.placeholder:SetShown(q == "" and not listFrame.search:HasFocus())
  listResults = NP.Search(q, nil, db.showAll)
  local maxOff = math.max(0, #listResults - LIST_ROWS)
  if listOffset > maxOff then listOffset = maxOff end
  if listOffset < 0 then listOffset = 0 end
  for i = 1, LIST_ROWS do fillRow(listRows[i], listResults[listOffset + i]) end
  listFrame.count:SetText(#listResults .. L(" Namen", " names"))
  -- schmaler Rollbalken rechts
  local track = listFrame.track
  if #listResults > LIST_ROWS then
    local h = track:GetHeight()
    local thumbH = math.max(18, h * LIST_ROWS / #listResults)
    listFrame.thumb:SetHeight(thumbH)
    listFrame.thumb:ClearAllPoints()
    listFrame.thumb:SetPoint("TOP", track, "TOP", 0, -((h - thumbH) * listOffset / math.max(1, maxOff)))
    track:Show()
  else
    track:Hide()
  end
  listFrame.empty:SetShown(#listResults == 0)
end

local function buildUI()
  box = _G.SendMailNameEditBox
  if not box or NP.uiBuilt then return end
  NP.uiBuilt = true

  -- Vorschlagsfenster direkt unter dem Empfängerfeld
  sug = Panel("PostillionSuggest")
  sug:SetFrameStrata("DIALOG")
  sug:SetWidth(310)
  sug:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -2)
  sug:SetBackdropBorderColor(unpack(C.sun))
  sug:Hide()
  rows = {}
  for i = 1, ROWS do rows[i] = makeRow(sug, i, chooseName) end
  local hint = Text(sug, 10, C.dim)
  hint:SetPoint("BOTTOMLEFT", 8, 5)
  hint:SetText(L("Tab = erster Treffer · Klick = übernehmen", "Tab = first match · click = pick"))

  box:HookScript("OnTextChanged", function(_, userInput)
    if userInput then showSuggestions() end
  end)
  box:HookScript("OnEditFocusLost", function()
    -- kurz warten, damit ein Klick auf eine Zeile noch ankommt
    C_Timer.After(0.15, function() if sug then sug:Hide() end end)
  end)
  box:HookScript("OnEscapePressed", function() sug:Hide() end)
  box:HookScript("OnTabPressed", function()
    -- Tab nimmt den ersten Vorschlag, wenn der Text noch nicht genau stimmt
    local q = box:GetText() or ""
    if #q < 1 then return end
    local res = NP.Search(q, 1)
    if res[1] and lower(res[1].c.name) ~= lower(q) then
      box:SetText(res[1].c.name)
      box:SetCursorPosition(#res[1].c.name)
    end
    sug:Hide()
  end)

  -- Schaltfläche neben dem Feld: komplette Liste mit Suche
  local btn = FlatButton(box, L("Freunde", "Friends"), 64, 22, function() NP.ToggleList() end)
  btn:SetPoint("LEFT", box, "RIGHT", 6, 0)
  btn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Postillion")
    GameTooltip:AddLine(L("Alle gemerkten Charakternamen, auch von Freunden, die offline sind.",
      "All remembered character names, including friends who are offline."), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  btn:HookScript("OnLeave", function() GameTooltip:Hide() end)

  -- Listenfenster
  listFrame = Panel("PostillionList")
  listFrame:SetFrameStrata("DIALOG")
  listFrame:SetSize(340, 40 + 34 + LIST_ROWS * ROW_H + 30)
  listFrame:SetPoint("TOPLEFT", MailFrame or box, "TOPRIGHT", 6, -20)
  listFrame:SetMovable(true); listFrame:EnableMouse(true)
  listFrame:RegisterForDrag("LeftButton")
  listFrame:SetScript("OnDragStart", function(s) s:StartMoving() end)
  listFrame:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  listFrame:EnableMouseWheel(true)
  listFrame:Hide()

  local title = Text(listFrame, 15, C.sun)
  title:SetPoint("TOPLEFT", 12, -11); title:SetText("Postillion")
  local sub = Text(listFrame, 10, C.dim)
  sub:SetPoint("LEFT", title, "RIGHT", 8, -1); sub:SetText(L("Post an Freunde, auch offline", "Mail to friends, even offline"))
  local close = FlatButton(listFrame, "×", 22, 22, function() listFrame:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)

  local search = CreateFrame("EditBox", nil, listFrame, "BackdropTemplate")
  search:SetHeight(24); search:SetPoint("TOPLEFT", 8, -40); search:SetPoint("TOPRIGHT", -8, -40)
  Flat(search, C.field)
  search:SetFont(FONT, 12, ""); search:SetTextColor(unpack(C.text))
  search:SetAutoFocus(false); search:SetTextInsets(8, 8, 0, 0)
  search:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  search:SetScript("OnTextChanged", function() listOffset = 0; refreshList() end)
  search:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.sun)); refreshList() end)
  search:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(C.edge)); refreshList() end)
  listFrame.search = search
  listFrame.placeholder = Text(search, 12, C.dim)
  listFrame.placeholder:SetPoint("LEFT", 8, 0)
  listFrame.placeholder:SetText(L("Name, Nachname oder Freund suchen ...", "Search name, last name or friend ..."))

  local holder = CreateFrame("Frame", nil, listFrame)
  holder:SetPoint("TOPLEFT", 0, -70); holder:SetPoint("BOTTOMRIGHT", 0, 30)
  listRows = {}
  for i = 1, LIST_ROWS do listRows[i] = makeRow(holder, i, chooseName, 0) end
  for i = 1, LIST_ROWS do listRows[i]:SetPoint("RIGHT", holder, "RIGHT", -13, 0) end
  listFrame.empty = Text(holder, 12, C.dim)
  listFrame.empty:SetPoint("TOP", 0, -30); listFrame.empty:SetJustifyH("CENTER")
  listFrame.empty:SetText(L("Noch keine passenden Namen.\nFreunde werden gemerkt, sobald sie online sind.",
    "No matching names yet.\nFriends are remembered once they are online."))

  -- Rollbalken
  local track = CreateFrame("Frame", nil, holder)
  track:SetWidth(4); track:SetPoint("TOPRIGHT", -5, -2); track:SetPoint("BOTTOMRIGHT", -5, 2)
  local tbg = track:CreateTexture(nil, "BACKGROUND"); tbg:SetAllPoints(); tbg:SetColorTexture(unpack(C.field))
  listFrame.thumb = track:CreateTexture(nil, "ARTWORK")
  listFrame.thumb:SetWidth(4); listFrame.thumb:SetColorTexture(unpack(C.edge))
  listFrame.track = track

  -- Fuß: Zähler, Schalter für fremde Server/Fraktionen
  listFrame.count = Text(listFrame, 10, C.dim)
  listFrame.count:SetPoint("BOTTOMLEFT", 12, 10)
  local tog = FlatButton(listFrame, "", 170, 18, function(self)
    db.showAll = not db.showAll
    self.label:SetText((db.showAll and "[x] " or "[ ] ") .. L("andere Server/Fraktionen", "other realms/factions"))
    listOffset = 0; refreshList()
  end)
  tog.label:SetFont(FONT, 10, "")
  tog.label:SetTextColor(unpack(C.dim))
  tog:SetPoint("BOTTOMRIGHT", -8, 6)
  listFrame.toggle = tog

  listFrame:SetScript("OnMouseWheel", function(_, d)
    listOffset = listOffset - d * 3
    refreshList()
  end)
  listFrame:SetScript("OnShow", function()
    NP.ScanAll()
    tog.label:SetText((db.showAll and "[x] " or "[ ] ") .. L("andere Server/Fraktionen", "other realms/factions"))
    refreshList()
  end)
  if MailFrame then MailFrame:HookScript("OnHide", function() listFrame:Hide(); sug:Hide() end) end
end

function NP.ToggleList()
  if not listFrame then return end
  if listFrame:IsShown() then listFrame:Hide() else listFrame:Show() end
end

----------------------------------------------------------------------
-- Ereignisse
----------------------------------------------------------------------

local f = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED",
  "BN_FRIEND_ACCOUNT_ONLINE", "BN_CONNECTED", "FRIENDLIST_UPDATE", "GROUP_ROSTER_UPDATE",
  "GUILD_ROSTER_UPDATE", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "CHAT_MSG_WHISPER",
  "CHAT_MSG_BN_WHISPER" }) do
  pcall(f.RegisterEvent, f, e)
end

local pendingScan
local function scheduleScan()
  if pendingScan then return end
  pendingScan = true
  C_Timer.After(1, function()
    pendingScan = nil
    if db then scanBattleNet(); scanFriendList() end
  end)
end

-- Selbstständig im Hintergrund einlesen: kurz nach dem Login (Battle.net ist dann oft noch nicht
-- bereit), danach regelmäßig. Freunde alle 60 s, Gilde alle 5 min. Ausschalten: /pp auto
local AUTO_FRIENDS, AUTO_GUILD = 60, 300
local function autoStep()
  if not db or db.auto == false then return end
  scanBattleNet(); scanFriendList(); scanGroup()
end
local function guildStep()
  if not db or db.auto == false then return end
  if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
  scanGuild()
end
function NP.StartAuto()
  if NP.autoStarted then return end
  NP.autoStarted = true
  for _, t in ipairs({ 5, 20 }) do C_Timer.After(t, autoStep) end
  C_Timer.After(10, guildStep)
  if C_Timer.NewTicker then
    C_Timer.NewTicker(AUTO_FRIENDS, autoStep)
    C_Timer.NewTicker(AUTO_GUILD, guildStep)
  end
end

local lastRecipient
f:SetScript("OnEvent", function(_, event, a1, ...)
  if event == "ADDON_LOADED" then
    if a1 == ADDON then initDB() end
    return
  end
  if not db then return end
  if event == "PLAYER_LOGIN" then
    NP.ScanAll()
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    NP.StartAuto()
    if SendMail and not NP.hookedSend then
      NP.hookedSend = true
      hooksecurefunc("SendMail", function(recipient) lastRecipient = recipient end)
    end
  elseif event == "MAIL_SHOW" then
    buildUI()
    scanInbox()
  elseif event == "MAIL_INBOX_UPDATE" then
    scanInbox()
  elseif event == "MAIL_SEND_SUCCESS" then
    if lastRecipient then remember(lastRecipient, "post"); lastRecipient = nil end
  elseif event == "GROUP_ROSTER_UPDATE" then
    scanGroup()
  elseif event == "GUILD_ROSTER_UPDATE" then
    scanGuild()
  elseif event == "CHAT_MSG_WHISPER" then
    -- a1 = Text, 2. Rückgabewert = Absender
    local sender = ...
    remember(sender, "fluestern")
  else
    -- Battle.net-/Freundesereignisse: Freunde einlesen (kurz gebündelt)
    scheduleScan()
  end
end)

----------------------------------------------------------------------
-- Befehle
----------------------------------------------------------------------

local function say(msg) print("|cffffcc5cPostillion:|r " .. msg) end

SLASH_POSTILLION1 = "/pp"
SLASH_POSTILLION2 = "/postillion"
SlashCmdList["POSTILLION"] = function(msg)
  if not db then return end
  msg = msg or ""
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = lower(cmd)
  if cmd == "" or cmd == "hilfe" or cmd == "help" then
    say(L("Merkt Charakternamen von Freunden und vervollständigt sie im Post-Feld, auch offline.",
          "Remembers friends' character names and autocompletes them in the mail field, also offline."))
    say(L("/pp liste [Teil]  zeigt gemerkte Namen", "/pp list [part]  shows remembered names"))
    say(L("/pp add <Name> [Freundesname]  Name von Hand merken", "/pp add <name> [friend name]  remember a name by hand"))
    say(L("/pp del <Name>  Namen vergessen", "/pp del <name>  forget a name"))
    say(L("/pp alle  Liste auch mit Namen anderer Server/Fraktionen (grau) ein- oder ausschalten",
          "/pp all  toggle showing names from other realms/factions (grey) in the list"))
    say(L("/pp auto  automatisches Einlesen alle 60 s ein/aus (Standard: an)",
          "/pp auto  toggle automatic scan every 60 s (default: on)"))
    say(L("/pp scan  Freunde, Gilde, Gruppe jetzt einlesen", "/pp scan  read friends, guild, group now"))
    say(L("Im Post-Fenster: Name tippen (auch nur Nachname) oder Knopf \"Freunde\".",
          "In the mail window: type a name (or just the last name) or use the \"Friends\" button."))
  elseif cmd == "alle" or cmd == "all" then
    db.showAll = not db.showAll
    say(db.showAll and L("Liste zeigt jetzt auch andere Server/Fraktionen (grau, Vorschläge im Post-Feld bleiben gefiltert).",
      "List now also shows other realms/factions (grey, mail suggestions stay filtered).")
      or L("Liste zeigt nur noch Namen von deinem Server und deiner Fraktion.", "List shows only your realm and faction again."))
  elseif cmd == "liste" or cmd == "list" then
    local res = NP.Search(rest, 40, db.showAll)
    say(#res .. L(" Treffer", " matches"))
    for _, r in ipairs(res) do
      say(r.c.name .. "  |cff999999" .. worldLabel(r.c) .. ", " .. describe(r.c) .. " [" .. tostring(r.c.src) .. "]|r")
    end
  elseif cmd == "add" then
    local name, acc = rest:match("^(.-)%s*|%s*(.+)$")
    if not name then name = rest end
    if name == "" then say(L("Name fehlt.", "Name missing.")) return end
    -- von Hand eingetragene Namen gelten für deinen Server und deine Fraktion
    remember(name, "manuell", nil, acc, nil, nil, GetRealmName and GetRealmName(), UnitFactionGroup("player"))
    say(L("gemerkt: ", "remembered: ") .. name)
  elseif cmd == "del" or cmd == "loeschen" or cmd == "löschen" then
    local want, found = lower((rest:gsub("%-[^%- ]+$", ""))), false
    for key, c in pairs(db.chars) do
      if lower(c.name) == want and (db.showAll or sameWorld(c)) then
        db.chars[key] = nil; db.hide[key] = true; found = true
      end
    end
    say((found and L("vergessen: ", "forgotten: ") or L("nicht gefunden: ", "not found: ")) .. rest)
  elseif cmd == "auto" then
    db.auto = (db.auto == false)
    say(db.auto and L("Automatisches Einlesen im Hintergrund AN (Freunde alle 60 s, Gilde alle 5 min).",
      "Automatic background scan ON (friends every 60 s, guild every 5 min).")
      or L("Automatisches Einlesen AUS (nur noch bei Ereignissen und /pp scan).",
      "Automatic background scan OFF (only on events and /pp scan)."))
  elseif cmd == "scan" then
    NP.ScanAll()
    local n = 0 for _ in pairs(db.chars) do n = n + 1 end
    say(n .. L(" Namen gemerkt", " names remembered"))
  elseif cmd == "debug" then
    -- zuerst ich selbst, damit die Zeile nicht aus dem Chatfenster rutscht
    local ac = ""
    if GetAutoCompleteRealms then
      local ok, list = pcall(GetAutoCompleteRealms)
      if ok and type(list) == "table" then ac = table.concat(list, ",") end
    end
    say(L("ICH: GetRealmName=", "ME: GetRealmName=") .. tostring(GetRealmName and GetRealmName())
      .. " Normalized=" .. tostring(GetNormalizedRealmName and GetNormalizedRealmName())
      .. " Fraktion=" .. tostring(UnitFactionGroup("player"))
      .. " verbunden=[" .. ac .. "]")
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
      local shown = 0
      for i = 1, (BNGetNumFriends() or 0) do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        local g = info and info.gameAccountInfo
        if g and g.characterName and g.characterName ~= "" then
          local rk = normRealm(g.realmName or g.realmDisplayName)
          local c = db.chars[lower(g.characterName) .. "|" .. (rk or "?")]
          local verdict
          if not c then verdict = "NICHT gespeichert"
          elseif sameWorld(c) then verdict = "PASST"
          else
            verdict = "ausgeblendet: Server " .. (realmOk(c.realmKey) and "ok" or "ANDERS")
              .. ", Fraktion " .. (c.faction == myFaction() and "ok" or ("ANDERS (" .. tostring(c.faction) .. ")"))
          end
          say(g.characterName .. " | realm=" .. tostring(g.realmName) .. " | realmID=" .. tostring(g.realmID)
            .. " | " .. tostring(g.factionName) .. " -> " .. verdict)
          shown = shown + 1
          if shown >= 10 then break end
        end
      end
    end
    say("SendMailNameEditBox=" .. tostring(_G.SendMailNameEditBox ~= nil))
  else
    say(L("Unbekannter Befehl. /pp hilfe", "Unknown command. /pp help"))
  end
end
