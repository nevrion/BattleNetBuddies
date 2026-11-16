<p align="center"><img src="docs/logo.png" alt="Battle.net Buddies" width="160"></p>

# Battle.net Buddies

**Deutsch** · [English](#english)

*Früher "Postillion". Die alten Befehle `/pp` und `/postillion` funktionieren weiter, gespeicherte Daten werden übernommen.*

Post-Empfänger-Vervollständigung für **WoW Forever** (Interface 16001): Battle.net Buddies merkt sich die Charakternamen deiner Battle.net-Freunde und vervollständigt sie im Post-Fenster, **auch wenn der Freund offline ist**. Befehl im Spiel: `/bnb`

**Status:** Beta. Das Addon ist bisher nur offline (Simulation) und in ersten Tests im Spiel geprüft, Fehlermeldungen sind willkommen (siehe unten).

## Das Problem

Mit Vor- und Nachnamen und dem neuen Freundessystem kennt das Spiel den Charakternamen eines Battle.net-Freundes nur, solange er **online** ist. Die eingebaute Autovervollständigung im Post-Fenster greift nur bei Online-Charakteren, und den Charakter zusätzlich in die Freundesliste zu setzen scheitert an "ihr seid bereits befreundet". Offline Post zu schicken heißt, sich den vollen Namen merken zu müssen.

## Die Lösung

Battle.net Buddies liest im Hintergrund die Charakternamen **deiner Freunde** mit und speichert sie dauerhaft: Battle.net-Freunde (immer) und Freunde der normalen Freundesliste (in den Einstellungen einschaltbar). Gilde, Gruppe, Flüstern und Post-Absender werden bewusst **nicht** erfasst, damit nur echte Freunde in der Liste stehen. Ein Freund muss **einmal online gesehen** worden sein, danach ist sein Name im Post-Fenster verfügbar.

## Installation

1. Unter [Releases](../../releases) die Datei `BattleNetBuddies-x.y.z-forever.zip` herunterladen.
2. Den Ordner `BattleNetBuddies` aus dem Zip nach `World of Warcraft/<Spielversion>/Interface/AddOns/` kopieren.
3. Spiel starten oder `/reload`.

**WoWUp:** Unter "Addons holen" die Spielversion Forever wählen, "Von URL installieren" und `https://github.com/nevrion/BattleNetBuddies` einfügen. (WoWUp erkennt die Forever-Datei am Zusatz `-forever` im Zip-Namen.)

## Benutzung

- **Minimap-Button:** Linksklick öffnet das Hauptfenster mit der Freundesliste, Rechtsklick die **Einstellungen**, Ziehen verschiebt den Button am Minimaprand. Das Hauptfenster ist unabhängig vom Post-Fenster, öffnet sich auch mit `/bnb` und lässt sich verschieben (die Position wird gemerkt). Ohne offenes Post-Fenster öffnet ein Klick auf einen Namen Notiz und Berufe, mit offenem Post-Fenster übernimmt er den Namen.
- **Einstellungen:** Alles, was es als Befehl gibt, geht auch per Klick: Minimap-Button, automatisches Einlesen und Namen anderer Server/Fraktionen als Schalter, "Jetzt einlesen", Namen von Hand hinzufügen, Diagnose in den Chat, dazu eine Übersicht der Befehle. Namen vergessen geht im Bearbeitungsfenster (Rechtsklick auf einen Namen).
- **Im Post-Fenster** im Feld "An" ein paar Buchstaben tippen, auch nur vom **Nachnamen** oder vom Namen des Freundes. Es erscheint ein Vorschlagsfenster, **Tab** übernimmt den ersten Treffer, ein Klick übernimmt den gewählten Namen.
- Der Knopf **Freunde** neben dem Feld öffnet die komplette Liste mit Suche, Klassensymbolen und Mausrad-Blättern. Die Liste ist **nach BattleTag gruppiert**: Jeder Freund steht als Zeile mit seinem BattleTag, ein Klick klappt seine Charaktere auf (Zähler, Notiz und Berufe stehen schon in der Kopfzeile). Beim Suchen klappen die Treffer von selbst auf, welche Freunde aufgeklappt sind, wird gemerkt. Ingame-Freunde und von Hand eingetragene Namen (ohne BattleTag) stehen einzeln darunter.
- **Notizen und Berufe:** **Rechtsklick** auf einen Namen (Liste oder Vorschlag) öffnet ein Fenster mit einer Notiz (z.B. "tauscht gern Erz") und den Berufen des Freundes zum Anklicken: bis zu **2 Hauptberufe** (Bergbau, Kräuterkunde, Kürschnerei, Schmiedekunst, Ingenieurskunst, Alchemie, Schneiderei, Lederverarbeitung, Verzauberkunst; Sekundärberufe gibt es nicht). Beides gilt für alle Charaktere desselben Freundes, die Berufe erscheinen als Symbole in der Zeile, alles steht im Tooltip und ist durchsuchbar: "schmied" findet alle Freunde, die Schmiedekunst haben. Das Spiel verrät die Berufe eines Freundes nicht, du trägst sie selbst ein.
- **Server und Fraktion sind abgesichert:** Vorgeschlagen werden nur Namen, die zu deinem Servertyp (PvE, RP-PvE, PvP ...) und deiner Fraktion passen. Gleichnamige Charaktere auf einem anderen Servertyp oder in der anderen Fraktion werden nicht angeboten, damit Post nicht an die falsche Person geht. Die Nummern in den Servernamen (z.B. `Realm1`, `Realm5`) sind nur Layer desselben Servers und werden ignoriert. Gespeichert wird alles, angezeigt nur, was passt (in der Liste lässt sich "andere Server/Fraktionen" einblenden, grau und mit Warnung).
- **Automatisch:** Nach dem Login und danach alle 60 Sekunden liest Battle.net Buddies deine Freunde jede Minute selbst ein.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/bnb` | Hauptfenster öffnen |
| `/bnb einstellungen` | Einstellungen öffnen |
| `/bnb minimap` | Minimap-Button ein- oder ausblenden |
| `/bnb hilfe` | Befehle im Chat |
| `/bnb liste [Teil]` | gemerkte Namen anzeigen |
| `/bnb note <Name> \| <Text>` | Notiz zu einem Freund setzen (leerer Text löscht) |
| `/bnb beruf <Name> \| <Beruf, Beruf>` | Berufe eines Freundes eintragen (leer löscht) |
| `/bnb add <Name>` | Namen von Hand merken (gilt für deinen Server und deine Fraktion) |
| `/bnb del <Name>` | Namen vergessen |
| `/bnb scan` | Freunde sofort einlesen |
| `/bnb auto` | automatisches Einlesen ein- oder ausschalten (Standard: an) |
| `/bnb alle` | Liste auch mit Namen anderer Server/Fraktionen |
| `/bnb debug` | zeigt, was die Battle.net-Schnittstelle liefert und warum ein Freund passt oder ausgeblendet wird |

## Erweiterungen

Battle.net Buddies hat eine kleine Schnittstelle (`BattleNetBuddies.API`) für Erweiterungen, z.B. **Battle.net Buddies Craft**, das Berufe automatisch unter Freunden austauscht. Erweiterungen können eigene Reiter im Hauptfenster anlegen, Berufe und Tooltip-Zeilen liefern und Freunde abfragen.

## Datenschutz

Alle Daten liegen lokal in deiner `SavedVariables`-Datei (`Battle.net BuddiesDB`). Das Addon sendet nichts an Dritte.

## Fehler melden

Vor dem Test `/console scriptErrors 1` eingeben, dann erscheint bei einem Lua-Fehler ein Fenster. Bitte den Text daraus als [Issue](../../issues) melden, dazu die Ausgabe von `/bnb debug` (Namen von Freunden bitte unkenntlich machen).

## Grenzen

- Ein Freund, den das Addon nie online gesehen hat, ist unbekannt. Mit `/bnb add` lässt er sich von Hand nachtragen.
- Das Addon ist für die Namensstruktur von WoW Forever gebaut (Server wie `...Realm5PvE`); auf anderen Spielversionen wird der gesamte Servername verglichen.

## Lizenz

[MIT](LICENSE). Du darfst das Addon frei nutzen, ändern und weitergeben, der Urhebervermerk muss bleiben.

---

# English

*Formerly "Postillion". The old commands `/pp` and `/postillion` still work, saved data is carried over.*

Mail recipient autocomplete for **WoW Forever** (Interface 16001): Battle.net Buddies remembers the character names of your Battle.net friends and completes them in the mail window, **even when the friend is offline**. In-game command: `/bnb`

**Status:** Beta. Checked offline (simulation) and in first in-game tests so far; bug reports are welcome (see below).

## The problem

With first and last names and the new friends system, the game only exposes a Battle.net friend's character name while they are **online**. The built-in mail autocomplete only works for online characters, and adding the character to the friends list fails with "you are already friends". Mailing an offline friend means remembering their full name.

## The solution

Battle.net Buddies quietly records the character names of **your friends** and stores them permanently: Battle.net friends (always) and friends of the regular friends list (can be switched on in the settings). Guild, group, whispers and mail senders are deliberately **not** recorded, so only real friends are in the list. A friend has to be **seen online once**; after that the name is available in the mail window.

## Installation

1. Download `BattleNetBuddies-x.y.z-forever.zip` from [Releases](../../releases).
2. Copy the `BattleNetBuddies` folder from the zip to `World of Warcraft/<game version>/Interface/AddOns/`.
3. Start the game or `/reload`.

**WoWUp:** In "Get Addons" choose the Forever game version, use "Install from URL" and paste `https://github.com/nevrion/BattleNetBuddies`. (WoWUp recognizes the Forever file by the `-forever` suffix in the zip name.)

## Usage

- **Minimap button:** left-click opens the main window with the friends list, right-click opens the **settings**, dragging moves the button around the minimap. The main window works independently of the mail window, also opens with `/bnb` and can be moved (position is remembered). With the mail window closed, clicking a name opens note and professions; with it open, it picks the name.
- **Settings:** everything that exists as a command also works by click: minimap button, automatic scan and names of other realms/factions as toggles, "Scan now", add a name by hand, diagnostics to chat, plus an overview of the commands. Forgetting a name is in the edit window (right-click a name).
- **In the mail window**, type a few letters into the "To" field, also just of the **last name** or of the friend's name. A suggestion popup appears, **Tab** accepts the first match, a click picks the selected name.
- The **Friends** button next to the field opens the full list with search, class icons and mouse-wheel scrolling. The list is **grouped by BattleTag**: each friend is one row with their BattleTag, a click expands their characters (count, note and professions are already shown in the header row). While searching, matches expand automatically, and which friends are expanded is remembered. In-game friends and names added by hand (without a BattleTag) are listed individually below.
- **Notes and professions:** **right-click** a name (list or suggestion) to open a window with a note (e.g. "likes to trade ore") and the friend's professions to click: up to **2 main professions** (Mining, Herbalism, Skinning, Blacksmithing, Engineering, Alchemy, Tailoring, Leatherworking, Enchanting; no secondary professions). Both apply to all characters of the same friend, professions show as icons in the row, everything is in the tooltip and searchable: "blacksm" finds every friend who has Blacksmithing. The game does not reveal a friend's professions, so you enter them yourself.
- **Realm and faction are safeguarded:** only names matching your realm type (PvE, RP-PvE, PvP ...) and your faction are suggested. Same-named characters on another realm type or in the other faction are never offered, so mail does not reach the wrong person. The numbers in realm names (e.g. `Realm1`, `Realm5`) are just layers of the same server and are ignored. Everything is stored, only matching entries are shown (the list can show "other realms/factions", greyed out with a warning).
- **Automatic:** after login and then every 60 seconds Battle.net Buddies reads your friends by itself every minute.

## Commands

| Command | Effect |
|---|---|
| `/bnb` | open the main window |
| `/bnb settings` | open the settings |
| `/bnb minimap` | show or hide the minimap button |
| `/bnb help` | commands in chat |
| `/bnb list [part]` | show remembered names |
| `/bnb note <name> \| <text>` | set a note for a friend (empty text deletes) |
| `/bnb prof <name> \| <profession, profession>` | set a friend's professions (empty deletes) |
| `/bnb add <name>` | remember a name by hand (assumed to be on your realm and faction) |
| `/bnb del <name>` | forget a name |
| `/bnb scan` | read friends now |
| `/bnb auto` | toggle automatic scanning (default: on) |
| `/bnb all` | show names from other realms/factions in the list |
| `/bnb debug` | shows what the Battle.net API returns and why a friend matches or is hidden |

## Extensions

Battle.net Buddies has a small interface (`BattleNetBuddies.API`) for extensions, e.g. **Battle.net Buddies Craft**, which exchanges professions automatically between friends. Extensions can add their own tabs to the main window, provide professions and tooltip lines, and look up friends.

## Privacy

All data stays local in your `SavedVariables` file (`Battle.net BuddiesDB`). The addon sends nothing to third parties.

## Reporting bugs

Enter `/console scriptErrors 1` before testing; a Lua error then opens a window. Please report its text as an [issue](../../issues), together with the output of `/bnb debug` (please blur your friends' names).

## Limitations

- A friend the addon has never seen online is unknown. Add them by hand with `/bnb add`.
- Built for the naming of WoW Forever (realms like `...Realm5PvE`); on other game versions the full realm name is compared.

## License

[MIT](LICENSE). You may freely use, modify and redistribute the addon; the copyright notice must stay.
