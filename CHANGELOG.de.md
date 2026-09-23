# Changelog

Alle nennenswerten Änderungen an MetaCodex. Englische Fassung: `CHANGELOG.md`.

## [Unveröffentlicht]

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

### Entfernt

- Der eigene Talent-Kodierer. Strings kommen nur noch aus echten Clients.
