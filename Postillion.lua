-- Postillion: Post-Empfänger vervollständigen, auch für Battle.net-Freunde, die offline sind.
-- Idee: Der Charaktername eines Battle.net-Freundes ist nur sichtbar, solange er online ist.
-- Wir merken uns die Charakternamen deiner Freunde (Battle.net-Freunde, optional die normale Freundesliste)
-- und bieten sie im Empfängerfeld der Post an. Gilde, Gruppe, Flüstern und Post-Absender werden nicht erfasst.

local ADDON = "Postillion"
local NP = {}
_G.Postillion = NP

local DE = (GetLocale and GetLocale() == "deDE")
local function L(de, en) return DE and de or en end

local ROWS = 8          -- Zeilen im Vorschlagsfenster
local LIST_ROWS = 15
local WIN_W = 480       -- Breite des Hauptfensters    -- Zeilen in der vollständigen Liste

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
  db.notes = db.notes or {}   -- Notizen: ["tag:<BattleTag>"] oder ["char:<Name|Server>"]
  db.open = db.open or {}     -- aufgeklappte BattleTag-Gruppen in der Liste
  db.profs = db.profs or {}   -- Berufe je Freund (gleicher Schlüssel wie Notizen): {"mining", "tailoring"}
  for k, c in pairs(db.chars) do c.key = c.key or k end
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

-- Servertyp in üblicher Schreibweise (intern kleingeschrieben: pve, rppve ...)
local KIND_NAMES = { pve = "PvE", pvp = "PvP", rppve = "RP-PvE", rppvp = "RP-PvP", rp = "RP" }
local function kindLabel(k)
  if not k or k == "" then return "?" end
  return KIND_NAMES[k] or k:upper()
end
-- Fraktionswappen als eingebettete Textur statt "Horde"/"Allianz" auszuschreiben
local function factionIcon(f)
  if f == "Horde" then return "|TInterface\\TargetingFrame\\UI-PVP-Horde:18:18:0:0:64:64:0:40:0:40|t" end
  if f == "Alliance" then return "|TInterface\\TargetingFrame\\UI-PVP-Alliance:18:18:0:0:64:64:0:40:0:40|t" end
  return "?"
end

local function worldLabel(c)
  return kindLabel(c.realmKey) .. " " .. factionIcon(c.faction)
end

-- Quelle: höhere Zahl = vertrauenswürdiger bzw. wichtiger für die Sortierung
local SRC_RANK = { freund = 5, manuell = 4, liste = 3 }

-- Quellen im selben Spiel wie ich (Freundesliste, Handeinträge): Server und
-- Fraktion sind bekannt oder gleich meiner. Battle.net-Freunde liefern beides selbst mit.
local function remember(name, src, tag, acc, class, level, realm, faction)
  if not name or not db then return end
  -- nur echte Freunde: Battle.net (freund), normale Freundesliste (liste) und Handeinträge (manuell);
  -- Gilde, Gruppe, Flüstern und Post-Absender werden bewusst nicht mehr erfasst
  if src ~= "freund" and src ~= "liste" and src ~= "manuell" then return end
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
  if src == "freund" then c.bn = true elseif src == "liste" then c.fl = true elseif src == "manuell" then c.manual = true end
  if realm and realm ~= "" then c.realm = realm; c.realmKey = rk end
  if fk then c.faction = fk end
  if tag and tag ~= "" then c.tag = tag end
  if acc and acc ~= "" then c.acc = acc end
  if class and class ~= "" then c.class = class end
  if level and tonumber(level) and tonumber(level) > 0 then c.level = tonumber(level) end
  c.key = key
  c.seen = time()
end

-- Alle Namen des Freundes (gleiche BattleTag) für die Anzeige "Alt von ..."
local function friendLabel(c)
  if c.acc and c.acc ~= "" then return c.acc end
  if c.tag then return (c.tag:gsub("#.*$", "")) end
  return nil
end

-- Notizen gelten pro Freund (BattleTag, dann haben alle seine Charaktere dieselbe), sonst pro Charakter
local function noteKeys(c)
  return c.tag and ("tag:" .. c.tag) or nil, "char:" .. (c.key or lower(c.name))
end
local function getNote(c)
  local tk, ck = noteKeys(c)
  return (tk and db.notes[tk]) or db.notes[ck]
end
local function setNote(c, text)
  local tk, ck = noteKeys(c)
  text = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
  if text == "" then text = nil end
  if tk then db.notes[ck] = nil end
  db.notes[tk or ck] = text
end

-- Berufe (Reihenfolge = Anordnung im Bearbeitungsfenster)
local PROFS = {
  { "mining", L("Bergbau", "Mining"), "Trade_Mining" },
  { "herbalism", L("Kräuterkunde", "Herbalism"), "Trade_Herbalism" },
  { "skinning", L("Kürschnerei", "Skinning"), "INV_Misc_Pelt_Wolf_01" },
  { "blacksmithing", L("Schmiedekunst", "Blacksmithing"), "Trade_BlackSmithing" },
  { "engineering", L("Ingenieurskunst", "Engineering"), "Trade_Engineering" },
  { "alchemy", L("Alchemie", "Alchemy"), "Trade_Alchemy" },
  { "tailoring", L("Schneiderei", "Tailoring"), "Trade_Tailoring" },
  { "leatherworking", L("Lederverarbeitung", "Leatherworking"), "Trade_LeatherWorking" },
  { "enchanting", L("Verzauberkunst", "Enchanting"), "Trade_Engraving" },
}
local MAX_PROFS = 2   -- höchstens zwei Hauptberufe pro Freund
local PROF_BY_KEY = {}
for _, p in ipairs(PROFS) do PROF_BY_KEY[p[1]] = p end

local function getProfs(c)
  local tk, ck = noteKeys(c)
  return (tk and db.profs[tk]) or db.profs[ck] or {}
end
local function setProfs(c, list)
  local tk, ck = noteKeys(c)
  while #list > MAX_PROFS do table.remove(list) end
  if #list == 0 then list = nil end
  if tk then db.profs[ck] = nil end
  db.profs[tk or ck] = list
end
-- Eingabetext ("Bergbau, Schmied") -> Schlüsselliste; erkennt Anfang des Namens oder des englischen Schlüssels
local function parseProfs(text)
  local out = {}
  for part in (text or ""):gmatch("[^,;/]+") do
    local q = lower(part:gsub("^%s+", ""):gsub("%s+$", ""))
    if q ~= "" then
      for _, p in ipairs(PROFS) do
        if lower(p[2]):sub(1, #q) == q or p[1]:sub(1, #q) == q then
          if #out < MAX_PROFS then out[#out + 1] = p[1] end
          break
        end
      end
    end
  end
  return out
end

-- Einmalige Aufräumarbeit (0.11.0): Namen aus Gilde, Gruppe, Flüstern und Post entfernen, reine
-- Ingame-Freunde (ohne BattleTag) als solche markieren, Sekundärberufe streichen, auf 2 Berufe kürzen
function NP.Migrate()
  if not db or (db.v or 0) >= 3 then return end
  for key, c in pairs(db.chars) do
    local src = c.src
    if src == "freund" and not c.tag then c.src = "liste"; c.fl = true; c.bn = nil; c.acc = nil
    elseif src == "freund" then c.bn = true
    elseif src == "liste" then c.fl = true
    elseif src == "manuell" then c.manual = true
    else db.chars[key] = nil end
  end
  for key, list in pairs(db.profs) do
    local out = {}
    for _, k in ipairs(list) do if PROF_BY_KEY[k] and #out < MAX_PROFS then out[#out + 1] = k end end
    db.profs[key] = (#out > 0) and out or nil
  end
  db.v = 3
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
              -- ohne BattleTag meldet Forever reine Ingame-Charakterfreunde über diese Liste
              local real = info.battleTag and info.battleTag ~= ""
              remember(g.characterName, real and "freund" or "liste", real and info.battleTag or nil,
                real and info.accountName or nil, g.className, g.characterLevel,
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
        local real = tag and tag ~= ""
        remember(toon, real and "freund" or "liste", real and tag or nil, real and accName or nil) -- alte API: kein Server/Fraktion
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

function NP.ScanAll()
  scanBattleNet(); scanFriendList()
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
  local tg = lower(c.tag or "")
  if tg ~= "" and tg:sub(1, #q) == q then return 2 end
  local note = getNote(c)
  if note and #q >= 2 and lower(note):find(q, 1, true) then return 2 end
  if #q >= 3 then
    for _, k in ipairs(getProfs(c)) do
      local p = PROF_BY_KEY[k]
      if p and (lower(p[2]):sub(1, #q) == q or k:sub(1, #q) == q) then return 2 end
    end
  end
  if #q >= 3 and nm:find(q, 1, true) then return 1 end
  return nil
end

local function visibleSource(c)
  return c.bn or c.manual or (c.fl and db.showIngame) or false
end

function NP.Search(q, max, all)
  q = lower((q or ""):gsub("^%s+", ""):gsub("%s+$", ""))
  local out = {}
  for _, c in pairs(db.chars) do
    local score = matches(c, q)
    -- nur Namen von meinem Server und meiner Fraktion, sonst geht die Post an die falsche Person;
    -- Freunde der normalen Freundesliste nur, wenn in den Einstellungen eingeschaltet
    if score and visibleSource(c) and (all or sameWorld(c)) then
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
  local note = getNote(c)
  if note then parts[#parts + 1] = "|cffffcc5c" .. (#note > 20 and (note:sub(1, 19) .. "…") or note) .. "|r" end
  local lab = friendLabel(c)
  if lab then parts[#parts + 1] = lab end
  if c.level then parts[#parts + 1] = L("Stufe ", "Lvl ") .. c.level end
  return table.concat(parts, " · ")
end

local editNote
local function chooseName(c)
  -- Post-Fenster nicht offen: Klick auf einen Namen öffnet stattdessen Notiz und Berufe
  if not (box and box:IsVisible()) then editNote(c) return end
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

-- Bearbeitungsfenster (Rechtsklick auf einen Namen): Notiz + Berufe
local editFrame
local function buildEdit()
  local f = Panel("PostillionEdit")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetSize(380, 336)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:SetBackdropBorderColor(unpack(C.sun))
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) s:StartMoving() end)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  f:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "PostillionEdit") end
  f.title = Text(f, 15, C.sun); f.title:SetPoint("TOPLEFT", 14, -12)
  f.sub = Text(f, 10, C.dim); f.sub:SetPoint("TOPLEFT", 14, -32)
  local nl = Text(f, 11, C.dim); nl:SetPoint("TOPLEFT", 14, -56); nl:SetText(L("Notiz", "Note"))
  local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  eb:SetHeight(24); eb:SetPoint("TOPLEFT", 14, -72); eb:SetPoint("TOPRIGHT", -14, -72)
  Flat(eb, C.field)
  eb:SetFont(FONT, 12, ""); eb:SetTextColor(unpack(C.text)); eb:SetAutoFocus(false)
  eb:SetMaxLetters(80); eb:SetTextInsets(8, 8, 0, 0)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  eb:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  eb:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.sun)) end)
  eb:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(C.edge)) end)
  f.note = eb
  local pl = Text(f, 11, C.dim); pl:SetPoint("TOPLEFT", 14, -108); pl:SetText(L("Hauptberufe (höchstens 2)", "Main professions (max. 2)"))
  f.sel = {}
  f.btns = {}
  for i, p in ipairs(PROFS) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetSize(112, 48)
    b:SetPoint("TOPLEFT", 14 + col * 120, -126 - row * 54)
    Flat(b, C.card)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(24, 24); b.icon:SetPoint("TOP", 0, -4)
    b.icon:SetTexture("Interface\\Icons\\" .. p[3]); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.lab = Text(b, 9, C.text); b.lab:SetJustifyH("CENTER")
    b.lab:SetPoint("BOTTOM", 0, 4); b.lab:SetText(p[2])
    local function paint()
      if f.sel[p[1]] then b:SetBackdropColor(unpack(C.cardHover)); b:SetBackdropBorderColor(unpack(C.sun)); b.icon:SetAlpha(1)
      else b:SetBackdropColor(unpack(C.card)); b:SetBackdropBorderColor(unpack(C.edge)); b.icon:SetAlpha(0.45) end
    end
    b.paint = paint
    b:SetScript("OnClick", function()
      if f.sel[p[1]] then
        f.sel[p[1]] = nil
      else
        local n = 0
        for _ in pairs(f.sel) do n = n + 1 end
        if n >= MAX_PROFS then f.limit:SetTextColor(unpack(C.red)); return end   -- dritter Beruf wird abgelehnt
        f.sel[p[1]] = true
      end
      f.limit:SetTextColor(unpack(C.dim))
      paint(); f.UpdateLimit()
    end)
    f.btns[i] = b
  end
  f.limit = Text(f, 11, C.dim); f.limit:SetPoint("TOPRIGHT", -14, -108)
  function f.UpdateLimit()
    local n = 0
    for _ in pairs(f.sel) do n = n + 1 end
    f.limit:SetText(n .. "/" .. MAX_PROFS)
  end
  local ok = FlatButton(f, L("Speichern", "Save"), 110, 24, function()
    local c = f.c
    if c then
      setNote(c, f.note:GetText())
      local list = {}
      for _, p in ipairs(PROFS) do if f.sel[p[1]] then list[#list + 1] = p[1] end end
      setProfs(c, list)
      if NP.RefreshAll then NP.RefreshAll() end
    end
    f:Hide()
  end)
  ok:SetPoint("BOTTOMRIGHT", -14, 12)
  ok:SetBackdropColor(unpack(C.sun)); ok:SetBackdropBorderColor(unpack(C.sun)); ok.label:SetTextColor(0.13, 0.1, 0.04)
  ok:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.sun)); self:SetBackdropBorderColor(unpack(C.sun)) end)
  ok:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 0.88, 0.55, 1) end)
  local cancel = FlatButton(f, L("Abbrechen", "Cancel"), 100, 24, function() f:Hide() end)
  cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
  local forget = FlatButton(f, L("Name vergessen", "Forget name"), 120, 24, function()
    local c = f.c
    if c and c.key then
      db.chars[c.key] = nil; db.hide[c.key] = true
      print("|cffffcc5cPostillion:|r " .. L("vergessen: ", "forgotten: ") .. c.name)
      if NP.RefreshAll then NP.RefreshAll() end
    end
    f:Hide()
  end)
  forget:SetPoint("BOTTOMLEFT", 14, 12)
  local close = FlatButton(f, "×", 22, 22, function() f:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)
  return f
end

editNote = function(c)
  editFrame = editFrame or buildEdit()
  local f = editFrame
  f.c = c
  f.title:SetText(c.name)
  f.sub:SetText(friendLabel(c) and (friendLabel(c) .. " · " .. worldLabel(c)) or worldLabel(c))
  f.note:SetText(getNote(c) or ""); f.note:SetCursorPosition(0)
  f.sel = {}
  for _, k in ipairs(getProfs(c)) do f.sel[k] = true end
  for _, b in ipairs(f.btns) do b.paint() end
  f.limit:SetTextColor(unpack(C.dim)); f.UpdateLimit()
  f:Show()
  f.note:SetFocus()
end

-- Zeile: Klassensymbol, Name in Klassenfarbe, rechts Freund/Stufe, bei Fremden Server/Fraktion in Rot
local toggleGroup
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
  b.pi = {}
  for k = 1, MAX_PROFS do
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetSize(14, 14); t:SetPoint("RIGHT", -7 - (k - 1) * 16, 0)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92); t:Hide()
    b.pi[k] = t
  end
  b.info = Text(b, 11, C.dim)
  b.info:SetJustifyH("RIGHT"); b.info:SetPoint("RIGHT", -7, 0)
  b.name:SetPoint("RIGHT", b.info, "LEFT", -6, 0)
  b.name:SetWordWrap(false)
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(C.cardHover)); self:SetBackdropBorderColor(unpack(C.sky)) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.card)); self:SetBackdropBorderColor(unpack(C.card)) end)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if not self.c then return end
    if button == "RightButton" then editNote(self.c)
    elseif self.group then toggleGroup(self.group)
    else onClick(self.c) end
  end)
  b:HookScript("OnEnter", function(self)
    local c = self.c
    if not c then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.group then
      GameTooltip:SetText(c.tag or c.name, unpack(C.sun))
      if c.acc then GameTooltip:AddLine(c.acc, 1, 1, 1) end
      for _, nm in ipairs(self.groupNames or {}) do GameTooltip:AddLine(nm, 0.8, 0.8, 0.85) end
      local gnames = {}
      for _, k in ipairs(getProfs(c)) do if PROF_BY_KEY[k] then gnames[#gnames + 1] = PROF_BY_KEY[k][2] end end
      if #gnames > 0 then GameTooltip:AddLine(table.concat(gnames, ", "), 0.47, 0.87, 0.7, true) end
      local gnote = getNote(c)
      if gnote then GameTooltip:AddLine(gnote, 1, 0.8, 0.36, true) end
      GameTooltip:AddLine(L("Klick = auf-/zuklappen · Rechtsklick = Notiz und Berufe", "Click = expand/collapse · right-click = note and professions"), 0.62, 0.6, 0.72)
      GameTooltip:Show()
      return
    end
    GameTooltip:SetText(c.name, classColor(c.class))
    local lab = friendLabel(c)
    if lab then GameTooltip:AddLine(lab, 1, 1, 1) end
    GameTooltip:AddLine(worldLabel(c), 0.62, 0.6, 0.72)
    local names = {}
    for _, k in ipairs(getProfs(c)) do if PROF_BY_KEY[k] then names[#names + 1] = PROF_BY_KEY[k][2] end end
    if #names > 0 then GameTooltip:AddLine(table.concat(names, ", "), 0.47, 0.87, 0.7, true) end
    local note = getNote(c)
    if note then GameTooltip:AddLine(note, 1, 0.8, 0.36, true) end
    GameTooltip:AddLine(L("Rechtsklick = Notiz und Berufe", "Right-click = note and professions"), 0.62, 0.6, 0.72)
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function fillRow(r, res, first, indent)
  if not res then r.c = nil; r.group = nil; r:Hide() return end
  local c = res.c
  r.c = c
  r.group = nil
  r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", 7 + (indent or 0), 0); r.icon:SetSize(16, 16)
  r.name:SetFont(FONT, 13, "")
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
  local pl = getProfs(c)
  for k = 1, MAX_PROFS do
    local p = pl[k] and PROF_BY_KEY[pl[k]]
    if p then
      r.pi[k]:SetTexture("Interface\\Icons\\" .. p[3]); r.pi[k]:SetDesaturated(not ok); r.pi[k]:Show()
    else r.pi[k]:Hide() end
  end
  r.info:ClearAllPoints()
  r.info:SetPoint("RIGHT", r, "RIGHT", -7 - math.min(#pl, MAX_PROFS) * 16, 0)
  if r.stripe then if first then r.stripe:Show() else r.stripe:Hide() end end
  r:Show()
end

-- Kopfzeile eines Freundes (BattleTag), Klick klappt seine Charaktere auf
local function fillGroupRow(r, g, open)
  local c = g.first
  r.c = c
  r.group = g.key
  r.groupNames = {}
  for _, x in ipairs(g.chars) do r.groupNames[#r.groupNames + 1] = x.c.name end
  r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", 7, 0); r.icon:SetSize(14, 14)
  r.icon:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  r.icon:SetTexCoord(0, 1, 0, 1); r.icon:SetDesaturated(false)
  r.name:SetFont(FONT, 13, "")
  r.name:SetText(g.tag); r.name:SetTextColor(unpack(C.sun))
  local note = getNote(c)
  local cnt = #g.chars .. (#g.chars == 1 and L(" Char", " char") or L(" Chars", " chars"))
  if note then cnt = "|cffffcc5c" .. (#note > 14 and (note:sub(1, 13) .. "…") or note) .. "|r · " .. cnt end
  r.info:SetText(cnt); r.info:SetTextColor(unpack(C.dim))
  local pl = getProfs(c)
  for k = 1, MAX_PROFS do
    local p = pl[k] and PROF_BY_KEY[pl[k]]
    if p then r.pi[k]:SetTexture("Interface\\Icons\\" .. p[3]); r.pi[k]:SetDesaturated(false); r.pi[k]:Show()
    else r.pi[k]:Hide() end
  end
  r.info:ClearAllPoints()
  r.info:SetPoint("RIGHT", r, "RIGHT", -7 - math.min(#pl, MAX_PROFS) * 16, 0)
  if r.stripe then r.stripe:Hide() end
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

local refreshList
local listOffset = 0
local listItems = {}

-- Anzeigeliste: Freunde (BattleTag) als aufklappbare Gruppen, Namen ohne BattleTag einzeln
local function buildItems(q)
  local res = NP.Search(q, nil, db.showAll)
  local groups, items = {}, {}
  for _, r in ipairs(res) do
    local c = r.c
    if c.tag then
      local g = groups[c.tag]
      if not g then
        g = { kind = "group", key = "tag:" .. c.tag, tag = c.tag, chars = {}, score = r.score, first = c, name = lower(c.tag) }
        groups[c.tag] = g
        items[#items + 1] = g
      end
      g.chars[#g.chars + 1] = r
      if r.score > g.score then g.score = r.score end
    else
      items[#items + 1] = { kind = "char", res = r, score = r.score, name = lower(c.name) }
    end
  end
  table.sort(items, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.name < b.name
  end)
  local searching = (q or ""):gsub("%s", "") ~= ""
  local flat, nGroups = {}, 0
  for _, it in ipairs(items) do
    if it.kind == "group" then
      nGroups = nGroups + 1
      local open = searching or db.open[it.key]
      flat[#flat + 1] = { kind = "group", g = it, open = open }
      if open then
        for _, r in ipairs(it.chars) do flat[#flat + 1] = { kind = "char", res = r, indent = 18 } end
      end
    else
      flat[#flat + 1] = it
    end
  end
  return flat, nGroups, #res
end

toggleGroup = function(key)
  db.open[key] = (not db.open[key]) or nil
  if listFrame and listFrame:IsShown() then refreshList() end
end

function refreshList()
  local q = listFrame.search:GetText() or ""
  listFrame.placeholder:SetShown(q == "" and not listFrame.search:HasFocus())
  local nGroups, nChars
  listItems, nGroups, nChars = buildItems(q)
  local maxOff = math.max(0, #listItems - LIST_ROWS)
  if listOffset > maxOff then listOffset = maxOff end
  if listOffset < 0 then listOffset = 0 end
  for i = 1, LIST_ROWS do
    local it, r = listItems[listOffset + i], listRows[i]
    if not it then fillRow(r, nil)
    elseif it.kind == "group" then fillGroupRow(r, it.g, it.open)
    else fillRow(r, it.res, false, it.indent) end
  end
  listFrame.count:SetText(nGroups .. L(" Freunde, ", " friends, ") .. nChars .. L(" Namen", " names"))
  -- schmaler Rollbalken rechts
  local track = listFrame.track
  if #listItems > LIST_ROWS then
    local h = track:GetHeight()
    local thumbH = math.max(18, h * LIST_ROWS / #listItems)
    listFrame.thumb:SetHeight(thumbH)
    listFrame.thumb:ClearAllPoints()
    listFrame.thumb:SetPoint("TOP", track, "TOP", 0, -((h - thumbH) * listOffset / math.max(1, maxOff)))
    track:Show()
  else
    track:Hide()
  end
  listFrame.empty:SetShown(#listItems == 0)
end

function NP.RefreshAll()
  if listFrame and listFrame:IsShown() then refreshList() end
  if sug and sug:IsShown() then showSuggestions() end
end

local function buildUI()
  box = _G.SendMailNameEditBox
  if not box or NP.uiBuilt then return end
  NP.uiBuilt = true

  -- Vorschlagsfenster direkt unter dem Empfängerfeld
  sug = Panel("PostillionSuggest")
  sug:SetFrameStrata("DIALOG")
  sug:SetWidth(400)
  sug:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -2)
  sug:SetBackdropBorderColor(unpack(C.sun))
  sug:Hide()
  rows = {}
  for i = 1, ROWS do rows[i] = makeRow(sug, i, chooseName) end
  local hint = Text(sug, 10, C.dim)
  hint:SetPoint("BOTTOMLEFT", 8, 5)
  hint:SetText(L("Tab = erster Treffer · Klick = übernehmen · Rechtsklick = Notiz/Berufe", "Tab = first match · click = pick · right-click = note/professions"))

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

  if MailFrame then MailFrame:HookScript("OnHide", function() sug:Hide() end) end
end

----------------------------------------------------------------------
-- Hauptfenster (Reiter Freunde / Einstellungen) und Minimap-Button
----------------------------------------------------------------------

local pageList, pageSet
local tabBtns = {}
local checks = {}
local mm
local setInfo

local function Check(parent, label, get, set)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(WIN_W - 24, 20)
  b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
  b.box:SetSize(16, 16); b.box:SetPoint("LEFT", 0, 0)
  Flat(b.box, C.field)
  b.mark = b.box:CreateTexture(nil, "OVERLAY")
  b.mark:SetSize(8, 8); b.mark:SetPoint("CENTER", 0, 0)
  b.mark:SetColorTexture(unpack(C.sun))
  b.text = Text(b, 12)
  b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
  b.text:SetText(label)
  function b:Refresh() self.mark:SetShown(get() and true or false) end
  b:SetScript("OnClick", function(self) set(not get()); self:Refresh() end)
  b:SetScript("OnEnter", function(self) self.box:SetBackdropBorderColor(unpack(C.sun)) end)
  b:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(unpack(C.edge)) end)
  checks[#checks + 1] = b
  return b
end

function NP.RefreshSettings()
  for _, c in ipairs(checks) do c:Refresh() end
  if setInfo then
    local nChars, tags, nTags = 0, {}, 0
    for _, c in pairs(db.chars) do
      nChars = nChars + 1
      if c.tag and not tags[c.tag] then tags[c.tag] = true; nTags = nTags + 1 end
    end
    setInfo:SetText(nChars .. L(" Namen gemerkt, davon ", " names remembered, ") .. nTags .. L(" Freunde mit BattleTag", " friends with a BattleTag"))
  end
end

local function selectTab(which)
  NP.tab = which
  if not pageList then return end
  pageList:SetShown(which == "list"); pageSet:SetShown(which == "settings")
  for k, b in pairs(tabBtns) do
    if k == which then
      b:SetBackdropBorderColor(unpack(C.sun)); b:SetBackdropColor(unpack(C.cardHover)); b.label:SetTextColor(unpack(C.sun))
    else
      b:SetBackdropBorderColor(unpack(C.edge)); b:SetBackdropColor(unpack(C.card)); b.label:SetTextColor(unpack(C.text))
    end
  end
  if which == "list" then refreshList() else NP.RefreshSettings() end
end

local function placeWindow()
  listFrame:ClearAllPoints()
  local w = db.winPos
  if w and w[1] then
    listFrame:SetPoint(w[1], UIParent, w[2], w[3], w[4])
  elseif MailFrame and MailFrame:IsShown() then
    listFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 6, -20)
  else
    listFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  end
end

local function buildMain()
  if listFrame then return end
  local H = 40 + 28 + 34 + LIST_ROWS * ROW_H + 40
  listFrame = Panel("PostillionList")
  listFrame:SetFrameStrata("DIALOG")
  listFrame:SetSize(WIN_W, H)
  listFrame:SetMovable(true); listFrame:EnableMouse(true)
  listFrame:RegisterForDrag("LeftButton")
  listFrame:SetScript("OnDragStart", function(s) s:StartMoving() end)
  listFrame:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    db.winPos = { p, rp, x, y }
  end)
  listFrame:EnableMouseWheel(true)
  listFrame:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "PostillionList") end

  local title = Text(listFrame, 15, C.sun)
  title:SetPoint("TOPLEFT", 12, -11); title:SetText("Postillion")
  local sub = Text(listFrame, 10, C.dim)
  sub:SetPoint("LEFT", title, "RIGHT", 8, -1); sub:SetText(L("Post an Freunde, auch offline", "Mail to friends, even offline"))
  local close = FlatButton(listFrame, "×", 22, 22, function() listFrame:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)

  -- Reiter
  local function tab(key, label, x)
    local b = FlatButton(listFrame, label, 120, 22, function() selectTab(key) end)
    b:SetPoint("TOPLEFT", x, -36)
    b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
    tabBtns[key] = b
  end
  tab("list", L("Freunde", "Friends"), 12)
  tab("settings", L("Einstellungen", "Settings"), 138)

  pageList = CreateFrame("Frame", nil, listFrame)
  pageList:SetPoint("TOPLEFT", 0, -62); pageList:SetPoint("BOTTOMRIGHT", 0, 0)
  pageSet = CreateFrame("Frame", nil, listFrame)
  pageSet:SetPoint("TOPLEFT", 0, -62); pageSet:SetPoint("BOTTOMRIGHT", 0, 0)
  pageSet:Hide()

  ------------------------------------------------------------ Reiter Freunde
  local search = CreateFrame("EditBox", nil, pageList, "BackdropTemplate")
  search:SetHeight(24); search:SetPoint("TOPLEFT", 8, -6); search:SetPoint("TOPRIGHT", -8, -6)
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
  listFrame.placeholder:SetText(L("Name, Nachname, Freund oder Beruf suchen ...", "Search name, last name, friend or profession ..."))

  local holder = CreateFrame("Frame", nil, pageList)
  holder:SetPoint("TOPLEFT", 0, -36); holder:SetPoint("BOTTOMRIGHT", 0, 30)
  listRows = {}
  for i = 1, LIST_ROWS do listRows[i] = makeRow(holder, i, chooseName, 0) end
  for i = 1, LIST_ROWS do listRows[i]:SetPoint("RIGHT", holder, "RIGHT", -13, 0) end
  listFrame.empty = Text(holder, 12, C.dim)
  listFrame.empty:SetPoint("TOP", 0, -30); listFrame.empty:SetJustifyH("CENTER")
  listFrame.empty:SetText(L("Noch keine passenden Namen.\nFreunde werden gemerkt, sobald sie online sind.",
    "No matching names yet.\nFriends are remembered once they are online."))

  local track = CreateFrame("Frame", nil, holder)
  track:SetWidth(4); track:SetPoint("TOPRIGHT", -5, -2); track:SetPoint("BOTTOMRIGHT", -5, 2)
  local tbg = track:CreateTexture(nil, "BACKGROUND"); tbg:SetAllPoints(); tbg:SetColorTexture(unpack(C.field))
  listFrame.thumb = track:CreateTexture(nil, "ARTWORK")
  listFrame.thumb:SetWidth(4); listFrame.thumb:SetColorTexture(unpack(C.edge))
  listFrame.track = track

  listFrame.count = Text(pageList, 10, C.dim)
  listFrame.count:SetPoint("BOTTOMLEFT", 12, 10)
  local hintR = Text(pageList, 10, C.dim)
  hintR:SetPoint("BOTTOMRIGHT", -12, 10)
  hintR:SetText(L("Klick = Name/Aufklappen · Rechtsklick = Notiz", "Click = name/expand · right-click = note"))

  ------------------------------------------------------- Reiter Einstellungen
  local function head(text, y)
    local t = Text(pageSet, 12, C.sun)
    t:SetPoint("TOPLEFT", 12, y); t:SetText(text)
    local line = pageSet:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.edge)); line:SetHeight(1)
    line:SetPoint("TOPLEFT", 12, y - 16); line:SetPoint("TOPRIGHT", -12, y - 16)
  end
  head(L("Allgemein", "General"), -8)
  local function subline(text, y)
    local t = Text(pageSet, 10, C.dim)
    t:SetPoint("TOPLEFT", 36, y); t:SetWidth(WIN_W - 48); t:SetText(text)
  end
  local c1 = Check(pageSet, L("Minimap-Button anzeigen", "Show minimap button"),
    function() return not db.mmHide end,
    function(v) db.mmHide = not v; if mm then mm:SetShown(v) end end)
  c1:SetPoint("TOPLEFT", 12, -30)
  local c2 = Check(pageSet, L("Automatisch im Hintergrund einlesen", "Scan automatically in the background"),
    function() return db.auto ~= false end,
    function(v) db.auto = v end)
  c2:SetPoint("TOPLEFT", 12, -52)
  subline(L("Liest deine Freunde jede Minute selbst ein.", "Reads your friends by itself every minute."), -70)
  local c3 = Check(pageSet, L("Namen anderer Server/Fraktionen in der Liste zeigen", "Show names of other realms/factions in the list"),
    function() return db.showAll and true or false end,
    function(v) db.showAll = v or nil; listOffset = 0; NP.RefreshAll() end)
  c3:SetPoint("TOPLEFT", 12, -90)
  local c4 = Check(pageSet, L("Freunde der normalen Freundesliste anzeigen", "Show friends of the regular friends list"),
    function() return db.showIngame and true or false end,
    function(v) db.showIngame = v or nil; listOffset = 0; NP.RefreshAll() end)
  c4:SetPoint("TOPLEFT", 12, -112)
  subline(L("Reine Ingame-Charakterfreunde. Battle.net-Freunde sind immer sichtbar.", "Pure in-game character friends. Battle.net friends are always shown."), -130)

  head(L("Namen", "Names"), -154)
  setInfo = Text(pageSet, 11, C.dim)
  setInfo:SetPoint("TOPLEFT", 12, -176)
  local scan = FlatButton(pageSet, L("Jetzt einlesen", "Scan now"), 130, 24, function()
    NP.ScanAll(); NP.RefreshSettings()
  end)
  scan:SetPoint("TOPLEFT", 12, -196)
  local diag = FlatButton(pageSet, L("Diagnose in den Chat", "Diagnostics to chat"), 160, 24, function()
    SlashCmdList.POSTILLION("debug")
  end)
  diag:SetPoint("LEFT", scan, "RIGHT", 8, 0)

  local addL = Text(pageSet, 11, C.dim)
  addL:SetPoint("TOPLEFT", 12, -230)
  addL:SetText(L("Namen von Hand merken (für deinen Server und deine Fraktion)", "Remember a name by hand (for your realm and faction)"))
  local addE = CreateFrame("EditBox", nil, pageSet, "BackdropTemplate")
  addE:SetSize(250, 24); addE:SetPoint("TOPLEFT", 12, -248)
  Flat(addE, C.field)
  addE:SetFont(FONT, 12, ""); addE:SetTextColor(unpack(C.text)); addE:SetAutoFocus(false); addE:SetTextInsets(8, 8, 0, 0)
  addE:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  addE:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.sun)) end)
  addE:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(C.edge)) end)
  local function doAdd()
    local n = addE:GetText() or ""
    if n:gsub("%s", "") == "" then return end
    remember(n, "manuell", nil, nil, nil, nil, GetRealmName and GetRealmName(), UnitFactionGroup("player"))
    addE:SetText(""); addE:ClearFocus()
    print("|cffffcc5cPostillion:|r " .. L("gemerkt: ", "remembered: ") .. n)
    NP.RefreshSettings()
  end
  addE:SetScript("OnEnterPressed", doAdd)
  local addB = FlatButton(pageSet, L("Hinzufügen", "Add"), 100, 24, doAdd)
  addB:SetPoint("LEFT", addE, "RIGHT", 8, 0)

  head(L("Befehle", "Commands"), -282)
  local cmds = Text(pageSet, 10, C.dim)
  cmds:SetPoint("TOPLEFT", 12, -304); cmds:SetWidth(WIN_W - 24); cmds:SetJustifyV("TOP")
  if cmds.SetSpacing then cmds:SetSpacing(3) end
  cmds:SetText(table.concat({
    "|cffffcc5c/pp|r  " .. L("Fenster öffnen", "open the window"),
    "|cffffcc5c/pp einstellungen|r  " .. L("diesen Reiter öffnen", "open this tab"),
    "|cffffcc5c/pp liste [Teil]|r  " .. L("Namen im Chat auflisten", "list names in chat"),
    "|cffffcc5c/pp note Name | Text|r  " .. L("Notiz setzen (Rechtsklick geht auch)", "set a note (right-click works too)"),
    "|cffffcc5c/pp beruf Name | Beruf, Beruf|r  " .. L("bis zu 2 Berufe setzen", "set up to 2 professions"),
    "|cffffcc5c/pp add Name|r  " .. L("Namen merken", "remember a name"),
    "|cffffcc5c/pp del Name|r  " .. L("Namen vergessen", "forget a name"),
    "|cffffcc5c/pp scan|r  " .. L("jetzt einlesen", "scan now"),
    "|cffffcc5c/pp auto · /pp alle · /pp minimap|r  " .. L("Schalter wie oben", "toggles as above"),
    "|cffffcc5c/pp debug|r  " .. L("Diagnose in den Chat", "diagnostics to chat"),
  }, "\n"))

  listFrame:SetScript("OnMouseWheel", function(_, d)
    if NP.tab ~= "list" then return end
    listOffset = listOffset - d * 3
    refreshList()
  end)
  listFrame:SetScript("OnShow", function()
    NP.ScanAll()
    selectTab(NP.tab or "list")
  end)
end

function NP.Open(which)
  if not db then return end
  buildMain()
  which = which or NP.tab or "list"
  if listFrame:IsShown() and NP.tab == which then listFrame:Hide() return end
  if not listFrame:IsShown() then placeWindow(); listFrame:Show() end
  selectTab(which)
end
function NP.ToggleList() NP.Open("list") end

-- Minimap-Button: Linksklick Freunde, Rechtsklick Einstellungen, Ziehen verschiebt ihn am Rand
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function placeMinimap()
  if not mm then return end
  local a = math.rad(db.mmAngle or 200)
  local r = (Minimap:GetWidth() / 2) + 5
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function NP.BuildMinimap()
  if mm or not Minimap then return end
  mm = CreateFrame("Button", "PostillionMinimapButton", Minimap)
  mm:SetSize(31, 31); mm:SetFrameStrata("MEDIUM"); mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp"); mm:RegisterForDrag("LeftButton")
  local bg = mm:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20); bg:SetPoint("TOPLEFT", 7, -5); bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = mm:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17); icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture("Interface\\Icons\\INV_Letter_15"); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local border = mm:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then NP.Open("settings") else NP.Open("list") end
  end)
  mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      db.mmAngle = math.deg(atan2(py / s - my, px / s - mx))
      placeMinimap()
    end)
  end)
  mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Postillion", unpack(C.sun))
    local n = 0
    for _ in pairs(db.chars) do n = n + 1 end
    GameTooltip:AddLine(n .. L(" Namen gemerkt", " names remembered"), 0.62, 0.6, 0.72)
    GameTooltip:AddLine(L("Linksklick: Freunde und Notizen", "Left-click: friends and notes"), 1, 1, 1)
    GameTooltip:AddLine(L("Rechtsklick: Einstellungen", "Right-click: settings"), 1, 1, 1)
    GameTooltip:AddLine(L("Ziehen: Button verschieben", "Drag: move the button"), 0.62, 0.6, 0.72)
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimap()
  mm:SetShown(not db.mmHide)
end


----------------------------------------------------------------------
-- Ereignisse
----------------------------------------------------------------------

local f = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED",
  "BN_FRIEND_ACCOUNT_ONLINE", "BN_CONNECTED", "FRIENDLIST_UPDATE", "MAIL_SHOW" }) do
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
-- bereit), danach jede Minute. Ausschalten: /pp auto
local AUTO_FRIENDS = 60
local function autoStep()
  if not db or db.auto == false then return end
  scanBattleNet(); scanFriendList()
end
function NP.StartAuto()
  if NP.autoStarted then return end
  NP.autoStarted = true
  for _, t in ipairs({ 5, 20 }) do C_Timer.After(t, autoStep) end
  if C_Timer.NewTicker then C_Timer.NewTicker(AUTO_FRIENDS, autoStep) end
end

f:SetScript("OnEvent", function(_, event, a1, ...)
  if event == "ADDON_LOADED" then
    if a1 == ADDON then initDB(); NP.Migrate() end
    return
  end
  if not db then return end
  if event == "PLAYER_LOGIN" then
    NP.ScanAll()
    NP.StartAuto()
    NP.BuildMinimap()
  elseif event == "MAIL_SHOW" then
    buildUI()
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
  if cmd == "" then
    NP.Open("list")
  elseif cmd == "einstellungen" or cmd == "settings" or cmd == "config" then
    NP.Open("settings")
  elseif cmd == "minimap" then
    db.mmHide = (not db.mmHide) or nil
    if mm then mm:SetShown(not db.mmHide) end
    say(db.mmHide and L("Minimap-Button AUS.", "Minimap button OFF.") or L("Minimap-Button AN.", "Minimap button ON."))
  elseif cmd == "hilfe" or cmd == "help" then
    say(L("Merkt Charakternamen von Freunden und vervollständigt sie im Post-Feld, auch offline.",
          "Remembers friends' character names and autocompletes them in the mail field, also offline."))
    say(L("/pp liste [Teil]  zeigt gemerkte Namen", "/pp list [part]  shows remembered names"))
    say(L("/pp add <Name> [Freundesname]  Name von Hand merken", "/pp add <name> [friend name]  remember a name by hand"))
    say(L("/pp beruf <Name> | <Beruf, Beruf>  Berufe eintragen (leer = löschen)",
          "/pp prof <name> | <profession, profession>  set professions (empty = delete)"))
    say(L("/pp note <Name> | <Text>  Notiz zu einem Freund (leer = löschen; im Fenster: Rechtsklick)",
          "/pp note <name> | <text>  note for a friend (empty = delete; in the window: right-click)"))
    say(L("/pp del <Name>  Namen vergessen", "/pp del <name>  forget a name"))
    say(L("/pp alle  Liste auch mit Namen anderer Server/Fraktionen (grau) ein- oder ausschalten",
          "/pp all  toggle showing names from other realms/factions (grey) in the list"))
    say(L("/pp auto  automatisches Einlesen alle 60 s ein/aus (Standard: an)",
          "/pp auto  toggle automatic scan every 60 s (default: on)"))
    say(L("/pp scan  Freunde jetzt einlesen", "/pp scan  read friends now"))
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
      say(r.c.name .. "  |cff999999" .. worldLabel(r.c) .. " " .. describe(r.c) .. " [" .. tostring(r.c.src) .. "]|r")
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
  elseif cmd == "note" or cmd == "notiz" then
    local name, text = rest:match("^(.-)%s*|%s*(.*)$")
    if not name then name, text = rest, "" end
    local want = lower((name:gsub("%-[^%- ]+$", "")))
    local hit
    for _, c in pairs(db.chars) do
      if lower(c.name) == want and (db.showAll or sameWorld(c)) then hit = c break end
    end
    if not hit then say(L("nicht gefunden: ", "not found: ") .. name) return end
    setNote(hit, text)
    say((text ~= "" and L("Notiz gespeichert für ", "note saved for ") or L("Notiz gelöscht für ", "note removed for ")) .. hit.name)
  elseif cmd == "beruf" or cmd == "berufe" or cmd == "prof" then
    local name, text = rest:match("^(.-)%s*|%s*(.*)$")
    if not name then name, text = rest, "" end
    local want = lower((name:gsub("%-[^%- ]+$", "")))
    local hit
    for _, c in pairs(db.chars) do
      if lower(c.name) == want and (db.showAll or sameWorld(c)) then hit = c break end
    end
    if not hit then say(L("nicht gefunden: ", "not found: ") .. name) return end
    local list = parseProfs(text)
    setProfs(hit, list)
    local names = {}
    for _, k in ipairs(list) do names[#names + 1] = PROF_BY_KEY[k][2] end
    say(hit.name .. ": " .. (#names > 0 and table.concat(names, ", ") or L("keine Berufe", "no professions")))
  elseif cmd == "auto" then
    db.auto = (db.auto == false)
    say(db.auto and L("Automatisches Einlesen im Hintergrund AN (Freunde jede Minute).",
      "Automatic background scan ON (friends every minute).")
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
