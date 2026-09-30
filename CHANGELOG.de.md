# Changelog

Alle nennenswerten Änderungen an MetaCodex. Englische Fassung: `CHANGELOG.md`.

## [Unveröffentlicht]

## [1.1.9] - 2026-10-01

### Neu

- Upgrades vergleicht jetzt mit dem, was du trägst. Ein Stück, das 43 %
  der Besten tragen, nützt nichts, wenn am selben Platz zwanzig Stufen
  mehr hängen – es tritt zurück und zählt nicht mehr mit, und die Zeile
  sagt „1 hast du besser". Sichtbar bleibt es: ein Set-Teil oder ein
  Stück mit Anlegen-Effekt kann auch einen Rang tiefer lohnen, und diese
  Abwägung gehört dem Spieler.
- Die Gegenstandsstufen im Schlüsselwähler tragen die Farbe dessen, was
  sie in dieser Saison bedeuten: ab Champion, ab Held, ab Mythisch – und
  über dem höchsten Rang, den ein Boss noch fallen lässt, hilft nur noch
  Aufwerten. Die Grenzen sind an den Pfaden der Saison abgelesen, nicht
  eingetragen.

### Behoben

- **Der Schlüsselwähler hängte jede Stufe an den falschen Schlüssel** –
  „311 (+6)" statt „311 (+10)". Der Client nennt diese Saison nur den
  Tresorwert; die Spieldaten bestätigen es, `EndOfRunRewardLevel` ist in
  allen dreißig Zeilen der Saison null. Beide Zuordnungen führen wir
  jetzt selbst, und zwar auf **Pfad und Rang** statt auf eine Zahl:
  dieselbe Stufe gibt es in zwei Pfaden, und über die Zahl beschriftet
  stand „+10" an zwei Stellen. Die Stufe selbst rechnet weiterhin der
  Client aus der Bonus-ID des Rangs.
- **„Wie die Besten spielen" zeigte die Grundstufe** – 28 unter einem
  Ring, den die Besten auf 311 tragen. Der Eintrag ist weg; ohne eigene
  Wahl gilt, was ein +10 abwirft. Die Ausrüstungsliste hatte dieselbe
  Lücke: in der Zeile stand „Stufe 311", im Zeiger 28.

## [1.1.8] - 2026-09-30

### Neu

- **Upgrades**, ein neuer Eintrag unter Ausrüstung: je Instanz eine
  Zeile, je Stück ein Kästchen, sortiert nach dem, was für dich noch
  offen ist. Die Ausrüstungsliste beantwortet „was trägt man am Kopf",
  diese Ansicht „wo gehe ich dafür hin".
- Dungeons zuerst, Schlachtzüge darunter. Aus dem Schlachtzug fällt mehr
  als aus allen acht Dungeons zusammen – eine Liste, die er immer
  anführt, ist keine Auskunft.
- Was in keiner Instanz fällt, bekommt eigene Zeilen: Handwerk,
  Set-Teile, PvP, Auktionshaus, ohne bekannten Fundort. Eine blosse Zahl
  („8 aus dem Handwerk") ist wahr und nutzlos – sie sagt nicht, welche
  acht.
- Fünf Wähler: Platz, Hervorhebung, Fundort, Reihenfolge und Stufe. Die
  Reihenfolge ist eine Frage, kein Urteil – „am meisten offen" und
  „bestes Stück zuerst" sind beide vernünftig, also wählt der Spieler.
- Hervorhebung nach Zweitwerten, mit Kombinationsmodus: Krit UND
  Meisterschaft. Ein Stück, das der Client noch nicht kennt, wird weder
  hervorgehoben noch abgeblendet – eine Vermutung wäre hier besonders
  teuer, denn die Werte sind der Grund, warum man hinsieht.
- Rechtsklick auf ein Kästchen merkt es vor (goldener Rahmen, Stern)
  oder ignoriert es. Ignoriertes bleibt sichtbar, durchgestrichen, und
  zählt nicht mehr mit; der Stern ändert die Reihenfolge nie, denn eine
  Vorliebe darf keine gemessene Zahl verschieben.

### Behoben

- **Die Handwerksausrüstung dieser Erweiterung stand unter „ohne
  bekannten Fundort".** Sie hat keinen Journal-Eintrag, keinen
  Rezept-Zauber, und murlok liefert die Marke nur manchmal mit – die
  Spieldaten kennzeichnen sie aber, und von 350 gekennzeichneten
  Stücken steht kein einziges im Abenteuerjournal.
- **Ein Helm mit „Anlegen:"-Effekt zeigte den Effekt nirgends.** Der
  hängt an einer Bonus-Liste, nicht am Gegenstand, und der Link, den wir
  für die gewählte Stufe bauen, verlor ihn. Neun Stücke haben eine
  eindeutige Effektliste und tragen sie jetzt mit; wo geraten werden
  müsste, wird nichts behauptet.
- Zeilen werden in diesem Fenster wiederverwendet, und die neue Ansicht
  liess drei Dinge an ihnen zurück: ihre Kästchen, den Namen ihrer
  Instanz für den Zeiger und eine schmale Textspalte. Alle drei tauchten
  danach in der Ausrüstungsliste auf. Sie werden jetzt an der einen
  Stelle gelöscht, durch die jede Zeile läuft.

### Geändert

- UI.Refresh ist von 54 auf 40 Upvalues gefallen. WoW erlaubt 60, und
  darüber lädt die Datei ohne Fehlermeldung nicht mehr – das Addon ist
  dann einfach weg.

## [1.1.7] - 2026-09-30

### Neu

- Eine Einkaufsliste neben dem Auktionshaus. Sie geht mit dem
  Auktionshaus auf und wieder zu, zeigt das Fehlende mit Symbol, Balken
  und „14 von 20", und ein Klick auf eine Zeile sucht den Gegenstand.
  Shift-Klick hängt seinen Link in den Chat.
- Sie hängt an der äußeren rechten Kante des Auktionshauses, nicht
  darin: diese Kante behält auch ein von ElvUI umgebautes Fenster.
- Ein Schalter dafür bei der Erinnerung. Er hängt an den Erinnerungen:
  wer die ganz abstellt, will Ruhe, und ein Fenster, das trotzdem
  aufgeht, wäre das Gegenteil.

### Geändert

- Die Chatzeile am Auktionshaus ist weg. Sie sagte in einem Satz, was
  die Liste neben dem Fenster jetzt Posten für Posten zeigt.
- Die Knöpfe für Auctionator stehen nur da, wenn Auctionator installiert
  ist. Ausgegraut heißt „geht, nur gerade nicht" – ohne Auctionator geht
  es überhaupt nicht, und ein grauer Knopf sieht dann kaputt aus.
- „Jetzt suchen" sagt im Tooltip, warum es grau ist, und „Liste anlegen"
  ist bei geschlossenem Auktionshaus ebenfalls grau.
- „Liste anlegen" wechselt zuerst auf den Einkaufsreiter von Auctionator
  und füllt ihn dann. Auctionators eigene Meldung erreicht nur einen
  Reiter, der einmal offen war – der erste Klick sah deshalb aus, als
  täte er nichts.
- Die Liste zieht mit: Ignorieren, eine neue Zielmenge oder ein Kauf
  sind sofort zu sehen, ohne erst weg- und wieder hinzugehen.

### Behoben

- Ignorierte Gegenstände standen weiter auf der Einkaufsliste und wurden
  an Auctionator übergeben, obwohl das Fenster sie längst nicht mehr
  zeigte. Die Regel liegt jetzt an einer Stelle statt an dreien.
- Die Liste neben dem Auktionshaus kannte nur die Hälfte des Fehlenden.
  Verbrauchsgüter werden an einer Stelle gezählt, Verzauberungen und
  Steine an einer anderen; sie fragte nur die zweite und stand leer da,
  während im Fenster fünf Dinge fehlten.
- Dem Todesritter wurde gesagt, eine Rune sei bereits auf der Waffe,
  während eine andere darauf saß. Irgendeine Rune galt als erledigt;
  jetzt zählt die empfohlene, und irgendeine nur dort, wo es keine
  Empfehlung gibt.
- Ein Handwerksgegenstand stand in der falschen Qualitätsstufe. Kam ein
  Name doppelt vor, gewann die zuletzt gelesene Stufe statt der
  häufigsten – in den aktuellen Daten 3 Posten gegen 109.
- Ein langer Gegenstandsname brach auf den Balken darunter um. Namen
  werden jetzt mit „…" gekürzt und beim Draufzeigen ganz angezeigt.
- Der Tooltip eines ausgegrauten Knopfes blieb im Spiel unsichtbar,
  obwohl er im Test da war: ein abgeschalteter Knopf bekommt überhaupt
  keine Mausereignisse, solange man es ihm nicht ausdrücklich sagt.

## [1.1.6] - 2026-09-29

### Neu

- Der Omnium-Foliant, als Untereintrag bei den Talenten: fünf Reihen,
  dreizehn Runen, je Spec, je Aktivität und je Dungeon.
- Jede Reihe nennt, an wie vielen Spielern sie gemessen wurde. Eine Rune
  wird an ihrer Wirkung im Kampf erkannt, also ist die Stichprobe hinter
  einer Reihe kleiner als die der Spec – das zu verschweigen lüde zum
  falschen Vergleich ein.
- Reihe 3 hat nur eine Rune und steht darum ohne Prozentwert da: es gibt
  nichts zu wählen.
- Restenergie ist überhaupt nicht zu sehen, ihre Zahl ist also das, was
  die beiden anderen in Reihe 5 übrig lassen. Die Zeile sagt „Gerechnet,
  nicht gesehen" und bekommt nie die Akzentfarbe – so trägt die kleinste
  der drei Zahlen die Unsicherheit und nicht die größte.
- Der Waffenbuff, den eine Klasse selbst auflegt, wird gemessen und
  gezeigt: Flammenzunge des Schamanen und das Gift des Schurken stehen
  dort, wo sonst ein Öl stünde.
- Alles unter „Sonstiges" auf der Erinnerung hat eine eigene Menge.
  Trommeln, Reparaturhammer und Vantusrune sind nicht eine Entscheidung.
- Gegenstände, die niemand gemessen hat, lassen sich über ihre ID auf die
  Erinnerung setzen – mit Vorschau und dem Tooltip des Spiels.
- Eine Ignorieren-Liste: eine Zeile, von der man nichts mehr hören will,
  verschwindet über ein Menü und kommt genauso wieder zurück.
- Der Tageslauf lässt sich als Stichprobe starten – eine Seite je
  Rangliste, zwei Begegnungen. Fünfzehn Minuten statt fünfeinhalb Stunden,
  gedacht zum Prüfen einer Änderung am Sammler. Ein solcher Lauf
  veröffentlicht nichts: seine Zahlen ruhen auf Dutzenden Spielern, nicht
  auf Tausenden.

### Geändert

- Der Tageslauf beginnt um 00:05 UTC statt 04:30, damit die frischen
  Tabellen vor dem Frühstück auf CurseForge stehen und nicht nach dem
  Mittagessen. Die alte Zeit wartete auf eine tägliche Ranglisten-
  Rücksetzung, von der hier nichts abhängt.
- Fehlende Verzauberungen und Steine werden benannt, nicht gezählt. „Zwei
  Steine fehlen" sagt nicht, welche zwei.
- Ein Sockel mit einem Stein darin heißt nicht mehr leer. Tempo und
  Vielseitigkeit mit Absicht zu tragen ist eine Entscheidung, kein
  Versäumnis.

### Behoben

- Ein Schamane sollte Öl kaufen. Die Zeile, die das verhindern sollte,
  konnte nie wirken: in Lua ergibt `cond and nil or x` immer `x` – der
  Zweig, der richtig aussah, tat nichts.
- Der Anteil neben einem Talent-Build sagt jetzt, wessen fünfzig Prozent
  das sind.
- Anteile, die eine Menge aufteilen, ergeben zusammen hundert. In jeder
  Reihe des Folianten wählt jeder Spieler genau eine Rune, die Zahlen
  teilen also dieselbe Menge; einzeln gerundet kamen sie auf 99 oder 101.
  Über 790 Reihen echter Daten landet jetzt jede auf genau 100.
- Die Zielwert-Zeilen überlappen den Balken nicht mehr: ein Text ohne
  Breite läuft so weit, wie er lang ist, und der Balken liegt senkrecht
  genau darüber.
- Die Zielwert-Zeilen sagen, welchen Prozentwert sie meinen – diese
  Wertung gegen die Summe der vier Zweitwerte, und das ist nicht die
  Wirkung, die das Charakterfenster zeigt.
- Die Raid-Schwierigkeiten haben ihre Bossauswahl zurück, und den neunten
  Boss des Raids gleich mit.

### Geändert (Oberfläche)

- Die Scrollleiste gehört zu diesem Fenster: eine schmale Schiene in der
  Klassenfarbe, zum Ziehen, und ein Klick daneben springt dorthin. Sie
  erscheint nur, wenn es etwas zu schieben gibt – Blizzards Pfeile standen
  auf kurzen Seiten da, als gäbe es noch etwas zu finden.
- Die Folianten-Zeilen wiederholen ihren Prozentwert nicht mehr in Worten,
  und eine Zeile ohne zweite Zeile setzt ihren Namen mittig.

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
