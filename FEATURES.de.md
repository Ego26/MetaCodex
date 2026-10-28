# MetaCodex — Was das Addon kann

> Stand: 27. Oktober 2026. Deutsche Fassung von `FEATURES.md`. Wer
> wissen will, *wie* etwas gebaut ist, findet das nicht in diesem Repo.

**MetaCodex zeigt dir, was die besten Spieler deiner Spezialisierung
wirklich spielen** — Talente, Ausrüstung, Verzauberungen, Steine,
Verbrauchsgüter, Zielwerte, Rassen, die Gruppen, in denen sie spielen —
für Mythic+, Raid und jede PvP-Klammer. Nicht aus einem Guide abgeschrieben, sondern täglich aus
raider.io, murlok.io, Warcraft Logs und Battle.net gemessen. Und es
vergleicht das mit dem, was *du* gerade trägst und im Beutel hast, damit
du weißt, was noch fehlt.

Vier Wege hinein: der **Minimap-Knopf**, das runde **MetaCodex**-Symbol am
Charakterfenster, **`/mc`** oder die Addon-Leiste der Minimap. Beide
Knöpfe sind ab Werk an, beide lassen sich ziehen, und beide lassen sich
unter Einstellungen abschalten.

---

## Auf einen Blick

- **Talentbuilds mit Import-String** — der häufigste Build und seine
  Alternativen, je Dungeon in M+, je Boss im Raid, je Klammer im PvP.
  Kopieren, einfügen, fertig — oder direkt am Talentfenster laden.
- **Wo jedes Stück fällt** — jeder aktuelle Dungeon und jeder Raidboss mit
  der vollen Beuteliste deiner Spezialisierung, und Tooltips auf der Stufe, die
  *dein* Schlüsselstein gibt.
- **Favoriten** — markier die Stücke, hinter denen du her bist; das Addon
  sagt, wo die meisten fallen, und meldet sich, wenn eines für jemand
  anderen droppt.
- **Im Tooltip** — welche anderen Spezialisierungen dieses Stück tragen und zu wessen
  Werten es passt. Die Antwort auf jede kriegsgebundene Beute.
- **Verzauberungen & Steine gegen deine Ausrüstung** — was noch offen ist,
  was du schon hast, was du kaufen musst.
- **Verbrauchsgüter**, gruppiert nach Art, mit Bestand und Ziel.
- **Zielwerte**, gemessen an den Besten, deine Werte daneben — und die
  Schwellen des abnehmenden Ertrags markiert, wo du darüber liegst.
- **Rassen** — welche Rasse die Besten deiner Spezialisierung spielen, und was eine
  Rasse an Schaden bringt.
- **Rotation** (Beta) — was du drückst, in ganzen Sätzen: die Priorität
  aus SimulationCraft, zugeschnitten auf den Build der Top-Spieler, je
  Heldenbaum. Für Heiler, was Top-Heiler wirklich wirken, gemessen.
- **Gruppen & Klassen** — wer oben mit wem spielt: die häufigsten
  M+-Gruppen, die Raid-Aufstellungen, die Spezialisierungen unter den Besten im PvP.
- **Top-Spieler**, klickbar — ihr Talentbuild mit Import-String, ihre
  komplette Ausrüstung, ihr Profil.
- **Erinnerung** vor dem Start und am Auktionshaus — und ein Reiter, der
  zeigt, was sie prüft.
- **Guides** verlinkt, nie kopiert.
- **Eine Einkaufsliste neben dem Auktionshaus**: was noch fehlt, mit
  Balken und Zahl, und ein Klick sucht es.
- **Einkaufslisten an Auctionator** mit Stückzahlen; **Shift-Klick**
  verlinkt jeden Gegenstand in den Chat oder ins Suchfeld des Auktionshauses.
- **Jede Aktivität, jede Spezialisierung, vier Plattformen** — und nichts angezeigt,
  was keine Plattform beantworten kann.
- **Deutsch, Englisch und vereinfachtes Chinesisch**, auf jedem Client richtig.

---

## Die Reiter

### Überblick

**Guides** — Verweise auf die geschriebenen Guides zu deiner
Spezialisierung: Wowhead (Rotation und BiS), Method, Archon, murlok. Ein Klick legt die
Adresse zum Kopieren hin — ein Addon kann keinen Browser öffnen, aber den
Weg dorthin kurz machen.

**Rotation** (Beta) — Was du drückst, in ganzen Sätzen: „Nutze Aszendenz
auf Abklingzeit", „Wirke Lavaeruption, wenn Meister der Elemente nicht
aktiv ist", und am Ende der Füller. Für Schadensklassen und Tanks ist es
die Priorität, die SimulationCraft spielt, zugeschnitten auf den Build,
den die gemessenen Top-Spieler deiner Spezialisierung spielen — Talente, die sie
nicht nehmen, und Zauber eines Heldenbaums, den sie nicht spielen,
fallen heraus. Eine Rotation je Heldenbaum, mit einem Dropdown, wo genug
Top-Spieler jeden spielen, je Aktivität und Schwierigkeit. Reiter für
**Einzelziel**, **Flächenschaden** (mit der Zielzahl, ab der er gilt),
**vor dem Pull** und **Tränke & Schmuck**; darunter, was du **in
Bewegung** nutzt, und darüber ein **Beispiel-Ablauf**, gemessen an
Raid-Pulls. Dieser Teil ist simuliert, nicht gemessen, und die Karte sagt
das. **Heiler** bekommen keine Simulation, weil SimulationCraft keine
Heilung simuliert: ihre Karte zeigt, was Top-Heiler auf Warcraft Logs
wirken — Einzel- und Gruppenheilung als zwei Listen, Schaden, der heilt,
und die großen Abklingzeiten danach, wen sie schützen. Als Beta markiert:
noch nicht jede Zeile ist von Hand geprüft.

**Zielwerte** — Welche Sekundärwerte die Besten in welcher Höhe tragen,
gemessen als Median aus echten Kämpfen. Zwei Balken je Wert: das Ziel und
dein Stand. Grün, sobald du da bist; sonst steht dabei, wie viel fehlt.

Ab einer gewissen Wertung bringt jeder weitere Punkt weniger. Wo deine
eigene Wertung über so einer Schwelle liegt, färbt sich der Teil des
Balkens dahinter rot, ein Strich markiert die Schwelle, und rechts steht
„über der Schwelle"; eine Karte darunter erklärt, was ein Punkt dort noch
bringt und was 100 weitere wert sind. Die Zahlen werden beim Spiel selbst
erfragt und stehen nirgends fest, also stimmen sie auch, wenn Blizzard die
Schwellen verschiebt. Die meisten werden das nie zu sehen bekommen — die
gemessenen Zielwerte liegen fast durchweg unter der ersten Schwelle, und
eine Warnung, die nie zutrifft, überliest man bald.

**Rassen** — Welche Rasse die gemessenen Top-Spieler deiner Spezialisierung spielen,
und was eine Rasse bringt. Zwei Zahlen je Zeile. **Gespielt** kommt von
raider.io: jeder Spieler der besten M+-Läufe und die Profile der besten
Raid- und PvP-Spieler, jeder einmal gezählt. Hat eine Aktivität allein
weniger als fünfzehn gemessene Spieler, springt ihre Familie ein — alle
Raid-Schwierigkeiten, alle PvP-Klammern —, denn die Rasse wird je Charakter
gewählt und nicht je Aktivität; das Tooltip sagt, wann das passiert ist.
**Simuliert** kommt von bloodmallet.com (SimulationCraft): der
DPS-Vorsprung gegenüber der schwächsten Rasse, bei 1, 3 oder 5 Zielen in
M+ und 1 oder 3 im Raid. Unter 0,2 % gilt als gleichauf, denn so groß ist
der Fehler der Simulationen. Heiler, Augmentation, Verwüstung, Gleichgewicht
und Wächter haben dort keine Rassen-Simulation und zeigen nur, was gespielt
wird.

Eine Liste über beide Fraktionen, sortiert nach dem simulierten Vorsprung,
auf Horde oder Allianz eingrenzbar, mit den Rassen beider Seiten darunter.
Das Tooltip listet die Rassenfähigkeiten so auf, wie die Charaktererstellung
sie beschreibt.

**Top-Spieler** — Wer diese Spezialisierung gerade oben spielt, je Aktivität. Ein
Klick öffnet das Profil *im Fenster*: seinen Talent-String (mit Vermerk, ob
er zur Aktivität passt), seine komplette Ausrüstung — Tooltips zeigen
jedes Stück genau so, wie er es trägt — und die Adresse seines Profils.

**Gruppen & Klassen** — Wer oben mit wem spielt. In **M+** die häufigsten
Fünfergruppen und die Spezialisierungen je Rolle, aus den hohen Schlüsseln
(raider.io) und +7 bis +21 (Warcraft Logs), auch je Dungeon; ob eine
Gruppe Kampfrausch und Wiederbelebung im Kampf mitbringt, steht dabei,
wo sie fehlen. Im **Raid** je Schwierigkeit, in wie vielen Kills eine
Spezialisierung steht und wie oft im Schnitt. Im **PvP**, welche Spezialisierungen unter den
Top-Spielern jeder Klammer stehen. Deine eigene Spezialisierung ist markiert. Was
gespielt wird, kein Beweis, was am stärksten ist — auch das sagt die
Karte.

### Talente

**Talente & Builds** — Der häufigste Build als eine Zeile: Klick, String
kopieren, im Talentfenster bei „Importieren" einfügen. Darunter bis zu sechs
Alternativen, jede beschrieben als *„Talent X statt Talent Y"*, damit du
siehst, worin sich die Meinungen unterscheiden — und jede mit eigenem
String. Dann die umstrittenen Talente (die, die zwischen 15 und 85 % der
Besten nehmen) und bei PvP die PvP-Talente in eigener Gruppe. Bei M+
zusätzlich je Dungeon wählbar, im Raid je Boss — nach Raid gruppiert, wenn
mehrere laufen.

**Omnium-Foliant** — Welche Rune die Besten nehmen, Reihe für Reihe, mit
der Zahl der Spieler, auf der jede Reihe ruht. Er steht neben den Talenten
und nicht in ihnen, weil er aus einer eigenen Messung stammt — und er sagt,
welche Art Antwort eine Reihe ist: Wo niemand beim Wählen zu beobachten
war, steht, dass sie erschlossen und nicht gesehen ist, und eine Reihe mit
nur einer Rune sagt das, statt eine Entscheidung vorzutäuschen.

### Ausrüstung

**Beliebt** — Je Platz die fünf meistgetragenen Gegenstände mit Anteil,
Gegenstandsstufe, höchster Schlüsselstufe, Set- und Handwerksmarke und
**Fundort**: welcher Boss in welcher Instanz, welcher Händler, oder ehrlich
„kein Instanzdrop". Oben rechts wählst du *deinen* Schlüsselstein — nach
Aufwertungspfad wie in KeystoneLoot (Champion / Held / Große Schatzkammer)
— und jedes Tooltip zeigt den Gegenstand auf genau der Stufe, die du dafür
bekämst, mit „Held 3/8" im Tooltip. Was du schon trägst oder dabeihast,
sagt es — **angelegt** oder **liegt schon im Gepäck**.

**Fundorte** — Wohin man dafür geht. Jeder aktuelle Dungeon und jeder
Raidboss listet alle Drops deiner Spezialisierung, direkt aus dem Abenteuerführer des
Spiels mit seinem Klassen- und Spezialisierungsfilter — dieselbe Liste wie sein
Beute-Reiter, nicht nur die Stücke, die Top-Spieler tragen. Was gemessen
wurde, trägt seinen Anteil daneben. Dungeons und Raids stehen immer beide
da, egal welche Aktivität gewählt ist, und Raids sind nach Bossen in der
Reihenfolge des Abenteuerführers geteilt. Handwerk, Set, PvP und Weltbeute
stehen unten in einer Karte **Anderswo**.

Ein Klick markiert ein Stück als **Favorit** — goldener Rahmen und Stern,
je Charakter und Spezialisierung — und eine Hinweiszeile nennt die Instanz, in der die
meisten deiner Favoriten fallen. Ein grüner Haken sitzt auf allem, was du
schon hast: angelegt, oder irgendwo in Taschen, Bank, Reagenzien- oder
Kriegsmeutebank. **Hervorhebung** markiert, wonach du suchst: Favoriten
gold, das meistgetragene Stück je Platz lila (bei Ringen und Schmuck die
ersten zwei), passende Zweitwerte türkis. Eine Legende über der Liste sagt,
was was ist; der Rahmen zeigt die wichtigste Markierung, ein Punkt in der
Ecke eine zweite.

**Tier-Set, Handwerk & Verzierungen** — Drei Fragen, die die
Ausrüstungsliste allein nicht beantwortet, alle aus denselben Profilen
gezählt: welche Set-Teile getragen werden und wie viele davon; welche
Handwerksstücke getragen werden, mit dem Wertepaar, das ihre Träger gewählt
haben, und den gemessenen Gegenstandsstufen — beides auswählbar, damit man
vergleichen kann; und welche **zwei** Verzierungen zusammen getragen werden,
denn die Kombination ist die Entscheidung, und das Tooltip zeigt beide.

### Vorbereitung

**Verzauberungen & Steine** — Was die Besten auf welchem Platz tragen, mit
zwei Alternativen je Platz und dem besonderen Sockel getrennt. Verglichen
mit deiner Ausrüstung, und zwar richtig: Ein Platz gilt als erledigt, wenn
**die empfohlene Verzauberung** drauf ist, nicht wenn irgendeine drauf ist.
Eine andere sagt es mit Namen und bleibt auf der Liste. Leere Sockel werden
gezählt, der besondere Sockel am Stein, der drinsteckt, und deine Taschen
und deine Bank werden abgezogen. Qualitätsstufen zählen mit: eine höhere
Stufe in der Tasche deckt den Bedarf, eine niedrigere steht dabei, deckt
aber nicht. Rechts steht, was du noch brauchst. Ein Dungeon-Wähler engt
alles auf einen Dungeon ein; die Vorgabe sind alle.

**Verbrauchsgüter** — Ein Klick auf eine Zeile sagt, **was du selbst
nimmst**: deine Wahl aus deinen eigenen Taschen rückt nach oben, ihr
Bestand wird gezählt, und Einkaufsliste wie Erinnerung kaufen diese. Eine
billigere Speise, die niemand misst, ist trotzdem deine Speise. Gruppiert
nach Art: Fläschchen,
Speise, Kampftrank, Heiltrank, Waffenbuffs (Öle, Wetzsteine), Runen. Je
Gruppe der Anteil der Spieler und die höchste Schlüsselstufe, bei der es
noch benutzt wurde. Dazu dein Bestand — in jeder Qualitätsstufe — und eine
Zielmenge, die du per Klick einstellst.

**Erinnerung** — Was das Addon prüft, bevor es losgeht: je Verbrauchsart
der Stand gegen dein Ziel (reicht / knapp / leer), die Verzauberungen und
Steine, die an deinem Charakter noch fehlen, und die Einstellungen dazu.
Beim Betreten von Dungeon oder Raid sagt es dir, was fehlt. Am
Auktionshaus geht daneben eine schmale **Einkaufsliste** auf: jeder
fehlende Posten mit Symbol, Balken und „14 von 20", ein Klick sucht ihn,
Shift-Klick verlinkt ihn. Sie zieht mit, während du dort stehst, und sie
lässt sich abschalten. **Wie** die Erinnerung selbst sich meldet,
wählst du: Chatzeile, eigenes ziehbares Fenster, Schlachtzugswarnung über
dem Bild, Ton, beliebig kombiniert. Die Chatzeile trägt echte
Gegenstandslinks zum Draufzeigen und Shift-Klicken und einen Link, der
das Addon auf deiner Liste öffnet. Das Fenster listet die Gegenstände mit
Symbol und hat dieselben zwei Knöpfe wie das große. Eine Vorschau zeigt
genau das, was käme.

### Über

**Einstellungen** — Jedes An und Aus steht unter **Funktionen**:
Minimap-Knopf, Knopf am Charakterfenster, der Build-Knopf am Talentfenster,
die Tooltip-Zeilen, das Fenster bei einem gefallenen Favoriten, die
Erinnerung und die Einkaufsliste am Auktionshaus. Was eine Funktion fein
einstellt — Mengen, Schwellen, wie sie sich meldet —, steht direkt daneben,
in den Gruppen **Knöpfe**, **Tooltip**, **Beute** und **Erinnerung**. Unter
**Fenster** liegen Schriftgröße, Sprache, mit welcher Aktivität das Fenster
aufgeht, und ein Zurücksetzen für Lage und Größe. Jede Einstellung ist ein
Menü zum Auswählen, kein Wert zum Durchklicken.

**Info** — Version, Stand des Katalogs, wann jede Plattform zuletzt
gemessen hat, und ob Auctionator da ist.

---

## Außerhalb des Fensters

**Builds am Talentfenster** — Ein Knopf unten am Talentfenster öffnet
die Builds deiner aktiven Spezialisierung — des Baums daneben, egal, was das
Fenster gerade zeigt; ein Klick lädt einen davon, über dieselbe
Methode, die auch Blizzards Import-Dialog benutzt. Je Dungeon und je
Boss wählbar, gegliedert wie im Fenster. Shift-Klick kopiert statt zu
laden, im Kampf sagt es das, und scheitert es, landet der String im
Kopierfeld. Der Knopf ist ziehbar, die Liste hängt an ihm — welche Ecke
bei dir frei ist, wissen wir nicht.

**Die Vorschau im Baum** — Wer mit der Maus über einen Build fährt,
sieht ihn im Talentbaum selbst: grün um das, was dazukäme, rot um das,
was wegfiele. Gegen **deinen** Baum, nicht gegen den häufigsten Build:
in den Daten steht je Build die vollständige Talentliste, der Client
sagt, welche Knoten du hast — auch die, die das Spiel umsonst gibt und
die kein Build wegnehmen kann —, und der Unterschied dieser beiden
Mengen ist die Antwort. Ein Stern je Zeile hält die Vorschau fest, damit
du die Maus wegnehmen und nachlesen kannst, was ein markiertes Talent
tut — an jedem Talent steht Blizzards eigenes Tooltip. Was keinen Rahmen
bekommt, wird mit Grund benannt, und der nützlichste davon ist *dieser
Build spielt einen anderen Held-Baum als du* — was der Baum dir nicht
zeigen kann, weil der andere gar nicht gezeichnet wird.

**Im Gegenstands-Tooltip** — Zwei Zeilen, und nur dort, wo sie etwas wert
sind. *Auch getragen von* nennt die anderen Spezialisierungen, die dieses Stück tragen,
mit ihrem Anteil und der Aktivität, in der es gemessen wurde — die Frage
hinter jeder kriegsgebundenen Beute: taugt das für einen meiner anderen
Charaktere? Zwei Zeilen als Vorgabe, alle, solange Shift gedrückt ist.
*Werte passen zu* antwortet für Stücke, die keine Messung kennt, eine Tiefe
oder eine Weltbeute: wessen zwei höchste gemessene Werte genau die darauf
sind, wobei Rüstungsart und Hauptwert entscheiden, wer es überhaupt tragen
könnte.

Beides erscheint nur dort, wo das Stück einen anderen Charakter noch
erreichen kann — kriegsgebunden, beim Anlegen gebunden, ungebunden, oder
noch innerhalb der Handelsfrist einer Dungeon- oder Raidbeute. Und beides
schweigt, wo die Antwort geraten wäre: eine Quelle ohne bekannte Stichprobe
von mindestens fünfzehn Spielern trägt nichts bei, unter zwanzig Prozent
ist kein „getragen von", und ein Schmuck ist sein Effekt und nicht seine
Werte — und Effekte misst hier niemand. **`/mc fit`** schreibt für den
Gegenstand unter der Maus Schritt für Schritt auf, warum eine Zeile dort
steht oder eben nicht.

**Wenn ein Favorit droppt** — Fällt ein von dir markiertes Stück — in
irgendeiner Spezialisierung dieses Charakters — für jemand anderen, geht nach dem Boss
oder am Ende des Dungeons ein kleines Fenster auf und sagt, was es war und
wer es bekommen hat, als Name-Realm in seiner Klassenfarbe. Ein Klick
flüstert ihn an und fragt nach dem Handel — immer auf Englisch, denn es
geht an Spieler von jedem Realm. Im Schlüsselstein oder Bosskampf
unterbindet das Spiel Flüstern von Addons; dann sagt der Knopf „Wartet…",
und die Nachricht geht von allein raus, sobald es vorbei ist. Abschaltbar
unter Einstellungen → Beute.

**Im Kampf** — MetaCodex geht nicht auf, solange *du* kämpfst, und schließt
sich, wenn ein Kampf beginnt: Das Spiel hält deine Kampfwertungen dort
geheim, und die Zielwerte stünden auf nichts. Im laufenden Schlüsselstein
bleiben sie die ganze Zeit geheim, auch zwischen den Pulls — deshalb öffnet
das Fenster, während die Gruppe ohne dich pullt, und zeigt die Werte, die
es sich vor dem Lauf gemerkt hat, so gekennzeichnet. Sie ändern sich dort
ohnehin nicht; die Ausrüstung ist dieselbe.

---

## Bedienung

- **Spezialisierung** (Kopfzeile links): die eigene ist voreingestellt.
  Jede andere Klasse und Spezialisierung ist wählbar.
- **Aktivität**: M+, Raid, PvP — in Untermenüs. Es steht nur da, wozu es
  für den aktuellen Reiter Daten gibt.
- **Plattform**: einzeln oder alle. Wo eine Plattform zu einem Reiter
  nichts hat, wird sie gar nicht erst angeboten; bleibt nur eine, gibt es
  keinen Knopf.
- **Dungeon / Boss** (bei Talenten): alle acht Dungeons der Saison, oder
  jeder Boss jedes laufenden Raids.
- **Held-Talente** (bei Talenten): alle Bäume oder einer — die Talente und
  Builds nur dieses Baums, mit seinem Anteil an den Besten.
- **Fraktion** (bei Rassen): beide, oder nur Horde oder Allianz.
- **Schlüsselstein** (bei Ausrüstung): Champion / Held / Große Schatzkammer,
  jede Stufe mit den Schlüsseln, die sie geben.
- **Kategorie / Platz**: Listen lassen sich auf einen Platz oder eine Art
  eingrenzen.
- **Fenster**: an der Ecke unten rechts ziehbar; Position und Größe werden
  gemerkt. `/mc scale` skaliert zusätzlich für große und kleine Bildschirme.
- **Klick auf eine Zeile**: kopiert einen String, öffnet ein Profil, stellt
  eine Zielmenge ein, markiert einen Favoriten — je nachdem, was die Zeile
  ist.
- **Shift-Klick auf eine Zeile mit Gegenstand**: verlinkt ihn — in den
  Chat, oder bei offenem Auktionshaus direkt ins Suchfeld. Ctrl-Klick:
  Ankleideraum.
- **Einkaufsliste anlegen / Jetzt suchen** (unten, bei Verzauberungen,
  Verbrauchsgütern und Erinnerung): übergibt an **Auctionator** — eine
  Liste je Reiter, mit Stückzahlen. Beide brauchen ein offenes
  Auktionshaus und sagen im Tooltip, warum sie grau sind, wenn es zu ist.
  Ohne Auctionator stehen die Knöpfe gar nicht erst da — MetaCodex zeigt
  alles trotzdem, nur die Übergabe fällt weg.

**Slash-Befehle:** `/mc` öffnet · `/mc scale 0.6–1.6` Fenstergröße ·
`/mc remind` schaltet die Erinnerung · `/mc lang de|en|zh|auto` Sprache ·
`/mc fit` warum eine Tooltip-Zeile da ist oder nicht · `/mc probe`
Selbsttest zum Kopieren · `/mc reset` setzt die Auswahl zurück.

---

## Woher die Daten kommen — und warum man ihnen trauen kann

| Plattform | Liefert |
|---|---|
| **raider.io** | M+: Ausrüstung, Verzauberungen, Steine, Talente mit fertigem Import-String. Die Profile der Top-Spieler, die Rasse, die jeder spielt, und die Gruppen der hohen Schlüssel |
| **murlok.io** | Alle PvP-Klammern und M+: Ausrüstung, Steine, Zielwerte, Talente, Ranglisten der Top-Spieler |
| **Warcraft Logs** | Raid komplett und Verbrauchsgüter — das, was sonst niemand veröffentlicht. Die Gruppen von +7 bis +21 und die Raid-Aufstellungen, was Top-Heiler wirken, und die Abläufe von Raid-Pulls |
| **Battle.net** | Die offiziellen PvP-Ranglisten mit Wertung: jede Wertungsart, EU und US. Je Top-Spieler der Import-String der gewerteten Spezialisierung, PvP-Talente, Held-Baum, Ausrüstung, Verzauberungen und Steine — direkt aus Blizzards Charakterprofil — und welche Spezialisierungen oben stehen |
| **SimulationCraft** | Die Rotations-Priorität für Schadensklassen und Tanks — simuliert, nicht gemessen, und die Karte sagt das auch |
| **bloodmallet.com** | Die Rassen-Simulationen, ebenfalls aus SimulationCraft und ebenfalls als simuliert markiert |

Alles wird einmal täglich von der GitHub-Action `Daily data` gesammelt und
als fertiges Addon-Paket an das Release **nightly** gehängt; im Spiel wird
nichts aus dem Internet nachgeladen. Gespeichert werden nur IDs — Namen und
Symbole holt dein Client in seiner Sprache.

**Talent-Strings sind nie ausgedacht.** Jeder stammt aus dem Client eines
echten Spielers. Für Raid und PvP wird jeder String geprüft, bevor er als
Build gilt: die Talente im Profil müssen zu denen passen, die derselbe
Spieler im geloggten Kampf hatte (Raid) beziehungsweise zu dem, was fast
alle Top-Spieler nehmen (PvP). Was die Prüfung nicht besteht, wird nicht
als Build angeboten.

**Nichts wird angezeigt, was es nicht gibt.** Ein Reiter ohne Daten für die
gewählte Aktivität verschwindet aus der Leiste, eine Aktivität ohne Daten
aus dem Menü, eine Plattform ohne Daten aus der Auswahl. Beispiel: unter
PvP gibt es keine Verbrauchsgüter, weil keine Plattform sie dort misst —
also auch keinen Reiter dafür.

## In Zahlen

| | |
|---|---|
| **10 Aktivitäten** | M+ (High Keys), M+ (+7 bis +21), Raid Normal / Heroisch / Mythisch, 2v2, 3v3, Solo Shuffle, RBG, RBG Blitz |
| **4 Plattformen** | raider.io, murlok.io, Warcraft Logs, Battle.net — einzeln wählbar oder „Alle Plattformen". SimulationCraft liefert zusätzlich die Rotation, bloodmallet.com die Rassen-Simulationen |
| **Alle 40 Spezialisierungen** | Auch für Klassen, die du gar nicht spielst — zum Nachsehen oder zum Einkaufen für den Zweitcharakter |
| **3.008 Talent-Import-Strings** | Jeder von einem echten Spieler, jeder mit einem Klick kopierbar |
| **3.058 Spielerprofile** | Die Top-Spieler je Spezialisierung und Aktivität, mit kompletter Ausrüstung |
| **Jede Nacht neu** | Die Daten sind höchstens einen Tag alt |

---

## Was noch geplant ist

- **Ein Fundort für jeden Gegenstand** — Händler und Weltquellen für die
  Stücke, die noch „kein Instanzdrop" heißen.

---

## Voraussetzungen

- World of Warcraft Retail, aktueller Patch (12.1.5)
- **Auctionator** für die Übergabe ins Auktionshaus (optional)
- Die drei Datenaddons `MetaCodex_Data`, `MetaCodex_Dungeons`,
  `MetaCodex_Players` liegen bei und laden erst, wenn sie gebraucht werden —
  beim Login kostet MetaCodex nichts.
