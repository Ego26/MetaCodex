![MetaCodex](assets/banner-1696-de.png)

# MetaCodex

**Aus echten Kämpfen, nicht aus Guides.** Talentbuilds mit Import-String,
Ausrüstung mit Fundort, Verzauberungen, Steine, Verbrauchsgüter, Zielwerte
und die Top-Spieler je Spec — für Mythic+, Raid und jede PvP-Klammer.
Täglich gemessen aus raider.io, murlok.io und Warcraft Logs, nie aus einem
Guide abgeschrieben. Liest deine Ausrüstung und übergibt das Fehlende an
Auctionator.

    /mc

*[English readme](README.md) · [Features](FEATURES.de.md) ·
[Changelog](CHANGELOG.de.md)*

---

## Installation

Das neueste Paket vom Release
[**nightly**](https://github.com/Ego26/MetaCodex/releases/tag/nightly)
laden und nach `Interface/AddOns` entpacken. Es sind vier Ordner:
`MetaCodex` und die drei Datenaddons `MetaCodex_Data`, `MetaCodex_Dungeons`,
`MetaCodex_Players`, die erst laden, wenn sie gebraucht werden.
[Auctionator](https://www.curseforge.com/wow/addons/auctionator) ist
optional — ohne ihn zeigt MetaCodex die Listen trotzdem, nur die Übergabe
fällt weg.

## Was es zeigt

| Reiter | |
|---|---|
| **Guides & Rotation** | Verweise auf die geschriebenen Guides zur Spec |
| **Zielwerte** | Gemessene Mediane der Besten, deine Werte als zweiter Balken |
| **Talente** | Der häufigste Build mit Import-String, Alternativen als *X statt Y*, umstrittene Talente — je Dungeon in M+, je Boss im Raid |
| **Top-Spieler** | Wer oben steht, klickbar: Talentbuild mit Import-String und komplette Ausrüstung |
| **Prioritäten** | Was deinem Charakter fehlt, geordnet nach dem Anteil der Besten, die es tragen |
| **Ausrüstung** | Fünf je Platz mit Fundort; Tooltips auf der Schlüsselstufe, die du wählst |
| **Tier-Set** | Welche Set-Teile die Besten tragen, und wie viele davon |
| **Handwerk** | Die Handwerksstücke, die wirklich getragen werden, mit ihrem Wertepaar und den gemessenen Gegenstandsstufen |
| **Verzierungen** | Welche zwei Verzierungen zusammen getragen werden, und wie oft |
| **Verzauberungen & Steine** | Gegen deine angelegte Ausrüstung: was noch offen ist |
| **Verbrauchsgüter** | Nach Art gruppiert, mit Anteil, höchstem Schlüssel, Bestand und Ziel |
| **Erinnerung** | Was vor dem Start geprüft wird, und die Einstellungen dazu |

Zehn Aktivitäten, vier Plattformen, alle vierzig Speccs. Nichts wird
gezeigt, was keine Plattform beantworten kann: Abschnitte, Aktivitäten und
Plattformen ohne Daten sind ausgeblendet. [FEATURES.de.md](FEATURES.de.md)
hat das ganze Bild.

## Sprache

**Englisch ist der Standard, Deutsch kommt dazu.** Die Oberfläche hat
`enUS` als Basis und `deDE` als Überschreibung – ein deutscher Client
bekommt also ungefragt Deutsch, und `/mc lang de|en|auto` übersteuert
auch das. Dieselbe Reihenfolge gilt drumherum: Readme, Changelog und
Feature-Seite sind zuerst englisch, mit einer `.de`-Fassung. Gespeichert
werden nur IDs von Gegenständen, Zaubern und Begegnungen, deshalb stimmen
Namen und Symbole auf jedem Client.

## Aufbau

```
Core/Init.lua          Namensraum, Konstanten, Aktivitäten und ihre Gruppen
Core/Locale.lua        L[...] mit enUS als Basis
Core/Style.lua         Farben, Abstände, Schriften – die eine Bildsprache
Core/Compat.lua        jeder Griff nach außen, einmal abgesichert
Core/Data.lua          lädt die Datenaddons bei Bedarf
Core/Catalog.lua       Zugriff auf den Katalog – kennt als Einzige das Format
Core/Recommend.lua     Zugriff auf die Empfehlungen: Modi, Quellen, Mischen
Core/Profile.lua       SavedVariables: Auswahl, Fenster, Ziele
Core/Gear.lua          angelegte Ausrüstung: leere Sockel, fehlende Verzauberungen
Core/List.lua          Soll minus Ist, für eine Spec oder mehrere
Core/Auctionator.lua   der Adapter – die EINZIGE Stelle, die Auctionator kennt
Core/Guides.lua        die Guide-Verweise
Core/UI.lua            das Fenster
Core/Remind.lua        Erinnerung beim Betreten und am Auktionshaus
Core/Probe.lua         /mc probe
Core/Slash.lua         /mc
Core/Boot.lua          Ereignisse

Locales/               enUS.lua, deDE.lua
Tests/                 Rauch- und Logiktests in einer echten Lua-VM (fengari)

tools/build-catalog.js         Spieltabellen → MetaCodex_Data/Catalog.lua
tools/collect-raiderio.js      M+: Ausrüstung, Verzauberungen, Steine, Talent-Strings
tools/collect-murlok.js        PvP und M+: Anteile, Talente, Top-Spieler
tools/collect-wcl.js           Warcraft Logs: Raids und Verbrauchsgüter
tools/collect-profiles.js      raider.io-Profile der Top-Spieler, geprüft
tools/collect-bnet.js          Battle.net: PvP-Ranglisten, Loadouts, PvP-Talente, Ausrüstung
tools/build-recommendations.js alles → die drei Datenaddons
tools/collect-all.js           der Tageslauf, in Reihenfolge
tools/package.sh               die Zip für ein Release
tools/sync.ps1                 Repo → AddOns-Ordner
tools/schedule.ps1             der Tageslauf als Windows-Aufgabe
```

## Daten

Die Daten liegen **nicht im Git**. Es sind 60 MB, die sich jede Nacht
ändern; ein Jahr davon wären Gigabytes Verlauf für nichts. Stattdessen
läuft jede Nacht die GitHub-Action `Daily data`: sie sammelt von raider.io,
murlok.io und Warcraft Logs, lässt die Tests laufen, packt die vier
Addon-Ordner und hängt die Zip an das laufende Release
[**nightly**](https://github.com/Ego26/MetaCodex/releases/tag/nightly).

Selbst bauen:

```bash
node tools/collect-all.js .        # alles, in der richtigen Reihenfolge (1–2 h)
node tools/build-catalog.js .      # nur der Katalog aus den Spieltabellen
```

Warcraft Logs braucht Zugangsdaten: `tools/wcl-credentials.json` (siehe
`.example`) oder die Umgebungsvariablen `WCL_CLIENT_ID` und
`WCL_CLIENT_SECRET`. Die Action nimmt sie aus den Repository-Secrets.
Battle.net genauso: `tools/bnet-credentials.json` oder `BNET_CLIENT_ID` und
`BNET_CLIENT_SECRET`; ohne sie wird dieser Schritt übersprungen.
Unter Windows richtet `.\tools\schedule.ps1` denselben Lauf als tägliche
Aufgabe ein.

Der Katalog liest `ItemSparse`, `ItemBonus`, `JournalEncounterItem`,
`TraitDefinition` und Verwandte über [wago.tools](https://wago.tools) –
dieselben Tabellen, die der Client selbst benutzt. Keine ID in diesem
Projekt ist abgeschrieben. Jede kommt aus den Spieldaten und ist nachprüfbar.

Talent-Strings werden nie erzeugt: jeder stammt aus dem Client eines echten
Spielers. Raid- und PvP-Strings werden gegen den geloggten Kampf bzw. die
murlok-Heatmap geprüft, bevor sie als Build gelten.

Releases: ein Tag `v1.2.3` genügt, der Workflow `Release` packt den Code
dieses Tags mit den neuesten Nightly-Daten, lädt ihn zu CurseForge hoch und
legt das GitHub-Release an. Jede Nacht geht dasselbe Paket noch einmal hoch,
mit den Tabellen dieser Nacht - der Code des neuesten Tags, nie der aktuelle
Stand von `main`. Beides über den [BigWigs-Packager](https://github.com/BigWigsMods/packager),
`.pkgmeta` und das Repository-Secret `CF_API_KEY`; die Änderungsnotizen
stehen in `RELEASE-NOTES.md`.

## Tests

```bash
cd Tests && npm install
node run.js smoke_test.lua   # lädt das Addon über seine TOC und bedient es
node run.js                  # nur die Kataloglogik
```

Siehe [Tests/README.md](Tests/README.md).

## Beim Entwickeln ins Spiel bringen

```powershell
.\tools\sync.ps1                # einmal
.\tools\sync.ps1 -Watch         # bei jeder Änderung
```

## Drei Regeln, die nicht verhandelbar sind

1. **Durch den Quelltext reisen nur IDs, nie Namen.** Der Client löst den
   Namen auf – nur so stimmt das Fenster auf einem deutschen Client genauso
   wie auf einem englischen.
2. **MetaCodex schreibt ausschließlich in Listen mit dem Präfix `MetaCodex:`.**
   Auctionators `CreateShoppingList` ersetzt eine Liste vollständig; wer den
   Namen einer fremden Liste träfe, löschte sie.
3. **Nichts wird gezeigt, was es nicht gibt.** Keine erfundenen Vorgaben,
   keine geratenen Fundorte, keine Talent-Strings, die kein Client geschrieben
   hat.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE).

Benutzen, ändern, weitergeben: alles erlaubt. Was die Lizenz dafür
verlangt, ist, dass eine geänderte Fassung, die du weitergibst, ihren
Quelltext mitbringt, unter derselben Lizenz. Damit bleibt das Addon
offen - niemand kann diese Arbeit nehmen, schließen und weiterreichen.

Die Tabellen, die das Addon mitbringt, sind Messungen von öffentlichen
Plattformen und aus den Spieldaten selbst. Der Code, der sie sammelt,
prüft und zusammenbaut, gehört zu diesem Programm und steht unter
derselben Lizenz.
