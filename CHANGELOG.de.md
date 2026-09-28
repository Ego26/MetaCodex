# Changelog

Alle nennenswerten Änderungen an MetaCodex. Englische Fassung: `CHANGELOG.md`.

## [Unveröffentlicht]

## [1.1.5] - 2026-09-28

### Neu

- Die Handwerksstufe steht am Symbol - dasselbe Zeichen wie im Beutel, in
  derselben Ecke: bei Verbrauchsgütern, bei Handwerksstücken und bei den
  Reagenzien der Verzierungen. Sie kommt aus den Qualitätstabellen des
  Spiels und wird nicht mehr daraus geraten, wie viele Stufen derselben
  Ware es gibt.
- Die Zielwerte sagen, was sie sind: der Median der gemessenen Spieler, je
  Wert einzeln, mit der mittleren Hälfte des gemessenen Feldes hinter jeder
  Zahl. Ausdrücklich keine BiS-Liste.
- Ringe und Schmuck zeigen zwei Zeilen, weil man zwei trägt, und die
  Überschrift sagt, für wie viele Plätze sie steht.

### Behoben

- Zweimal dieselbe Verzierung wurde als eine gezählt. Sie ist eine eigene
  Wahl und bei vielen Speccs die häufigste. Die Zeile nennt sie einmal mit
  "×2" und trägt beide Tooltips.
- Eine Verzierung trug den Namen der niedrigsten Handwerksstufe ihres
  Reagenz: gesucht wurde über den Namen, und der erste Treffer gewann.
- Anteile runden nicht mehr zu einer Behauptung. 100 % steht nur da, wenn
  es wirklich alle sind, 0 % nur, wenn es wirklich keiner ist - bei den
  Ringen stand 100, 1 und 0 Prozent, das sind 101 und kann nicht sein.
- Hervorgehoben wird der erste Platz, nicht alles ab fünfzig Prozent. Ein
  Schmuckstück mit 48 % ist genauso das meistgetragene wie eines mit 51 %.
- "Bereits drauf" bei Sockelsteinen beantwortet die angelegte Ausrüstung
  und folgt sofort, wenn du ein Stück tauschst.
- "Aus meinen Taschen wählen" bietet an, was in den Taschen liegt, statt
  dessen, was im Katalog steht: eine ältere Rune fehlte in der Liste,
  obwohl sie genau dort lag. GetItemInfoInstant gibt sieben Werte zurück,
  und der fünfte ist das Symbol, nicht die Klasse.
- Deutsche Überschriften behielten einen kleinen Umlaut mitten in
  Großbuchstaben - string.upper kennt nur a bis z - und die Platzzahl las
  sich als "1 Platz/Plätze".

## [1.1.4] - 2026-09-28

### Behoben

- Der Minimap-Knopf sitzt wieder auf dem Rand der Minimap, in jeder Größe
  und Form - er folgte einer fest eingetragenen Zahl.
- Koreanische und chinesische Namen werden mit einer Schrift gezeichnet, die
  sie zeichnen kann, und die Schrift wird wieder hergegeben, wenn eine Zeile
  oder Überschrift weiterbenutzt wird.
- Der Reiter Tier-Set zeigt nur das Klassenset dieser Saison: nicht das der
  vorigen, nicht die PvP-Rüstung, nicht den Ring aus einem Schmuckset.

## [1.1.3] - 2026-09-27

### Behoben

- v1.1.2 wurde mit dem Katalog der Nacht gepackt statt mit dem eigenen:
  der Bau starb an einem fehlenden Verzeichnis, und der Schritt verschluckte
  den Fehler.

## [1.1.2] - 2026-09-27

### Neu

- Der Fundort-Wähler zeigt **alle Bosse** eines Schlachtzugs, nicht nur
  die, von denen in der gezeigten Liste etwas stammt. Wählt man einen, von
  dem niemand etwas trägt, steht dort ein Satz statt eines leeren Fensters.

### Behoben

- Der gewählte Ausrüstungsplatz wurde von der allgemeinen Kategorie-
  Prüfung gelöscht, die ihre Wahl unter demselben Schlüssel ablegt. Nach
  Schmuck sah man einmal den Schmuck, beim nächsten Klick wieder alles.
- Alter Inhalt bleibt aus Dungeons und Schlachtzügen heraus: die
  Feuerlande liefen vorige Woche als Zeitwanderung, jemand trägt seitdem
  ein Stück von dort - der Fundort ist echt, gehört aber unter
  Sonstiges.

## [1.1.1] - 2026-09-26

### Behoben

- Ein Schlachtzug, aus dem niemand einen Bericht hochgeladen hat, landete
  unter "Sonstiges": die Art einer Instanz kam aus den Messungen. Sie kommt
  jetzt aus dem Katalog, für alle 213 Instanzen, abgelesen an ihrer Karte.
- Eine Gruppe mit einem einzigen Eintrag verlor ihre Überschrift - der eine
  Schlachtzug stand nackt zwischen "Dungeons" und "Sonstiges".

### Neu

- Ein Schlachtzug klappt im Fundort-Wähler in seine Bosse auf - nur in die,
  aus denen in der Liste wirklich etwas steht.

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
