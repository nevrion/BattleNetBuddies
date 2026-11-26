# Changelog

## 0.14.1
- **EN:** Friends are now picked up whatever the game reports as the client program, as long as it starts with "WoW" (before only exactly "WoW" or "WoWC", so friends could vanish if WoW Forever changed the spelling). `/bnb debug` now also shows the client program and online state of each friend.
- **DE:** Freunde werden jetzt übernommen, egal wie das Spiel das Client-Programm schreibt, solange es mit "WoW" beginnt (vorher nur genau "WoW" oder "WoWC", Freunde konnten verschwinden, wenn WoW Forever die Schreibweise ändert). `/bnb debug` zeigt jetzt auch Client-Programm und Online-Status jedes Freundes.

## 0.14.0
- **EN:** Tabs share the window width, so extensions can add several tabs. New `API.OpenMailTo(name)` fills the mail recipient field (used by extensions).
- **DE:** Die Reiter teilen sich die Fensterbreite, damit Erweiterungen mehrere Reiter anlegen können. Neu: `API.OpenMailTo(name)` füllt das Empfängerfeld der Post (für Erweiterungen).

## 0.13.1
- **EN:** New logo: used for the minimap button and the addon list.
- **DE:** Neues Logo: wird für den Minimap-Button und die Addon-Liste verwendet.

## 0.13.0
- **EN:** Renamed from *Postillion* to **Battle.net Buddies** (folder `BattleNetBuddies`, command `/bnb`; `/pp` and `/postillion` still work as aliases). Saved data is carried over automatically. The extension is now *Battle.net Buddies Craft*.
- **DE:** Umbenannt von *Postillion* in **Battle.net Buddies** (Ordner `BattleNetBuddies`, Befehl `/bnb`; `/pp` und `/postillion` funktionieren weiter als Alias). Gespeicherte Daten werden automatisch übernommen. Die Erweiterung heißt jetzt *Battle.net Buddies Craft*.

## 0.12.0
- **EN:** Public interface for extensions (`Postillion.API`): friend lookup, online friends, automatic professions, tooltip lines and extra tabs in the main window. First extension: *Postillion Craft* (shares professions between friends). Behaviour of the addon itself is unchanged.
- **DE:** Öffentliche Schnittstelle für Erweiterungen (`Postillion.API`): Freunde nachschlagen, Freunde online, automatische Berufe, Tooltip-Zeilen und zusätzliche Reiter im Hauptfenster. Erste Erweiterung: *Postillion Craft* (tauscht Berufe unter Freunden aus). Das Verhalten des Addons selbst ändert sich nicht.

## 0.11.2
- **EN:** The main window is wider so the texts in the settings fit inside the frame.
- **DE:** Das Hauptfenster ist breiter, damit die Texte in den Einstellungen in den Rahmen passen.

## 0.11.1
- **EN:** Server types are written properly (PvE, PvP, RP-PvE) and the faction is shown as its crest instead of the word Horde/Alliance.
- **DE:** Servertypen stehen in richtiger Schreibweise (PvE, PvP, RP-PvE), und die Fraktion erscheint als Wappen statt als Wort Horde/Allianz.

## 0.11.0
- **EN:** Only real friends are listed now: Battle.net friends always, friends of the regular friends list optionally (Settings). Guild, group, whisper and mail-sender names are no longer recorded, and existing ones are removed. Professions: only the 9 main professions, at most 2 per friend (existing entries are trimmed). Fixed the edit window (buttons covered the profession icons) and the settings text running out of the frame.
- **DE:** Es stehen nur noch echte Freunde in der Liste: Battle.net-Freunde immer, Freunde der normalen Freundesliste auf Wunsch (Einstellungen). Namen aus Gilde, Gruppe, Flüstern und Post-Absendern werden nicht mehr erfasst, vorhandene werden entfernt. Berufe: nur die 9 Hauptberufe, höchstens 2 pro Freund (vorhandene Einträge werden gekürzt). Das Bearbeitungsfenster (Knöpfe verdeckten die Berufssymbole) und der Text in den Einstellungen, der über den Rahmen lief, sind korrigiert.

## 0.10.0
- **EN:** Minimap button (left-click friends, right-click settings, drag to move). New main window with *Friends* and *Settings* tabs; every slash command is now also available in the UI. Clicking a name with the mail window closed opens note and professions. New *Forget name* button.
- **DE:** Minimap-Button (Linksklick Freunde, Rechtsklick Einstellungen, Ziehen verschiebt). Neues Hauptfenster mit den Reitern *Freunde* und *Einstellungen*; jeder Befehl ist jetzt auch in der Oberfläche verfügbar. Ein Klick auf einen Namen öffnet bei geschlossenem Post-Fenster Notiz und Berufe. Neuer Knopf *Name vergessen*.

## 0.9.0
- **EN:** Friends list grouped by BattleTag, characters expandable; search also finds the BattleTag.
- **DE:** Freundesliste nach BattleTag gruppiert, Charaktere aufklappbar; die Suche findet auch den BattleTag.

## 0.8.x
- **EN:** Professions per friend (12 professions to click, shown as icons, searchable). MIT license. Release zips are named `-forever` so WoWUp finds them.
- **DE:** Berufe pro Freund (12 Berufe zum Anklicken, als Symbole, durchsuchbar). MIT-Lizenz. Release-Zips heißen `-forever`, damit WoWUp sie findet.

## 0.7.0
- **EN:** Notes per friend (right-click a name), searchable.
- **DE:** Notizen pro Freund (Rechtsklick auf einen Namen), durchsuchbar.

## 0.6.0
- **EN:** Modern flat dark UI, class icons, suggestion popup and Friends window.
- **DE:** Modernes flaches dunkles Design, Klassensymbole, Vorschlagsfenster und Freundefenster.

## 0.4.0 - 0.5.0
- **EN:** Automatic background scan (`/pp auto`). Renamed to Postillion (command `/pp`).
- **DE:** Automatisches Einlesen im Hintergrund (`/pp auto`). Umbenennung in Postillion (Befehl `/pp`).

## 0.1.0 - 0.3.0
- **EN:** First versions: remembers friends' character names and completes them in the mail window, only for your realm type and faction (realm layers are ignored).
- **DE:** Erste Versionen: merkt sich Charakternamen von Freunden und vervollständigt sie im Post-Fenster, nur für deinen Servertyp und deine Fraktion (Layer werden ignoriert).
