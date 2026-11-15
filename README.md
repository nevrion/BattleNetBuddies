# Postillion

**Deutsch** · [English](#english)

Post-Empfänger-Vervollständigung für **WoW Forever** (Interface 16001): Postillion merkt sich die Charakternamen deiner Battle.net-Freunde und vervollständigt sie im Post-Fenster, **auch wenn der Freund offline ist**. Befehl im Spiel: `/pp`

**Status:** Beta. Das Addon ist bisher nur offline (Simulation) und in ersten Tests im Spiel geprüft, Fehlermeldungen sind willkommen (siehe unten).

## Das Problem

Mit Vor- und Nachnamen und dem neuen Freundessystem kennt das Spiel den Charakternamen eines Battle.net-Freundes nur, solange er **online** ist. Die eingebaute Autovervollständigung im Post-Fenster greift nur bei Online-Charakteren, und den Charakter zusätzlich in die Freundesliste zu setzen scheitert an "ihr seid bereits befreundet". Offline Post zu schicken heißt, sich den vollen Namen merken zu müssen.

## Die Lösung

Postillion liest im Hintergrund jeden Namen mit, den das Spiel dir zeigt, und speichert ihn dauerhaft. Quellen: Battle.net-Freunde, normale Freundesliste, Gilde, Gruppe, Flüstern, Post-Absender und frühere Empfänger. Ein Freund muss **einmal online gesehen** worden sein, danach ist sein Name im Post-Fenster verfügbar.

## Installation

1. Unter [Releases](../../releases) die Datei `Postillion-x.y.z.zip` herunterladen.
2. Den Ordner `Postillion` aus dem Zip nach `World of Warcraft/<Spielversion>/Interface/AddOns/` kopieren.
3. Spiel starten oder `/reload`.

## Benutzung

- **Im Post-Fenster** im Feld "An" ein paar Buchstaben tippen, auch nur vom **Nachnamen** oder vom Namen des Freundes. Es erscheint ein Vorschlagsfenster, **Tab** übernimmt den ersten Treffer, ein Klick übernimmt den gewählten Namen.
- Der Knopf **Freunde** neben dem Feld öffnet die komplette Liste mit Suche, Klassensymbolen und Mausrad-Blättern.
- **Notizen:** **Rechtsklick** auf einen Namen (Liste oder Vorschlag) öffnet eine Notiz, z.B. "Schmied, tauscht gern Erz". Sie gilt für alle Charaktere desselben Freundes, wird in der Zeile und im Tooltip angezeigt und ist durchsuchbar.
- **Server und Fraktion sind abgesichert:** Vorgeschlagen werden nur Namen, die zu deinem Servertyp (PvE, RP-PvE, PvP ...) und deiner Fraktion passen. Gleichnamige Charaktere auf einem anderen Servertyp oder in der anderen Fraktion werden nicht angeboten, damit Post nicht an die falsche Person geht. Die Nummern in den Servernamen (z.B. `Realm1`, `Realm5`) sind nur Layer desselben Servers und werden ignoriert. Gespeichert wird alles, angezeigt nur, was passt (in der Liste lässt sich "andere Server/Fraktionen" einblenden, grau und mit Warnung).
- **Automatisch:** Nach dem Login und danach alle 60 Sekunden (Gilde alle 5 Minuten) liest Postillion Freunde, Gruppe und Gilde selbst ein.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/pp` | Hilfe |
| `/pp liste [Teil]` | gemerkte Namen anzeigen |
| `/pp note <Name> \| <Text>` | Notiz zu einem Freund setzen (leerer Text löscht) |
| `/pp add <Name>` | Namen von Hand merken (gilt für deinen Server und deine Fraktion) |
| `/pp del <Name>` | Namen vergessen |
| `/pp scan` | Freunde, Gilde, Gruppe sofort einlesen |
| `/pp auto` | automatisches Einlesen ein- oder ausschalten (Standard: an) |
| `/pp alle` | Liste auch mit Namen anderer Server/Fraktionen |
| `/pp debug` | zeigt, was die Battle.net-Schnittstelle liefert und warum ein Freund passt oder ausgeblendet wird |

## Datenschutz

Alle Daten liegen lokal in deiner `SavedVariables`-Datei (`PostillionDB`). Das Addon sendet nichts an Dritte.

## Fehler melden

Vor dem Test `/console scriptErrors 1` eingeben, dann erscheint bei einem Lua-Fehler ein Fenster. Bitte den Text daraus als [Issue](../../issues) melden, dazu die Ausgabe von `/pp debug` (Namen von Freunden bitte unkenntlich machen).

## Grenzen

- Ein Freund, den das Addon nie online gesehen hat, ist unbekannt. Mit `/pp add` lässt er sich von Hand nachtragen.
- Das Addon ist für die Namensstruktur von WoW Forever gebaut (Server wie `...Realm5PvE`); auf anderen Spielversionen wird der gesamte Servername verglichen.

---

# English

Mail recipient autocomplete for **WoW Forever** (Interface 16001): Postillion remembers the character names of your Battle.net friends and completes them in the mail window, **even when the friend is offline**. In-game command: `/pp`

**Status:** Beta. Checked offline (simulation) and in first in-game tests so far; bug reports are welcome (see below).

## The problem

With first and last names and the new friends system, the game only exposes a Battle.net friend's character name while they are **online**. The built-in mail autocomplete only works for online characters, and adding the character to the friends list fails with "you are already friends". Mailing an offline friend means remembering their full name.

## The solution

Postillion quietly records every name the game shows you and stores it permanently. Sources: Battle.net friends, the regular friends list, guild, group, whispers, mail senders and earlier recipients. A friend has to be **seen online once**; after that the name is available in the mail window.

## Installation

1. Download `Postillion-x.y.z.zip` from [Releases](../../releases).
2. Copy the `Postillion` folder from the zip to `World of Warcraft/<game version>/Interface/AddOns/`.
3. Start the game or `/reload`.

## Usage

- **In the mail window**, type a few letters into the "To" field, also just of the **last name** or of the friend's name. A suggestion popup appears, **Tab** accepts the first match, a click picks the selected name.
- The **Friends** button next to the field opens the full list with search, class icons and mouse-wheel scrolling.
- **Notes:** **right-click** a name (list or suggestion) to add a note, e.g. "blacksmith, likes ore". It applies to all characters of the same friend, shows in the row and tooltip, and is searchable.
- **Realm and faction are safeguarded:** only names matching your realm type (PvE, RP-PvE, PvP ...) and your faction are suggested. Same-named characters on another realm type or in the other faction are never offered, so mail does not reach the wrong person. The numbers in realm names (e.g. `Realm1`, `Realm5`) are just layers of the same server and are ignored. Everything is stored, only matching entries are shown (the list can show "other realms/factions", greyed out with a warning).
- **Automatic:** after login and then every 60 seconds (guild every 5 minutes) Postillion reads friends, group and guild by itself.

## Commands

| Command | Effect |
|---|---|
| `/pp` | help |
| `/pp list [part]` | show remembered names |
| `/pp note <name> \| <text>` | set a note for a friend (empty text deletes) |
| `/pp add <name>` | remember a name by hand (assumed to be on your realm and faction) |
| `/pp del <name>` | forget a name |
| `/pp scan` | read friends, guild, group now |
| `/pp auto` | toggle automatic scanning (default: on) |
| `/pp all` | show names from other realms/factions in the list |
| `/pp debug` | shows what the Battle.net API returns and why a friend matches or is hidden |

## Privacy

All data stays local in your `SavedVariables` file (`PostillionDB`). The addon sends nothing to third parties.

## Reporting bugs

Enter `/console scriptErrors 1` before testing; a Lua error then opens a window. Please report its text as an [issue](../../issues), together with the output of `/pp debug` (please blur your friends' names).

## Limitations

- A friend the addon has never seen online is unknown. Add them by hand with `/pp add`.
- Built for the naming of WoW Forever (realms like `...Realm5PvE`); on other game versions the full realm name is compared.
