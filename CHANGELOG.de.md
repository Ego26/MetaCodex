# Changelog

Alle nennenswerten Änderungen an MetaCodex. Englische Fassung: `CHANGELOG.md`.

## [Unveröffentlicht]

### Neu

- **Prioritäten** als erster Abschnitt unter Ausrüstung: was diesem
  Charakter fehlt - Verbrauchsgüter gegen die Beutel, Verzauberungen und
  Steine gegen die angelegte Ausrüstung - in einer Liste, geordnet nach
  dem gemessenen Anteil der Besten, die es tragen. Ausdrücklich keine
  Schadensrechnung; über der Liste steht, was die Zahl zählt. Die
  Erinnerung vor dem Start nimmt dieselbe Rangfolge.

## [1.1.0] - 2026-09-26

### Neu

- **Tier-Set**, **Handwerk** und **Verzierungen** als eigene Abschnitte,
  gezählt aus den Profilen, die ohnehin geholt werden: welche Set-Teile
  getragen werden und wie viele, welche Handwerksstücke mit dem Wertepaar
  ihrer Träger, und welche zwei Verzierungen zusammen getragen werden.
- Auswahl von Gegenstandsstufe und Werten beim Handwerk, beides aus den
  wirklich gemessenen Stufen und Wahlen - ein Handwerksstück wird nicht
  mit einem Schlüsselstein aufgewertet, die Belohnungstabelle der Dungeons
  sagt über es also nichts.
- Wertungen der Zweitwerte an jedem Gegenstand, überall - auch bei
  Handwerksstücken und im Vergleichs-Tooltip.

### Geändert

- Die Ausrüstungsliste zeigt je Platz eine Zeile; ein Klick öffnet die
  Alternativen. Neunzig Zeilen waren eine Wurst, keine Liste.
- Die Fundort-Auswahl ist nach Dungeons, Schlachtzügen und Sonstigem
  gegliedert, und eine ganze Gruppe lässt sich auf einmal wählen.
- Schriftgröße und Farbe entscheidet eine einzige Stelle (`Style.role`).

### Behoben

- Handwerksstücke zeigten "Zufallswert 1 / 2" statt ihrer Werte: der Link
  wird jetzt aus der ganzen gemessenen Bonus-Liste gebaut, je Stufe.
- Eine Zeile mit zwei Verzierungen zeigt beide Tooltips.
- Die Spieleransicht schließt sich beim Wechsel von Aktivität oder Spec.
- Geprüfte Raid-Talent-Strings wurden von M+-Strings überschrieben, weil
  acht Bossdateien alle den Modus "raid" trugen.

## [1.0.0] - 2026-09-24

### Neu

- **Talente** für jede Aktivität: der häufigste Build mit fertiger
  Import-String, bis zu sechs Alternativen als *welches Talent statt
  welchem*, die umstrittenen Talente, PvP-Talente in eigener Gruppe. Je
  Dungeon in M+, je Boss im Raid. Jeder String stammt aus dem Client eines
  echten Spielers; Raid- und PvP-Strings werden gegen den geloggten Kampf
  bzw. die murlok-Heatmap geprüft, bevor sie als Build gelten.
- **Ausrüstung** je Platz mit Anteil, Gegenstandsstufe, höchstem Schlüssel,
  Set-/Handwerksmarke und Fundort (Boss und Instanz, PvP-Händler oder „kein
  Instanzdrop"). Schlüsselwahl nach Aufwertungspfad (Champion / Held /
  Große Schatzkammer) wie KeystoneLoot; Tooltips zeigen den Gegenstand auf
  dem gewählten Pfad.
- **Zielwerte** als gemessene Mediane aus echten Kämpfen, mit den eigenen
  Werten als zweitem Balken.
- **Top-Spieler** je Spec und Aktivität, klickbar: Profil mit Talent-String,
  Adresse und kompletter Ausrüstung in einem dritten nachladbaren Addon.
- **Verbrauchsgüter**, gruppiert nach Art — Fläschchen, Speise, Kampftrank,
  Heiltrank, Waffenbuffs, Runen — mit Anteil, höchstem Schlüssel, Bestand
  und Ziel.
- **Erinnerung** als Reiter: Stand je Verbrauchsart, offene Verzauberungen
  und Steine, die Einstellungen (beim Betreten, am Auktionshaus, Schwelle).
  Die Chatzeile beim Betreten nennt jetzt auch offene Verzauberungen.
- **Zehn Aktivitäten, drei Plattformen:** M+ High Keys und +7–21, Raid in
  drei Schwierigkeiten, 2v2, 3v3, Solo Shuffle, RBG, Blitz; raider.io,
  murlok.io, Warcraft Logs, einzeln oder zusammen.
- **Eine Regel für das Fenster:** nichts wird gezeigt, was es nicht gibt —
  Abschnitte, Aktivitäten und Plattformen ohne Daten sind ausgeblendet.
- **Shift-Klick** verlinkt einen Gegenstand in den Chat oder ins Suchfeld
  des Auktionshauses; Ctrl-Klick öffnet den Ankleideraum.
- Fenster ziehbar und skalierbar (`/mc scale`); Position und Größe werden
  gemerkt.
- Einkaufslisten je Abschnitt (Verzauberungen, Verbrauchsgüter,
  Erinnerung), mit Stückzahlen, an Auctionator übergeben. Angefasst werden
  nur Listen mit dem Präfix `MetaCodex:`.
- Katalog aus den DB2-Tabellen des Clients über wago.tools: Verzauberungen,
  Steine, Verbrauchsarten, Aufwertungspfade, Fundorte, PvP-Händler,
  Talentnamen.
- Täglicher Datenlauf als GitHub-Action; das fertige Paket hängt am Release
  `nightly`. Lokal richtet `tools/schedule.ps1` denselben Lauf als
  Windows-Aufgabe ein.
- Oberfläche auf Englisch und Deutsch, umschaltbar per `/mc lang`; auf
  jedem Client richtig, weil nur IDs gespeichert werden.
- `/mc probe` Selbsttest mit kopierbarem Bericht.
