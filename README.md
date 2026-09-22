# OBIEKT '84

Gracz projektuje system ochrony tajnego retrofuturystycznego obiektu, uruchamia deterministyczną symulację infiltracji i poprawia zabezpieczenia po analizie wyniku.

Ten repozytorium zawiera **wyłącznie pionowy wycinek L0**: jeden ręcznie skonfigurowany incydent, którego logika działa deterministycznie bez UI.

## Wymagania

| Element | Wersja |
|---|---|
| Godot | **4.7.2.stable.official** (wykryta i używana lokalnie) |
| Język | GDScript |
| Framework testów | **GdUnit4 6.2.1**, tag `v6.2.1`, vendorowany w `addons/gdUnit4/` |

Źródło GdUnit4: <https://github.com/godot-gdunit-labs/gdUnit4>, archiwum przypiętego tagu `v6.2.1`.

Plugin jest w repozytorium świadomie — CI i kolejne sesje nie muszą go pobierać. Wersji nie zmieniamy bez wpisu w [docs/DECISIONS.md](docs/DECISIONS.md).

## Otwarcie projektu

1. Uruchom Godot 4.7.x.
2. **Import** → wskaż `project.godot` w katalogu tego repozytorium.
3. GdUnit4 jest już zarejestrowany w `project.godot`; zakładka **gdUnitConsole** pojawia się na dolnym panelu edytora.

## Uruchomienie vertical slice L0

W edytorze: **F5** (scena główna to `res://scenes/main.tscn`).

Z terminala, podstawiając własną ścieżkę do binarki Godota:

```bash
"%GODOT_BIN%" --path .
```

Okno startuje w stanie **PAUSED** na ticku 0, w wariancie wykrycia. Naciśnij **Spację**, żeby uruchomić przebieg, albo **N**, żeby przechodzić tick po ticku. Klawisze `1`, `2`, `3` przełączają wariant incydentu.

### Sterowanie

| Klawisz | Działanie |
|---|---|
| `1` / `2` / `3` | wybór wariantu incydentu |
| `[` / `]` | tempo podglądu: wolniej / szybciej |
| Spacja | start / pauza automatycznego przebiegu |
| `N` albo `.` | jeden tick do przodu |
| `,` | **jeden tick wstecz** |
| `Home` / `End` | początek / koniec przebiegu |
| klik w oś czasu | przewinięcie do wskazanego ticka |
| `R` | restart **aktualnie wybranego** wariantu |
| `F` | pokaż/ukryj stożki widzenia kamery i strażnika |
| `L` | pokaż/ukryj panel ostatnich zdarzeń |
| Escape | pauza (powrót do stanu neutralnego) |

### Tempo podglądu

| Tryb | Mnożnik | Odstęp między krokami | Efektywnie |
|---|---|---|---|
| Wolno | 0,5× | 0,2 s | 5 ticków/s |
| Normalnie (domyślne) | 1× | 0,1 s | 10 ticków/s |
| Szybko | 2× | 0,05 s | 20 ticków/s |

Tempo zmienia **wyłącznie odstęp czasu** między kolejnymi wywołaniami `Simulation.step()`. Zawartość ticka, ich kolejność, FOV, FSM, event log i wynik pozostają identyczne — przebieg przy 0,5× i 2× daje bit w bit ten sam kanoniczny log. Rdzeń nadal nie widzi czasu rzeczywistego.

`N` zawsze wykonuje dokładnie jeden tick, niezależnie od tempa. Tempo przeżywa restart (`R`) i zmianę wariantu (`1`/`2`/`3`), a po wyniku terminalnym jego zmiana nie wznawia przebiegu.

Wolne tempo jest po to, żeby dało się zobaczyć moment, w którym strażnik podejmuje decyzję: przejście `SUSPICION → ALARM` trwa przy 1× jedną dziesiątą sekundy.

To samo obsługują przyciski w HUD: trzy przyciski wariantu, trzy przyciski tempa oraz **Start**, **Pauza/Wznów** i **Restart**.

### Trzy warianty incydentu

Wszystkie trzy zakończenia silnika L0 można obejrzeć bez edytowania kodu. Warianty **nie zmieniają żadnej reguły gry** — to te same dane z `ScenarioL0.create()`, w dwóch przypadkach z jednym zmienionym polem:

| Wariant | Klawisz | Zmiana danych | Wynik |
|---|---|---|---|
| Wykrycie | `1` | brak | `INTRUDER_DETECTED`, tick 38 |
| Sukces intruza | `2` | `guard_view_range = 4` | `INTRUDER_SUCCESS`, tick 40 |
| Limit ticków | `3` | `max_ticks = 20` | `TICK_LIMIT`, tick 20 |

Wybór wariantu natychmiast restartuje przebieg: świeże dane, świeża `Simulation`, tick 0, pusty panel zdarzeń, stan `PAUSED`. Aktywny wariant jest oznaczony wypełnionym znacznikiem na przycisku i nazwą w HUD. `R` restartuje wybrany wariant, nie wraca do domyślnego.

### Co widać na ekranie

Plansza 20 × 20 po lewej: ciemna podłoga, obrys granicy, trasa intruza zaznaczona komórka po komórce (przebyty odcinek ma inny odcień), cztery waypointy patrolu z pogrubionym aktualnym celem, żółty marker celu intruza, kamera i strażnik ze znacznikiem kierunku. Stożki widzenia zmieniają kolor razem ze stanem strażnika: żółty w `PATROL`, jaśniejszy w `SUSPICION`, czerwony w `ALARM`.

HUD po prawej: komunikat końcowy (czerwony — wykrycie, zielony — sukces intruza, pomarańczowy — limit ticków), status `PAUSED` / `RUNNING` / `FINISHED`, tick i limit ticków, tempo podglądu, stany strażnika i intruza, legenda sterowania oraz panel jedenastu ostatnich zdarzeń w kolejności chronologicznej.

**Cofanie i przewijanie.** Klawisz `,` cofa symulację o jeden tick, `Home` i `End` skaczą na początek i koniec przebiegu, a kliknięcie w oś czasu przewija do wskazanego ticka. Nie ma tu historii stanów ani mechanizmu undo — działa to **dzięki determinizmowi rdzenia**: „idź do ticka N" to świeża `Simulation` na tych samych danych i dokładnie N kroków. Ten sam scenariusz zawsze daje ten sam przebieg, więc odtworzony tick jest identyczny z oryginalnym. Po zakończonym incydencie można się cofnąć przed moment wykrycia, zwolnić do 0,5× i obejrzeć decyzję strażnika jeszcze raz — stan przestaje być terminalny i przebieg da się doprowadzić do końca ponownie.

**Oś czasu pod planszą.** Pasek pokazuje, gdzie w przebiegu jesteśmy i kiedy coś się działo: pomarańczowe kreski to ticki decyzji, czerwona to zakończenie, biała to bieżący tick. Oś obejmuje domyślnie pierwsze 40 ticków — incydenty L0 kończą się w okolicach 20–40 ticka, a limit scenariusza wynosi 400, więc rozciąganie osi do limitu ścisnęłoby cały przebieg w lewy margines. Gdy przebieg wyjdzie poza horyzont, ten się podwaja.

**Wyróżnienie decyzji.** Gdy w danym ticku wydarzy się coś innego niż rutynowe minięcie waypointu — przejście FSM strażnika, wykrycie przez kamerę, `DETECTED`, `SUCCESS` albo zakończenie przebiegu — komórki podmiotów, których to dotyczy, dostają biały obrys na planszy, a odpowiadające im wpisy w panelu zdarzeń są oznaczone `►`. Dzięki temu widać, że zmiana na mapie i wiersz w logu to ta sama rzecz. Wyróżnienie znika wraz z następnym tickiem, więc przy tempie 0,5× jest wyraźnie czytelne.

Automatyczny przebieg zatrzymuje się sam po osiągnięciu wyniku terminalnego. Restart tworzy świeży scenariusz i świeżą instancję `Simulation` oraz czyści panel zdarzeń.

## Testy headless

Ustaw najpierw ścieżkę do swojej binarki Godota — repozytorium celowo nie zawiera żadnej ścieżki użytkownika.

**Windows, CMD:**

```bat
set "GODOT_BIN=C:\sciezka\do\Godot_v4.7.2-stable_win64_console.exe"
```

**Windows, PowerShell:**

```powershell
$env:GODOT_BIN = 'C:\sciezka\do\Godot_v4.7.2-stable_win64_console.exe'
```

### Komenda podstawowa — w pełni headless (zweryfikowana lokalnie)

```bat
"%GODOT_BIN%" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode
```

Wynik ostatniego uruchomienia: **92 przypadki testowe, 0 błędów, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit code 0.**

Flaga `--ignoreHeadlessMode` jest wymagana, ponieważ GdUnit4 domyślnie odmawia pracy w trybie headless. Nasze testy nie używają `InputEvent`, więc to ograniczenie ich nie dotyczy.

### Komenda alternatywna — runner dostarczony z GdUnit4 (zweryfikowana lokalnie)

```bat
call addons\gdUnit4\runtest.cmd -a tests
```

Exit code 0, 84/84 przypadków. Uwaga: `runtest.cmd` uruchamia właściwy przebieg **w trybie okienkowym**, nie headless, i w tym repozytorium działa poprawnie wyłącznie wywołany z CMD lub PowerShell. Wywołany przez Git Bash zawiesza się bez wypisania czegokolwiek. Do CI używaj komendy podstawowej.

Raporty XML i HTML lądują w `reports/` (katalog ignorowany przez Git).

### Regresja golden log

`tests/test_l0_golden_log.gd` porównuje bieżące przebiegi L0 z **trzema** zatwierdzonymi
artefaktami — po jednym na każdy terminalny wynik silnika:

| Fixture | Ścieżka | Outcome |
|---|---|---|
| `tests/fixtures/l0_incident_golden_log.txt` | wykrycie intruza przez strażnika | `INTRUDER_DETECTED` |
| `tests/fixtures/l0_success_golden_log.txt` | intruz kończy trasę | `INTRUDER_SUCCESS` |
| `tests/fixtures/l0_tick_limit_golden_log.txt` | wyczerpanie limitu ticków | `TICK_LIMIT` |

Warianty sukcesu i limitu to te same dane z `ScenarioL0.create()` z jednym świadomie
zmienionym polem (odpowiednio: mniejszy zasięg widzenia strażnika, krótszy `max_ticks`).
Wynik wynika z normalnej pracy silnika, nie z wymuszenia. Fixture'y chronią przed zmianą
reguł, której nie wykryje test 50/50 — bo tamten dowodzi tylko, że przebiegi są wzajemnie
identyczne, a nie że nadal zgadzają się z zatwierdzonym zachowaniem.

**Fixture'y są zatwierdzonym kontraktem zachowania L0.** Czerwony test golden log oznacza
albo regresję, albo zamierzoną zmianę reguł — nigdy powód do regeneracji pliku.

Format fixture'u: plik tekstowy z dwiema sekcjami. `[EVENT_LOG]` zawiera kanoniczny
log (`tick|subject|event|reason`, jeden wiersz na zdarzenie), `[FINAL_STATE]` —
kanoniczny snapshot końcowy (`klucz=wartość`, stała kolejność pól). Bez czasu
systemowego, identyfikatorów instancji i danych zależnych od kolejności hash map.

**Fixture'y aktualizują się wyłącznie świadomie**, w osobnym commicie po zamierzonej zmianie kontraktu zachowania L0 —
razem ze zmianą testów i wpisem w `docs/DECISIONS.md`. Test nigdy ich nie nadpisuje.
Czerwonego testu golden log **nie wolno "naprawiać" przez regenerację fixture'u**:
najpierw ustal, czy zmiana zachowania była zamierzona.

## Zakres L0

- Siatka logiczna 20 × 20, trzymana w pamięci, a nie jako 400 node'ów.
- Jeden strażnik, cztery waypointy patrolu, FSM `PATROL / SUSPICION / ALARM / RETURN`.
- Jeden intruz na jawnej trasie, FSM `MOVE / DETECTED / SUCCESS`.
- Jedna statyczna kamera wykrywająca intruza czysto matematycznie.
- Sztywny tick logiczny 10 Hz, niezależny od FPS i renderowania.
- Event log o stałym schemacie `tick | subject | event | reason`.
- UI: sterowanie klawiaturą i przyciskami, HUD ze stanem, komunikatem końcowym i panelem zdarzeń.
- Testy GdUnit4 uruchamiane bez otwierania okna gry.

Bieżący incydent kończy się w 38 ticku wykryciem intruza przez strażnika, trzy komórki przed końcem jego trasy.

## Świadome ograniczenia tej iteracji

- **Konfiguracja incydentu jest definiowana w danych scenariusza** (`scripts/core/scenario_l0.gd`), a **nie przez interaktywne UI planowania.** Nie ma edytora ustawiania kamer ani waypointów — to celowa decyzja, nie brak.
- Brak pathfindingu: intruz ma kompletną listę komórek, strażnik chodzi regułą „najpierw oś X, potem oś Y". Żadnego AStar, NavMesh ani `NavigationAgent2D`.
- Brak okluzji ścian i algorytmu linii widzenia — FOV to czysty test stożka.
- Brak dźwięku, animacji, shaderów, zapisu, ekonomii, metaprogresji i generowania proceduralnego.
- Strażnik w stanie `SUSPICION` stoi w miejscu, więc `RETURN` trwa zwykle jeden tick. Przejazd powrotny jest pokryty osobnym testem FSM.
- Placeholdery wizualne przeskakują między komórkami. Interpolacja byłaby czysto kosmetyczna.

## Struktura

```text
scripts/core/        rdzeń domenowy (RefCounted, zero node'ów)
scripts/actors/      FSM strażnika i intruza, kalkulator FOV
scripts/presentation/ widok poziomu, widok podmiotu, adapter czasu
scripts/ui/          HUD
scenes/              main.tscn, level_l0.tscn
tests/               testy GdUnit4
tests/fixtures/      trzy zatwierdzone golden logi L0 (wykrycie, sukces, limit)
docs/                MVP_L0, ARCHITECTURE, DECISIONS, PLAYTEST
addons/gdUnit4/      vendorowany plugin w przypiętej wersji 6.2.1
```

Granicę między rdzeniem a prezentacją opisuje [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
