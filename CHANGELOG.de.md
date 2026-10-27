# Changelog

Alle nennenswerten Änderungen an MetaCodex. Englische Fassung: `CHANGELOG.md`.

## [Unveröffentlicht]

### Neu

- **Vereinfachtes Chinesisch (zhCN)**, die ganze Oberfläche, übersetzt
  von Maple Saint (nanjuekaien1).

### Geändert

- **Rotation: Reiter und Heldenbaum.** Die Reiter sind schlichter Text,
  der offene in der Klassenfarbe unterstrichen. Der Heldenbaum ist ein
  Dropdown rechts in derselben Zeile - vorher standen dort zwei weitere
  Knöpfe direkt an den Reitern und sahen auf Deutsch aus wie ein Teil
  des letzten.

## [1.1.22] - 2026-10-26

### Neu

- **Rotation (Beta).** Ein neuer Abschnitt unter Überblick: was du
  drückst, in ganzen Sätzen - „Nutze Aszendenz auf Abklingzeit", „Wirke
  Lavaeruption, wenn Meister der Elemente nicht aktiv ist", „bevor die
  Aufladungen voll sind", „sobald du genug Wut hast", und am Ende der
  Füller.
  - **Schaden und Tanks**: die Priorität, die SimulationCraft spielt,
    zugeschnitten auf den Build, den die gemessenen Top-Spieler deiner
    Spec spielen. Talente, die sie nicht nehmen, und Zauber eines
    Heldenbaums, den sie nicht spielen, fallen weg. Eine Rotation je
    Heldenbaum (mit Umschalter, wo genug Top-Spieler jeden spielen), je
    Aktivität und je Schwierigkeit - Normal, Heroisch und Mythisch, die
    hohen Keys und +7 bis +21. Wo eine Stufe zu wenige Gemessene hat,
    springt die Aktivität als Ganzes ein, und die Karte sagt es.
  - **Einzelziel und Flächenschaden**: der AoE-Reiter sagt, ab wie
    vielen Zielen er gilt - ab der Zahl, bei der SimulationCraft in seine
    AoE-Liste wechselt. Wo es eine Spec gegen ein und viele Ziele gleich
    spielt, gibt es eine Liste, „Ein- und Mehrziel".
  - **Vor dem Pull** (was aufrecht bleibt, was vorab gewirkt wird),
    **Tränke & Schmuck**, was **in Bewegung** geht, und ein
    **Beispiel-Ablauf**, gemessen an Raid-Pulls.
  - Als Beta gekennzeichnet: sie ist neu, und noch nicht jede Zeile ist
    von Hand geprüft.
- **Für Heiler gemessen statt simuliert.** SimulationCraft simuliert
  keine Heilung, also zeigt die Heiler-Karte, was Top-Heiler auf
  Warcraft Logs wirken:
  - **Einzel- und Gruppenheilung** als zwei Listen. Wen ein Zauber
    heilt, sagt sein Spieltext; die Reihenfolge ist, wie oft sie ihn
    drücken.
  - **Schaden, der heilt**, nennt das Talent, über das er heilt - Sühne,
    Weg des Kranichs, Flamme des Lebensspenders.
  - **Große Cooldowns** danach, wen sie schützen: für die Gruppe, für
    einen Verbündeten in Not, zu deinem eigenen Schutz, und Werkzeuge
    für die Lage.
  - Tränke und Schmuck mit ihrem eigenen Symbol und Namen.
- **Gruppen & Specs.** Ein neuer Abschnitt unter Überblick: wer an der
  Spitze mit wem spielt.
  - **M+**: die häufigsten Fünfergruppen und die Specs je Rolle, aus den
    hohen Keys (raider.io) und +7 bis +21 (Warcraft Logs), auch je
    Dungeon - mit allen Dungeons als Rückfall, nie mit der anderen
    Klammer.
  - **Raid**: je Schwierigkeit, in wie vielen Kills eine Spec steht und
    wie oft im Schnitt.
  - **PvP**: welche Specs unter den Top-Spielern jeder Klammer stehen.

### Geändert

- **„Guides & Rotation" heißt jetzt „Guides".** Die Rotation hat einen
  eigenen Abschnitt.
- **Der Plattform-Knopf steht nur noch, wo er etwas ändert.** Rotation
  und Rassen hängen an keiner Plattform; dort ist er weg.
- **Keine Einkaufsknöpfe mehr unten im Fenster.** „Einkaufsliste
  anlegen" und „Jetzt suchen" standen unter jedem Abschnitt und nützen
  nur am Auktionshaus, wo die Liste daneben sie hat, wie auch die
  Erinnerung. „Auch kaufen für" im Spec-Menü ist mit ihnen gegangen.

### Behoben

- **Mönche und Furor-Krieger**: die Talent-Builds werden wieder gegen
  den aktuellen Talentbaum gelesen, mit Heldentalenten. Der Windläufer
  hatte keinen Heldenbaum, Furor-Builds wurden gegen einen Testbaum
  gelesen.
- **Omnium-Foliant**: Reihe 5 fehlte bei Specs mit weniger als zehn
  Gemessenen in einer Aktivität (Treffsicherheit, Frost). Sie kommt
  jetzt aus der nächstliegenden Aktivität, die sie hat, und ihre
  Überschrift sagt, woher. Im Spec-Menü des Druiden steht kein leerer
  fünfter Eintrag mehr.

## [1.1.21] - 2026-10-19

### Behoben

- **MetaCodex ging in einem Mythisch+-Schlüssel nicht auf.** In einem
  laufenden Schlüssel hält das Spiel deine Kampfwertungen den ganzen Lauf
  geheim, auch zwischen den Pulls, und v1.1.20 hielt das für einen
  Kampf. Jetzt hält nur dein eigener Kampf das Fenster zu - es geht auf,
  während die Gruppe ohne dich pullt, und schließt sich weiter, wenn du
  selbst kämpfst.
- **Deine Werte im Schlüssel.** Die Zielwerte zeigten dort keine eigenen
  Bahnen. MetaCodex merkt sich deine Wertungen jetzt, wann immer das
  Spiel sie herausgibt - beim Betreten einer Welt oder Instanz, also vor
  dem Start des Schlüssels, und bei jedem Wechsel der Ausrüstung - und
  zeigt sie im Lauf mit „Stand vor dem Lauf". Dort ändern sie sich
  nicht; die Ausrüstung ist dieselbe.

## [1.1.20] - 2026-10-19

### Neu

- **Rassen.** Ein neuer Abschnitt unter Überblick: welche Rasse die
  gemessenen Top-Spieler deiner Spec spielen, und was eine Rasse an
  Schaden bringt.
  - **Gespielt** kommt von raider.io - jeder Spieler der besten 2.000
    M+-Läufe und die Profile der besten Raid- und PvP-Spieler, jeder
    einmal gezählt. Wo eine Aktivität allein weniger als fünfzehn
    Gemessene hat, springt ihre Familie ein (alle Raid-Schwierigkeiten,
    alle PvP-Klammern), und sonst alle Aktivitäten der Spec - die Rasse
    wählt man je Charakter, nicht je Aktivität. Der Tooltip sagt, wann.
  - **Simuliert** kommt von bloodmallet.com (SimulationCraft): der
    DPS-Vorsprung gegenüber der schwächsten Rasse, bei 1, 3 oder 5
    Zielen in M+ und 1 oder 3 im Raid. Was innerhalb von 0,2 % an der
    besten liegt, gilt als gleichauf - die Sims haben etwa 0,1 %
    Messfehler. Heiler, Augmentation, Verheerung, Gleichgewicht und
    Wächter haben dort keine Rassen-Sims und zeigen nur, was gespielt
    wird.
  - Eine Liste über alle Fraktionen, nach dem simulierten Vorsprung
    sortiert; ein Filter grenzt auf Horde oder Allianz ein, Rassen
    beider Seiten stehen bei beiden. Der Tooltip zeigt die
    Rassenfähigkeiten, wie die Charaktererstellung sie beschreibt.

### Behoben

- **Das Fenster zeigte den vorigen Abschnitt** unter einer neuen
  Überschrift, wenn man es im Kampf öffnete. Das Spiel hält die
  Kampfwertungen dort geheim, und daran brach der Aufbau der Zielwerte
  ab. MetaCodex geht im Kampf jetzt gar nicht erst auf - auch nicht,
  solange das Spiel deine Werte geheim hält, etwa wenn du tot bist und
  die Gruppe noch kämpft - und schließt sich, wenn ein Kampf beginnt.

## [1.1.19] - 2026-10-19

### Neu

- **„Favorit gedroppt!"** Droppt ein Stück, das du als Favorit markiert
  hast - in irgendeiner Spec des Charakters -, bei jemand anderem, geht
  nach dem Boss oder am Ende des Dungeons ein kleines Fenster auf: das
  Item und wer es bekommen hat, als Name-Realm in seiner Klassenfarbe.
- **Anflüstern mit einem Klick**: „Hey, do you need [Item]? If not, I'd
  be really happy if you could trade it to me :)" - immer auf
  Englisch, weil es an Spieler von jedem Realm geht, und immer an
  Name-Realm. Während eines Schlüssels oder Bosskampfs sperrt das Spiel
  Flüstern von Addons; dann steht am Knopf „Wartet …", und das Flüstern
  geht von selbst raus, sobald das vorbei ist.
- Abschaltbar unter Einstellungen → Beute.
- **Ein grüner Haken an Drops, die du schon hast** - in den Fundorten,
  angelegt oder irgendwo in Taschen, Bank, Reagenzien- oder
  Kriegsmeutenbank. Der Tooltip sagt es auch, die Legende erklärt ihn.

### Geändert

- **Einstellungen**: die An/Aus-Schalter stehen in vier Gruppen -
  Knöpfe, Tooltip, Beute, Erinnerung - statt in einer langen Liste.

### Behoben

- **Schurken sahen kein Waffenöl.** Sie wurden wie Schamanen behandelt,
  deren eigener Waffenbuff den Platz des Öls belegt. Die Gifte des
  Schurken sind aber ein Buff am Schurken, nicht an der Waffe - und
  gemessen tragen 95-100 % der Top-Schurken in M+ ein Öl. Es steht
  wieder bei Verbrauchsgütern, Erinnerung und Einkaufsliste.

## [1.1.18] - 2026-10-17

### Behoben

- **Lua-Fehler an der Scrollleiste.** Beim Überfahren oder Ziehen des
  Griffs kam "Style.lua:382: attempt to call a nil value". Der Griff
  wurde mit einer Funktion für Texte eingefärbt. Gemeldet auf
  CurseForge, mit dem ganzen Log - danke.
- Als Spielversion steht nur noch 12.1.5; 12.1.0 entfällt.

## [1.1.17] - 2026-10-15

### Geändert

- **Fundorte, neu gebaut.** Jeder laufende Dungeon und jeder Raid-Boss
  zeigt jetzt alle Drops für deine Spec - direkt aus dem
  Abenteuerjournal des Spiels mit seinem Klassen- und Spec-Filter,
  dieselbe Liste wie dort im Reiter Beute. Vorher standen nur die
  Stücke da, die Top-Spieler tragen, verglichen mit dem Angelegten.
  Was gemessen ist, trägt weiter seinen Anteil. Dungeons und Raid
  stehen immer beide da, egal welche Aktivität gewählt ist; der Raid
  je Boss in der Reihenfolge des Journals. Hergestelltes, Set-Teile,
  PvP- und Welt-Stücke stehen unten in einer Karte „Anderswo“.
- **Favoriten.** Ein Klick auf ein Item markiert es als Favorit -
  goldener Rahmen und Stern -, je Charakter und Spec. Die Hinweiszeile
  nennt, wo die meisten deiner Favoriten fallen. Die alten Sterne
  werden übernommen.
- **Hervorhebung** um „Am häufigsten getragen (je Platz)“ erweitert:
  das meistgetragene Stück je Platz, bei Ringen und Schmuck die ersten
  zwei. Jede Markierung hat ihre Farbe - Favorit gold, Meistgetragen
  lila, passende Werte türkis -, und eine Legende über der Liste sagt,
  welche was heißt. Der Rahmen zeigt die wichtigste, ein kleiner Punkt
  in der Ecke eine zweite. „Alle gewählten Werte müssen drauf sein“
  gilt nur noch für die Werte.
- Weggefallen in den Fundorten: der Vergleich mit angelegten Items und
  Itemlevel, die Reihenfolge und „Ignorieren“.

### Behoben

- **„Data/Catalog.lua fehlt oder ist leer. tools/build-catalog.js
  ausführen.“** Mehr sah ein Spieler nach der Erstinstallation nicht -
  eine Meldung für den, der das Addon baut. Lädt das Spiel den
  Datenordner nicht, sagt MetaCodex jetzt in klaren Worten, was zu tun
  ist, und ein in der AddOn-Liste abgeschalteter Datenordner wird von
  selbst wieder eingeschaltet.
- Die TOC-Dateien nennen Interface 120105, für Patch 12.1.5.

## [1.1.16] - 2026-10-14

### Neu

- **Abnehmender Ertrag bei den Zielwerten.** Ab einer bestimmten Menge
  Wertung bringt jeder weitere Punkt eines Werts weniger: bis 30 % voll,
  danach 90 %, ab 39 % 80 % und so weiter. Liegt deine eigene Wertung
  hinter so einer Grenze, wird der Teil der Bahn dahinter rot, ein
  Strich markiert die Grenze, und rechts steht „über Grenze". Unter den
  Bahnen erklärt eine Karte es in einer kleinen Tabelle: der Wert, ab
  wo der Abschlag gilt, was ein Punkt noch bringt und was 100 Punkte
  mehr dort wert sind.
- Die Zahlen kommen vom Spiel selbst, live gefragt – nichts ist fest
  eingetragen, die Anzeige stimmt also auch, wenn Blizzard die Grenzen
  verschiebt. Nachgemessen auf Vergeltungs-Paladin und
  Elementar-Schamane: dieselbe Kurve für alle Klassen und Speccs. In
  Punkten statt Prozent, weil ein Prozentwert bei Meisterschaft der
  Wert vor dem Faktor der Spezialisierung wäre und nicht zum
  Charakterfenster passte.
- Zu sehen erst, wenn es zutrifft. Die gemessenen Zielwerte liegen
  fast alle vor der ersten Grenze, die meisten sehen es also nie – eine
  Warnung, die nie zutrifft, liest bald niemand mehr.
- **„Auch getragen von" lässt sich einzeln abschalten**, ohne die
  Rangnummern an den Werten zu verlieren. Gewünscht auf CurseForge.
- **Einstellungen → Funktionen**: alle An/Aus-Schalter an einer Stelle –
  Minimap-Knopf, Knopf im Charakterfenster, Tooltip, andere Speccs im
  Tooltip, Erinnerung, Erinnerung beim Betreten, Einkaufsliste am
  Auktionshaus, Talentknopf. Vorher verteilten sie sich auf zwei
  Reiter, und man musste wissen, wo welcher wohnt. Was eine Funktion
  fein einstellt (Mengen, Schwellen), bleibt neben ihr.

### Geändert

- `/mc probe` misst alle Grenzen des abnehmenden Ertrags auf dem
  Charakter, auf dem es läuft.

## [1.1.15] - 2026-10-14

### Neu

- **„Auch getragen von" unter einem Gegenstand.** Welche anderen
  Speccs dieses Stück tragen, mit Anteil und der Aktivität, in der es
  gemessen wurde – die Frage hinter jedem kriegsmeutegebundenen Drop:
  taugt das einem meiner anderen Charaktere? Zwei Zeilen als Vorgabe,
  alles bei gehaltener Umschalttaste, und Umschalt wirkt sofort, nicht
  erst beim nächsten Überfahren. Die Aktivität steht einmal als
  Überschrift statt in jeder Zeile, und eine graue Zeile sagt, was die
  Zahlen sind: der Anteil der gemessenen Spieler dieser Spec.
- Nur Gemessenes, und nur dort, wo die Messung sagt, auf wie vielen
  Spielern sie ruht. Hinter „50 %" standen bei 2v2 zwei Spieler – einer
  davon trug das Stück. Quellen ohne bekannte Stichprobe von mindestens
  fünfzehn tragen deshalb nichts bei, und unter zwanzig Prozent ist es
  kein „getragen von". PvP ist genau deshalb nicht dabei. raider.io
  und Battle.net nennen ihre Stichprobe jetzt mit; vorher tat das nur
  Warcraft Logs.
- **„Werte passen zu"** für Stücke, die keine Messung kennt – ein Drop
  aus einer Tiefe, ein Weltdrop. Genannt werden die Speccs, deren zwei
  höchste gemessene Zweitwerte genau die auf dem Stück sind.
  Rüstungsart und Hauptwert entscheiden, wer es überhaupt tragen
  könnte; Waffenarten kommen aus der Messung (wer in den Daten einen
  Streitkolben trägt, kann einen führen). Wo die Antwort geraten wäre,
  schweigt es: Schmuckstücke sind ihr Effekt, nicht ihre Werte, und
  Effekte misst hier niemand.
- Es erscheint nur, wo das Stück noch zu einem anderen Charakter kann:
  kriegsmeutegebunden, beim Anlegen gebunden, ungebunden – und Beute
  aus M+ und Raid während ihres zweistündigen Handelsfensters. Der
  gemessene Block darüber steht immer; er sagt, ob du selbst richtig
  liegst.
- **/mc fit** – mit der Maus über einem Gegenstand schreibt es Schritt
  für Schritt, warum darunter etwas steht oder nicht.

### Behoben

- **Die Talentvorschau zählte Knoten, nicht Ränge.** Ein voller Baum
  zeigte „5 grün dazu, 0 rot weg": die fünf neuen Talente wurden mit
  zweiten Rängen bezahlt, die der Build nicht nimmt, und die waren
  unsichtbar. Ein Rang, der wegfällt, ist jetzt ein Abgang wie jeder
  andere.
- **Aufwertbare Kriegsmeuten-Teile tragen mehrere Hauptwerte** – Stärke
  UND Intelligenz, bis sie angelegt werden –, und das Spiel meldet nur
  den, der zum Charakter davor passt. Der grau dargestellte im Tooltip
  zählt jetzt mit; eine Brustplatte gilt nicht mehr als Zauberzeug.
- **Umhänge** tragen die Unterklasse „Stoff" und wären an drei
  Zaubererklassen gegangen. Jeder trägt einen Umhang.
- **Der Datenlauf hat zwei weitere Nächte verloren.** wago.tools
  antwortete eine Minute lang mit HTTP 503; der Katalog hatte eine
  eigene Geduld von genau einer Minute statt der gemeinsamen von
  viereinhalb, raider.io starb an der Datei, die der Katalog nicht mehr
  schreiben konnte, und das Veröffentlichen hielt an dieser fehlenden
  Nebendatei an. Danach öffnete Patch 12.1.5 bei Warcraft Logs einen
  neuen Ranglisten-Abschnitt, der leer bleibt, bis darin Kämpfe
  hochgeladen werden – Raid-Ranglisten fallen jetzt auf den vorigen
  Abschnitt zurück, bis sich der neue füllt.

## [1.1.14] - 2026-10-11

### Behoben

- **Der Rotations-Link führte ins Leere, bei allen vierzig Speccs.**
  Wowheads Seite hieß /rotation-cooldowns-abilities und gibt es nicht
  mehr. Seit Midnight endet die Adresse auf die Rolle:
  /rotation-cooldowns-pve-dps, -healer, -tank. Gemessen statt
  angenommen – alle vierzig Speccs wurden mit allen drei Rollen
  gefragt, und jede hat genau eine Seite, die antwortet: 27 dps,
  7 Heiler, 6 Tanks, keine mehrdeutig, keine ohne. Die drei übrigen
  Links (Best in Slot, Method, murlok.io) antworten ebenfalls für alle
  vierzig.
- Die Rolle kommt von deinem **Client**, der sie für jede Spec kennt,
  auch für eine, die du gerade nicht spielst. Die Spieltabellen tragen
  sie als zweite Quelle, und beide sind sich bei allen vierzig einig.
  Antwortet keine von beiden, bleibt /overview der Rückfall statt eines
  toten Links.
- **Vier Nächte hintereinander hat der Datenlauf nichts
  veröffentlicht.** Zweimal maß eine Prüfung das Wetter statt einer
  Regel – sie verlangte, dass ein Filter weniger Zeilen zeigt, während
  die ehrliche Antwort "alle" war. Einmal wurden zehn Minuten fertiger
  Messung weggeworfen, weil eine Abfrage für einen Nachschlag ihren
  Server nicht erreichte. Der Lauf schreibt seine Ernte jetzt auch
  dann, wenn der Nachschlag ausfällt, und wartet Minuten statt
  Sekunden auf einen Dienst, der kurz hängt.
- **Ein einzelner 504 von wago.tools hat eine ganze Aktivität des
  Nachtlaufs gekostet.** Am 8. Oktober starb er nach 143 Minuten, mit
  zwei Stunden fertig gesammelter Raiddaten auf der Platte; raid-normal
  fiel weg, weil ein Katalogabruf beim Gegenüber in eine
  Zeitüberschreitung lief. Ein solcher Fehler sagt nichts über unsere
  Anfrage – sie noch einmal zu stellen ist die richtige Antwort darauf.
  Jetzt fünf Versuche mit wachsenden Pausen, die zusammen über vier
  Minuten ergeben, und nur bei 5xx und Netzfehlern: einen 404 oder 403
  zu wiederholen hieße, dieselbe falsche Frage lauter zu stellen.
- **Der Build-Lauf hat drei der vier Regeltests ausgeführt.** Sie waren
  namentlich aufgezählt, ein vierter kam dazu – und wäre nie gelaufen.
  Ein Test, von dem niemand weiß, dass er nicht läuft, ist schlechter
  als keiner.

## [1.1.13] - 2026-10-07

### Neu

- **Tier-Set-Boni für die Spec, die du ansiehst**, nicht für die, die du
  spielst. Blizzard zeichnet die Boni eines Tier-Teils für deine aktive
  Spec; wer als Elementar den Wiederherstellungs-Schamanen nachschlägt,
  liest die falschen Boni zum richtigen Teil – und nichts sagt es ihm.
  Die Boni der gezeigten Spec stehen jetzt unter dem Tooltip, mit Namen.
  Nur wenn beide auseinanderfallen – stimmen sie überein, steht oben
  ohnehin das Richtige.
  Vorher gemessen: dieselbe Hose gibt je Spec andere Zauber zurück (262
  nennt 1296625/1296626, 263 nennt 1296627/1296628, 264 nennt
  1296629/1296630), die Abfrage beachtet die Spec also wirklich. Keine
  Klasse und keine Spec steht im Code – wir fragen den Client mit der
  gewählten Nummer, und darum gilt es für jede Klasse und jede Spec.
  Blizzards eigene Zeilen bleiben stehen: die Tooltips bauen sich aus
  Daten auf, und was man hineinschreibt, ist beim nächsten Durchlauf
  wieder weg – versucht und wieder verworfen. Stattdessen wird der Block
  darüber erklärt, in einem Satz, mit dem Namen der Spec, zu der er
  gehört. Unbeschriftet liest man ihn als die Antwort auf die Frage, die
  man gerade gestellt hat; ein Satz dreht das.
  Jede Zeile sagt, wie viele Teile sie verlangt – „Set (2):“ und
  „Set (4):“. Die Zahl stammt aus dem Namen des Zaubers selbst
  („... Class Set 2pc“), nicht aus der Reihenfolge; nur wo im Namen
  keine steht, entscheidet die Stelle, und das auch nur bei genau zwei
  Boni – so ist ein Klassenset gebaut.

## [1.1.12] - 2026-10-03

### Behoben

- **Der Knopf am Charakterfenster ließ sich hinter den Wertekasten
  ziehen und dann nicht mehr zurück.** Er lag zwanzig Rahmenebenen über
  dem Fenster, und Blizzards Kästen liegen höher – wer darüber zeichnet,
  bekommt auch die Maus, also steckte der Knopf dort fest. Zwanzig war
  geraten; jetzt wird gemessen, wie hoch die Rahmen in diesem Fenster
  wirklich liegen, und der Knopf sitzt fünf darüber. Umschalt-Rechtsklick
  setzt ihn weiterhin zurück, aber danach greift niemand, der gerade
  feststeckt.

## [1.1.11] - 2026-10-02

### Neu

- **Die Vorschau im Talentbaum.** Wer mit der Maus über einen Build
  fährt, sieht ihn im Baum selbst: grün um das, was dazukäme, rot um
  das, was wegfiele. Zwei Namen in einer Zeile sagen nicht, wo man
  hinklicken muss.
- **Gegen deinen eigenen Baum**, nicht gegen den häufigsten Build. In
  den Daten steht je Build die vollständige Talentliste – im Mittel 76
  Knoten –, und der Client sagt, welche Knoten du gekauft hast. Der
  Unterschied dieser beiden Mengen ist die Antwort.
- **Ein Stern je Zeile hält die Vorschau fest**, damit du die Maus
  wegnehmen und nachlesen kannst, was ein markiertes Talent tut. An
  jedem Talent im Baum steht Blizzards eigenes Tooltip, vollständig, mit
  Rangstufen.
- **Was keinen Rahmen bekommt, wird beim Namen genannt, mit Grund.**
  Drei Gründe, die Verschiedenes bedeuten – und der häufigste ist die
  wertvollste Auskunft überhaupt: dieser Build spielt einen anderen
  Held-Baum als du. Das sieht man dem Baum nicht an, weil der andere gar
  nicht gezeichnet wird.
- Im Fenster sagt die Zeile eines Builds im Zeiger, **welches Talent
  gegen welches** getauscht wird – mit Symbolen und mit dem, was die
  einzelnen tun.
- Ein Schalter für den Build-Knopf am Talentfenster, neben den anderen
  Wegen hinein. Er setzt sich in Blizzards Fenster an genau die Ecke, an
  der bei anderen Raider.IO sitzt – die Einstellung gab es, nur die
  Zeile, über die man sie erreicht, fehlte.
- Die Build-Liste hängt am Knopf, immer, und wandert mit ihm. Nur eine
  Sache lässt sich verschieben, denn zwei, die das unabhängig tun,
  laufen auseinander – und dann steht der Knopf oben im Baum und seine
  Liste unten.

### Geändert

- Die Liste geht neben ihrem Knopf auf statt über ihm, und der Zeiger
  hängt an der Liste statt an der Zeile: Knopf, Liste, Zeiger
  nebeneinander, immer an derselben Stelle.
- `/mc talents` schreibt seinen Bericht ins Kopierfenster statt in den
  Chat, wie der Probe-Bericht auch. Dreißig Zeilen Messwerte im Chat
  liest niemand, und herausholen kann man sie dort gar nicht.
- **In einer PvP-Klammer bekommen die PvP-Talente ein eigenes Fenster**
  neben den Builds. Blizzards Importkette enthält sie nicht – sie sitzen
  in drei Plätzen, die keine Importkette berührt –, also lädt sie kein
  Build, und die Vorschau kann sie nicht einrahmen. Gemessen sind sie
  trotzdem, und wer dort in einer Klammer steht, hat drei Plätze zu
  füllen. Mit Symbol, Anteil und dem Zaubertooltip des Spiels.
- **In manchen Klammern fehlten sie ganz.** Der Sammler behält nur
  Talente zwischen 15 und 85 Prozent – was 98 Prozent nehmen, steht
  ohnehin im Build. Für ein PvP-Talent gibt es aber keinen Build, und
  das Einhellige wegzuwerfen löschte die Auskunft damit komplett: beim
  Elementar-Schamanen in 3v3 blieben null von elf übrig, während 2v2
  vier hatte. Gerade die Einhelligkeit ist hier die Antwort. Greift mit
  dem nächsten Nachtlauf.

### Behoben

- **Der Build-Knopf am Talentfenster lag auf Blizzards eigener
  Belegungsauswahl** – bei jedem, der ihn nie gezogen hatte. Die Vorgabe
  war fest 12/12 von der linken unteren Ecke; im Client gemessen stehen
  dort zwei Felder auf derselben Höhe: die Auswahl bei x+48, y+26,
  200×30, und das Suchfeld bei x+268. Ein 30 Pixel hoher Knopf auf y+12
  schneidet beide an. Jetzt wird geschaut statt gezählt: eine Zeile über dieser
  Leiste, und dann von links nach rechts an allem vorbei, was dort schon
  liegt – egal von wem. Dem Knopf eines anderen Addons wird ausgewichen
  statt ihn zuzudecken; gefunden wird über die Rahmen selbst, also zählt
  auch eines, von dem wir nie gehört haben. Verschiebt ein Patch die
  Leiste, verschiebt sich der Knopf mit; ist nichts zu finden, bleibt es
  bei der alten Ecke.
- **Fundorte schnitt die Instanznamen ab, obwohl die Zeile halb leer
  war.** Die Namensspalte war fest 150 Punkte breit, bemessen für die
  Raidzeile mit ihren vierzehn Kästchen; ein Dungeon hat drei. Sie nimmt
  jetzt ein Drittel der Breite, zwischen 150 und 300.
- **Bei Talente stand kein Satz unter dem Titel**, nur die Lücke, in die
  einer gehört. Jede andere Seite sagt dort, wofür ihre Prozente stehen.
- **Ein Verbrauchsgut bei 14 von 20 sagte „reicht" und „6 fehlen" in
  derselben Zeile.** „Reicht" hieß, dass die Erinnerung still bleibt,
  nicht dass der Vorrat die Zielmenge erfüllt – die Schwelle dafür ist
  eine eigene Einstellung. Das Wort sagt das jetzt.
- **Die Build-Liste am Talentfenster kürzte jede Zeile** und zeigte den
  ganzen Text nirgends. Sie ist breiter, und sie antwortet im Zeiger.
- Der besondere Sockel, von dem es einen gibt, meldete „1 sockets".
- Die Einkaufsliste neben dem Auktionshaus hörte mitten im Satz auf.
- **Grüne und rote Kästchen standen im leeren Raum.** Das waren echte
  Knoten hinter der Build-Liste: die Rahmen lagen über allem, auch über
  dieser Liste, während das Symbol darunter verdeckt blieb. Die Rahmen
  sitzen jetzt knapp über ihrem eigenen Knopf.
- **Die Rahmen waren zwei Haarlinien und verschwanden.** Auf einem
  Talentsymbol, das selbst schon eine goldene Fassung trägt, sieht man
  einen Pixel nicht. Drei Pixel und eine leichte Einfärbung beantworten
  die Frage aus zwei Metern Abstand.
- **Ab sieben Talenten fielen die Beschreibungen ganz weg**, und dann
  nannte eine Zeile eine Wirkung und die nächste nicht, ohne dass man
  sah, warum. Jetzt trägt jedes Talent seinen Text; ab sieben gekürzt,
  am Wortende, mit Auslassungspunkten – damit man das Kürzen sieht statt
  es zu erraten.
- **Ein Talent, das der Baum unter einer zweiten Zauber-Nummer führt,
  bekam keinen Rahmen.** Im Spiel gemessen: der Baum trägt 443454
  „Schnelligkeit der Ahnen", unsere Daten 448861 – gleicher Name, andere
  Nummer, und `GetOverrideSpell` verbindet die beiden nicht. Über die
  Nummer allein hätte die Vorschau dieses Talent nie gefunden, bei
  keiner Klasse. Der Name ist die Brücke, und beide Seiten holen ihn aus
  deinem eigenen Client: unsere Daten speichern nur Nummern, der Name
  kommt immer aus dem Spiel. Damit stimmt er auf jedem Sprachclient und
  braucht keine Liste, die jemand pflegt. Die Nummer hat weiter Vorrang;
  der Name antwortet nur, wo sie nichts fand, und nur, wenn er eindeutig
  ist – tragen zwei Knoten denselben, wird keiner gewählt, denn ein
  Rahmen um den falschen sieht aus wie eine Auskunft. Auf dem Client, an
  dem sie gebaut wurde, brauchte sie ein Talent von siebenundsiebzig,
  und `/mc talents` zählt das mit, damit es eine gemessene Zahl bleibt.

## [1.1.10] - 2026-10-01

### Neu

- **Ein Aufbau für jeden Abschnitt**: Titel, der Satz, der die Frage
  beantwortet, die Wähler links beginnend, dann die Liste. Vorher
  standen sie neben dem Titel und wanderten mit ihrer Zahl – einer ganz
  rechts, drei weiter links, fünf in eine zweite Zeile.

- **Die Builds am Talentfenster.** Es zu öffnen ist der Moment, in dem
  man einen Build wählt; der Weg dahin war bisher: Addon öffnen, Build
  suchen, String kopieren, zurück, Importieren, einfügen. Ein Knopf am
  Fenster öffnet die Liste, ein Klick lädt den Build – über dieselbe
  Methode, die auch Blizzards eigener Import-Dialog aufruft. Im Kampf
  sagt es das, und scheitert es, landet der String im Kopierfeld.
- Der Knopf ist ziehbar und merkt sich, wohin: welche Ecke des
  Talentfensters frei ist, können wir nicht wissen.
- Der Aktivitätswähler dort ist gegliedert wie im Fenster – M+, Raid,
  PvP, darunter die Stichproben, darunter Dungeons oder Bosse.
- **„Alle Stufen"** im Schlüsselwähler: ein eigener Zustand, nicht das
  Fehlen einer Wahl. Er schaltet den Vergleich ab, es wird nichts
  abgeblendet.

### Geändert

- **Das Menü ist nach der Frage gegliedert, die ein Abschnitt
  beantwortet**, nicht nach der Art seiner Daten: Überblick, Talente,
  Ausrüstung, Vorbereitung, Einstellungen. Verzauberungen,
  Verbrauchsgüter und Erinnerung standen unter Ausrüstung, weil sie mit
  Gegenständen zu tun haben – sie beantworten alle „bin ich bereit?".
- **„Ausrüstung" heißt jetzt „Beliebt"** – das ist, was dort gemessen
  wird: wie viele der Besten ein Stück tragen. Und „Fundorte" sagt, wo
  es fällt.
- Die Verzierungen stehen jetzt auf der Handwerksseite. Eine Verzierung
  ist kein eigener Gegenstand, sondern ein Zusatz auf einem
  hergestellten – zwei Menüpunkte hießen, dieselbe Entscheidung an zwei
  Stellen zu treffen.

### Behoben

- **Das Fenster ließ sich kleiner ziehen als sein eigenes Menü.** Die
  Seitenleiste wird nicht abgeschnitten und scrollt nicht – die Hälfte
  stand über dem Spiel. Die Mindesthöhe rechnet jetzt mit, was das Menü
  braucht.
- **Im Fundort-Raster lief die Unterzeile durch die Symbole.** Es hält
  seine Textspalte schmal, weil rechts die Kästchen stehen; der Zeichner
  verbreiterte sie bei jedem Ziehen wieder.
- **Der Knopf am Talentfenster stand auf jedem Reiter** – auch über dem
  Zauberbuch – und ließ sich ganz aus dem Fenster schieben.
- **Jede zweite Zeile wirkte ausgegraut.** Die Zeilen waren 46,8 Pixel
  hoch – ein Bruchteil –, also landete jede zweite Kante auf einem
  halben Bildschirmpixel, und der Client verteilte die Fläche über zwei.
  Es war nie eine Farbe, es war eine Kante. Die Zeilen sitzen jetzt auf
  ganzen Bildschirmpixeln, bei jeder Skalierung.
- **„Verzauberungen" hatte seinen halben Namen verloren.** Beim
  Aufräumen doppelter Sprachschlüssel am 28. September ist die falsche
  der beiden Fassungen geblieben – es heißt wieder „Verzauberungen &
  Steine", und zwei Tests kennen den Text jetzt.
- **Bei den Zielwerten sah es aus, als fehlte ein Symbol.** Die 26 Pixel
  waren für den Rang, der dort einmal stand und längst rechts steht. Für
  Zweitwerte gibt es keine Symbole – alle 19 643 Atlas-Elemente des
  Spiels wurden durchsucht.

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
