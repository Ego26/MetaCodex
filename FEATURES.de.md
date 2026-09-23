# MetaCodex — Was das Addon kann

> Stand: 23. September 2026. Deutsche Fassung von `FEATURES.md`. Wer
> wissen will, *wie* etwas gebaut ist, findet das nicht in diesem Repo.

**MetaCodex zeigt dir, was die besten Spieler deiner Spezialisierung
wirklich spielen** — Talente, Ausrüstung, Verzauberungen, Steine,
Verbrauchsgüter, Zielwerte — für Mythic+, Raid und jede PvP-Klammer. Nicht
aus einem Guide abgeschrieben, sondern täglich aus raider.io, murlok.io und
Warcraft Logs gemessen. Und es vergleicht das mit dem, was *du* gerade
trägst und im Beutel hast, damit du weißt, was noch fehlt.

Öffnen: **`/mc`** oder der Knopf in der Addon-Leiste der Minimap.

---

## Auf einen Blick

- **Talentbuilds mit Import-String** — der häufigste Build und seine
  Alternativen, je Dungeon in M+, je Boss im Raid, je Klammer im PvP.
  Kopieren, einfügen, fertig.
- **Ausrüstung mit Fundort** — fünf Gegenstände je Platz, wo jeder fällt,
  und Tooltips auf der Stufe, die *dein* Schlüsselstein gibt.
- **Verzauberungen & Steine gegen deine Ausrüstung** — was noch offen ist,
  was du schon hast, was du kaufen musst.
- **Verbrauchsgüter**, gruppiert nach Art, mit Bestand und Ziel.
- **Zielwerte**, gemessen an den Besten, deine Werte daneben.
- **Top-Spieler**, klickbar — ihr Talentbuild mit Import-String, ihre
  komplette Ausrüstung, ihr Profil.
- **Erinnerung** vor dem Start und am Auktionshaus — und ein Reiter, der
  zeigt, was sie prüft.
- **Guides** verlinkt, nie kopiert.
- **Einkaufslisten an Auctionator** mit Stückzahlen; **Shift-Klick**
  verlinkt jeden Gegenstand in den Chat oder ins Suchfeld des Auktionshauses.
- **Jede Aktivität, jede Spec, drei Plattformen** — und nichts angezeigt,
  was keine Plattform beantworten kann.
- **Deutsch und Englisch**, auf jedem Client richtig.

---

## Die Reiter

### Wissen

**Guides & Rotation** — Verweise auf die geschriebenen Guides zu deiner
Spec: Wowhead (Rotation und BiS), Method, Archon, murlok. Ein Klick legt die
Adresse zum Kopieren hin — ein Addon kann keinen Browser öffnen, aber den
Weg dorthin kurz machen.

**Zielwerte** — Welche Sekundärwerte die Besten in welcher Höhe tragen,
gemessen als Median aus echten Kämpfen. Zwei Balken je Wert: das Ziel und
dein Stand. Grün, sobald du da bist; sonst steht dabei, wie viel fehlt.

**Talente** — Der häufigste Build als eine Zeile: Klick, String kopieren, im
Talentfenster bei „Importieren" einfügen. Darunter bis zu sechs
Alternativen, jede beschrieben als *„Talent X statt Talent Y"*, damit du
siehst, worin sich die Meinungen unterscheiden — und jede mit eigenem
String. Dann die umstrittenen Talente (die, die zwischen 15 und 85 % der
Besten nehmen) und bei PvP die PvP-Talente in eigener Gruppe. Bei M+
zusätzlich je Dungeon wählbar, im Raid je Boss — nach Raid gruppiert, wenn
mehrere laufen.

**Top-Spieler** — Wer diese Spec gerade oben spielt, je Aktivität. Ein
Klick öffnet das Profil *im Fenster*: seinen Talent-String (mit Vermerk, ob
er zur Aktivität passt), seine komplette Ausrüstung — Tooltips zeigen
jedes Stück genau so, wie er es trägt — und die Adresse seines Profils.

### Ausrüstung

**Ausrüstung** — Je Platz die fünf meistgetragenen Gegenstände mit Anteil,
Gegenstandsstufe, höchster Schlüsselstufe, Set- und Handwerksmarke und
**Fundort**: welcher Boss in welcher Instanz, welcher Händler, oder ehrlich
„kein Instanzdrop". Oben rechts wählst du *deinen* Schlüsselstein — nach
Aufwertungspfad wie in KeystoneLoot (Champion / Held / Große Schatzkammer)
— und jedes Tooltip zeigt den Gegenstand auf genau der Stufe, die du dafür
bekämst, mit „Held 3/8" im Tooltip.

**Verzauberungen & Steine** — Was die Besten auf welchem Platz tragen, mit
zwei Alternativen je Platz und dem besonderen Sockel getrennt. Verglichen
mit deiner Ausrüstung: verzauberte Plätze werden übersprungen, leere Sockel
gezählt, dein Beutel und deine Bank abgezogen. Rechts steht, was du noch
brauchst.

**Verbrauchsgüter** — Gruppiert nach Art: Fläschchen,
Speise, Kampftrank, Heiltrank, Waffenbuffs (Öle, Wetzsteine), Runen. Je
Gruppe der Anteil der Spieler und die höchste Schlüsselstufe, bei der es
noch benutzt wurde. Dazu dein Bestand und eine Zielmenge, die du per Klick
einstellst.

**Erinnerung** — Was das Addon prüft, bevor es losgeht: je Verbrauchsart
der Stand gegen dein Ziel (reicht / knapp / leer), die Verzauberungen und
Steine, die an deinem Charakter noch fehlen, und die Einstellungen dazu.
Beim Betreten von Dungeon oder Raid sagt dir eine Chatzeile, was fehlt — und
am Auktionshaus einmal, wie viele Posten offen sind.

### Über

**Info** — Version, Stand des Katalogs, wann jede Plattform zuletzt
gemessen hat, und ob Auctionator da ist.

---

## Bedienung

- **Spec** (Kopfzeile links): die eigene ist voreingestellt. Jede andere
  Klasse und Spec ist wählbar; unter „Auch einkaufen für …" kommen weitere
  Speccs in dieselbe Einkaufsliste.
- **Aktivität**: M+, Raid, PvP — in Untermenüs. Es steht nur da, wozu es
  für den aktuellen Reiter Daten gibt.
- **Plattform**: einzeln oder alle. Wo eine Plattform zu einem Reiter
  nichts hat, wird sie gar nicht erst angeboten; bleibt nur eine, gibt es
  keinen Knopf.
- **Dungeon / Boss** (bei Talenten): alle acht Dungeons der Saison, oder
  jeder Boss jedes laufenden Raids.
- **Schlüsselstein** (bei Ausrüstung): Champion / Held / Große Schatzkammer,
  jede Stufe mit den Schlüsseln, die sie geben.
- **Kategorie / Platz**: Listen lassen sich auf einen Platz oder eine Art
  eingrenzen.
- **Fenster**: an der Ecke unten rechts ziehbar; Position und Größe werden
  gemerkt. `/mc scale` skaliert zusätzlich für große und kleine Bildschirme.
- **Klick auf eine Zeile**: kopiert einen String, öffnet ein Profil, stellt
  eine Zielmenge ein — je nachdem, was die Zeile ist.
- **Shift-Klick auf eine Zeile mit Gegenstand**: verlinkt ihn — in den
  Chat, oder bei offenem Auktionshaus direkt ins Suchfeld. Ctrl-Klick:
  Ankleideraum.
- **Einkaufsliste anlegen / Jetzt suchen** (unten, bei Verzauberungen,
  Verbrauchsgütern und Erinnerung): übergibt an **Auctionator** — eine
  Liste je Reiter, mit Stückzahlen. „Jetzt suchen" braucht ein offenes
  Auktionshaus und ist sonst grau. Ohne Auctionator zeigt MetaCodex alles
  trotzdem; nur die Übergabe fällt weg.

**Slash-Befehle:** `/mc` öffnet · `/mc scale 0.6–1.6` Fenstergröße ·
`/mc remind` schaltet die Erinnerung · `/mc lang de|en|auto` Sprache ·
`/mc probe` Selbsttest zum Kopieren · `/mc reset` setzt die Auswahl zurück.

---

## Woher die Daten kommen — und warum man ihnen trauen kann

| Plattform | Liefert |
|---|---|
| **raider.io** | M+: Ausrüstung, Verzauberungen, Steine, Talente mit fertigem Import-String. Die Profile der Top-Spieler |
| **murlok.io** | Alle PvP-Klammern und M+: Ausrüstung, Steine, Zielwerte, Talente, Ranglisten der Top-Spieler |
| **Warcraft Logs** | Raid komplett und Verbrauchsgüter — das, was sonst niemand veröffentlicht |

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
| **3 Plattformen** | raider.io, murlok.io, Warcraft Logs — einzeln wählbar oder „Alle Plattformen" |
| **Alle 40 Speccs** | Auch für Klassen, die du gar nicht spielst — zum Nachsehen oder zum Einkaufen für den Zweitcharakter |
| **1.401 Talent-Import-Strings** | Jeder von einem echten Spieler, jeder mit einem Klick kopierbar |
| **2.472 Spielerprofile** | Die Top-Spieler je Spec und Aktivität, mit kompletter Ausrüstung |
| **Jede Nacht neu** | Die Daten sind höchstens einen Tag alt |

---

## Was noch geplant ist

### Erweiterungen

- **Held-Talente getrennt.** Builds unterscheiden sich zwischen den beiden
  Held-Talent-Bäumen (etwa Sturmbringer und Weitseher); heute stehen sie
  gemischt. Geplant: je Baum eigene Zahlen.
- **Omnium Folio.** Archon zeigt, welche Folio-Runen die Besten nutzen. Die
  Runen sind in den Spieldaten nur als Kampfeffekte sichtbar, nicht als
  Gegenstände oder Talente — sobald sie sich sauber zuordnen lassen, kommt
  ein Reiter dafür.
- **Fundort für die letzten Gegenstände.** 459 Stücke (Ruf- und
  Weltbeute, etwa „Spellbreaker's", „Martyr's") haben in keiner Spieltabelle
  eine Quelle und heißen deshalb „kein Instanzdrop". Eine Händlerliste würde
  das schließen.
- **Filter nach Fundort.** „Was fällt in diesem Dungeon" statt nur „wo fällt
  das".

### Verbesserungen

- **Erster Klick auf einen Spieler** lädt 4,5 MB Profile — ob das spürbar
  ruckelt, entscheidet sich im Spiel. Wenn ja: weniger Spieler je Spec oder
  schlankere Profile.
- **Verbrauchsgüter für jede M+-Spec.** Die Stichprobe der Logs hat ein
  paar Speccs nicht erwischt; der Tageslauf zieht jetzt mehr Berichte.

### Was nicht kommt, und warum

- **PvP-Verbrauchsgüter** — keine Plattform misst sie, und Warcraft Logs
  loggt keine Arenen. Das Addon zeigt lieber nichts als etwas Erfundenes.
- **Guide-Texte im Addon** — die gehören den Seiten, die sie schreiben.
  Deshalb Verweise statt Kopien.

---

## Voraussetzungen

- World of Warcraft Retail, aktueller Patch (12.1)
- **Auctionator** für die Übergabe ins Auktionshaus (optional)
- Die drei Datenaddons `MetaCodex_Data`, `MetaCodex_Dungeons`,
  `MetaCodex_Players` liegen bei und laden erst, wenn sie gebraucht werden —
  beim Login kostet MetaCodex nichts.
