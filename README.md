# OBIEKT '84

Gracz projektuje system ochrony tajnego retrofuturystycznego obiektu, uruchamia deterministyczną symulację infiltracji i poprawia zabezpieczenia po analizie wyniku.

To repozytorium zawiera **pionowy wycinek L0** — incydent, którego logika działa deterministycznie bez UI — oraz **iterację L1-A „PLAN → RUN”**: gracz ustawia patrol strażnika i kamerę, ogląda deterministyczną noc i poprawia plan po wyniku.

**Status:** L0 domknięty — wszystkie kryteria z [docs/MVP_L0.md](docs/MVP_L0.md) spełnione. L1-A zaimplementowana; kryteria i ich stan są w sekcji „L1-A” tego samego dokumentu.

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

## Uruchomienie

W edytorze: **F5** (scena główna to `res://scenes/main.tscn`).

Z terminala, podstawiając własną ścieżkę do binarki Godota:

```bash
"%GODOT_BIN%" --path .
```

Build Web: <https://emsior.github.io/obiekt84/>.

### Build Web lokalnie

Preset `Web` jest w `export_presets.cfg`: **bez wątków** (`variant/thread_support=false`), bez rozszerzeń natywnych, bez PWA.
Build jednowątkowy nie potrzebuje nagłówków COOP/COEP — działa na zwykłym hostingu statycznym (GitHub Pages, dowolny serwer HTTP).

Wymagane są szablony eksportu Godota **4.7.2** dla Web (`web_nothreads_release.zip`) w katalogu szablonów edytora
(Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`). Źródło: oficjalne wydanie `4.7.2-stable` na GitHubie; sumę sprawdź w `SHA512-SUMS.txt` z tego samego wydania.

```bat
"%GODOT_BIN%" --headless --path . --import
"%GODOT_BIN%" --headless --path . --export-release "Web" build/web/index.html
python -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

Build trafia do `build/web/` — katalog jest ignorowany przez Git i **nigdy nie jest commitowany**; w CI powstaje jako artefakt Pages.
Gra otwarta przez `file://` nie wystartuje — potrzebny jest serwer HTTP (`index.wasm` musi mieć typ `application/wasm`).

**Smoke test po każdym eksporcie** (w przeglądarce, na `http://127.0.0.1:8060/`):

1. Konsola: tylko trzy wiersze startowe Godota, zero `ERROR`; wszystkie żądania `200`.
2. Faza PLAN widoczna, oś czasu ukryta.
3. Klik w kamerę obraca ją; przeciągnięcie węzła i kamery zmienia plan; upuszczenie kamery na trasę daje czerwony komunikat.
4. `Uruchom noc` → plan domyślny kończy się `DANE WYKRADZIONE — tick 40`.
5. `Wróć do planu`, sama kamera na (12,9) w dół → nadal `DANE WYKRADZIONE — tick 40` (w logu `MARKED`); potem węzeł 3 z (16,7) na (16,8) → `OBIEKT ZABEZPIECZONY — tick 32`, w logu `guard_alarm`.
6. Klik w oś czasu w nocy przewija przebieg; Spacja nie przewija strony.

## Jak grać

Bronisz obiektu przed intruzem, który idzie jawną trasą do celu (żółty znacznik). Masz jednego strażnika z czterema punktami patrolu i jedną kamerę.

1. **PLAN.** Okno startuje w fazie planowania z planem domyślnym. **Plan domyślny przegrywa**: patrol jest za krótki, strażnik w ogóle nie widzi intruza i ten dociera do celu. Na planszy widać patrol (ponumerowane węzły 1–4 i przerywaną ścieżkę), kamerę, oba stożki widzenia w pozycji startowej i pełną trasę intruza — zanim noc się zacznie, widać, co jest pilnowane.
   - **przeciągnij węzeł** — przenosi punkt patrolu na komórkę pod kursorem; strażnik zawsze startuje na węźle 1,
   - **przeciągnij kamerę** — przenosi kamerę,
   - **klik w kamerę** — obraca ją o 90° zgodnie z ruchem wskazówek zegara.

   Upuszczenie poza planszą, kamery na trasie intruza albo na węźle patrolu, lub węzła na kamerze jest odrzucane: element wraca na miejsce, a pod nagłówkiem przez 2 s widać czerwony powód.

   **Kamera namierza, strażnik zatrzymuje.** Kamera sama nie wykrywa intruza — gdy go zobaczy, oznacza go jako namierzonego (`NAMIERZONY` w HUD, `MARKED` w logu). Od tej chwili wystarczy, że strażnik zobaczy go choć przez jeden tick, żeby podnieść alarm; bez namierzenia potrzebuje dwóch ticków z rzędu. Dlatego wygrana zawsze wymaga strażnika, a w planie domyślnym — zmiany patrolu.
2. **NOC (RUN).** **Spacja** albo przycisk **Uruchom noc** — przebieg rusza od razu. To deterministyczna symulacja: ten sam plan zawsze daje tę samą noc.
3. **Wynik.** Zielone `OBIEKT ZABEZPIECZONY` — intruz wykryty, obrona się udała. Czerwone `DANE WYKRADZIONE` — intruz dotarł do celu. **P** albo **Wróć do planu** przenosi z powrotem do planowania **z zachowanym planem** — poprawiasz i odpalasz noc ponownie. Wrócić można też w trakcie nocy.

Grę da się obsłużyć samą myszą; z klawiatury potrzebna jest najwyżej Spacja.

### Sterowanie — plan

| Wejście | Działanie |
|---|---|
| przeciągnij węzeł | przeniesienie punktu patrolu |
| przeciągnij kamerę | przeniesienie kamery |
| klik w kamerę | obrót kamery o 90° w prawo |
| Spacja | uruchom noc |
| `R` | przywróć plan domyślny |
| `[` / `]` | tempo podglądu nocy: wolniej / szybciej |
| `F` / `L` | pokaż/ukryj stożki widzenia / panel zdarzeń |

### Sterowanie — noc

| Klawisz | Działanie |
|---|---|
| `P` | **wróć do planu** z zachowanym planem |
| `[` / `]` | tempo podglądu: wolniej / szybciej |
| Spacja | start / pauza automatycznego przebiegu |
| `N` albo `.` | jeden tick do przodu |
| `,` | **jeden tick wstecz** |
| `Home` / `End` | początek / koniec przebiegu |
| klik w oś czasu | przewinięcie do wskazanego ticka |
| `R` | restart nocy **na tym samym planie** |
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

`N` zawsze wykonuje dokładnie jeden tick, niezależnie od tempa. Tempo przeżywa restart (`R`) i przejścia między planem a nocą, a po wyniku terminalnym jego zmiana nie wznawia przebiegu.

Wolne tempo jest po to, żeby dało się zobaczyć moment, w którym strażnik podejmuje decyzję: przejście `SUSPICION → ALARM` trwa przy 1× jedną dziesiątą sekundy.

To samo obsługują przyciski w HUD: **Uruchom noc**, **Wróć do planu**, **Plan domyślny**, trzy przyciski tempa oraz **Start**, **Pauza/Wznów**, **Restart** i krok wstecz / naprzód. Przyciski nie przejmują fokusu, więc Spacja zawsze trafia do gry.

### Warianty incydentu L0 — wyłącznie w testach

Trzy zakończenia silnika L0 (wykrycie w 38 ticku, sukces intruza w 40, limit ticków w 20) nie są już wybierane z UI — od L1-A ich miejsce zajął edytor planu. Żyją dalej jako golden logi w testach, bo pilnują reguł silnika (patrz „Regresja golden log” niżej).

### Co widać na ekranie

Plansza 20 × 20 po lewej: ciemna podłoga, obrys granicy, trasa intruza zaznaczona komórka po komórce (przebyty odcinek ma inny odcień), cztery waypointy patrolu z pogrubionym aktualnym celem, żółty marker celu intruza, kamera i strażnik ze znacznikiem kierunku. Stożki widzenia zmieniają kolor razem ze stanem strażnika: żółty w `PATROL`, jaśniejszy w `SUSPICION`, czerwony w `ALARM`. W fazie planowania nad planszą są dodatkowo numery węzłów 1–4, przerywana ścieżka patrolu (strażnik chodzi najpierw w osi X, potem w osi Y) i obrys przeciąganego elementu.

HUD po prawej: komunikat końcowy z perspektywy obrońcy (zielony — obiekt zabezpieczony, czerwony — dane wykradzione, pomarańczowy — limit ticków), podtytuł fazy albo czerwony powód odrzuconej edycji, status `PAUSED` / `RUNNING` / `FINISHED`, tick i limit ticków, tempo podglądu, stany strażnika i intruza, legenda sterowania dla bieżącej fazy oraz panel dziesięciu ostatnich zdarzeń w kolejności chronologicznej. W fazie planowania panel statusu pokazuje węzły patrolu, pozycję i kierunek kamery, cel intruza i limit ticków.

**Cofanie i przewijanie.** Klawisz `,` cofa symulację o jeden tick, `Home` i `End` skaczą na początek i koniec przebiegu, a kliknięcie w oś czasu przewija do wskazanego ticka. Nie ma tu historii stanów ani mechanizmu undo — działa to **dzięki determinizmowi rdzenia**: „idź do ticka N" to świeża `Simulation` na danych tej nocy (kopii planu z chwili uruchomienia) i dokładnie N kroków. Ten sam scenariusz zawsze daje ten sam przebieg, więc odtworzony tick jest identyczny z oryginalnym. Po zakończonym incydencie można się cofnąć przed moment wykrycia, zwolnić do 0,5× i obejrzeć decyzję strażnika jeszcze raz — stan przestaje być terminalny i przebieg da się doprowadzić do końca ponownie.

**Oś czasu pod planszą.** Pasek pokazuje, gdzie w przebiegu jesteśmy i kiedy coś się działo: pomarańczowe kreski to ticki decyzji, czerwona to zakończenie, biała to bieżący tick. Oś obejmuje domyślnie pierwsze 40 ticków — incydenty L0 kończą się w okolicach 20–40 ticka, a limit scenariusza wynosi 400, więc rozciąganie osi do limitu ścisnęłoby cały przebieg w lewy margines. Gdy przebieg wyjdzie poza horyzont, ten się podwaja.

**Wyróżnienie decyzji.** Gdy w danym ticku wydarzy się coś innego niż rutynowe minięcie waypointu — przejście FSM strażnika, wykrycie przez kamerę, `DETECTED`, `SUCCESS` albo zakończenie przebiegu — komórki podmiotów, których to dotyczy, dostają biały obrys na planszy, a odpowiadające im wpisy w panelu zdarzeń są oznaczone `►`. Dzięki temu widać, że zmiana na mapie i wiersz w logu to ta sama rzecz. Wyróżnienie znika wraz z następnym tickiem, więc przy tempie 0,5× jest wyraźnie czytelne.

Automatyczny przebieg zatrzymuje się sam po osiągnięciu wyniku terminalnego. Restart tworzy świeżą instancję `Simulation` na tym samym planie i czyści panel zdarzeń.

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

Wynik ostatniego uruchomienia: **177 przypadków testowych, 0 błędów, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit code 0.**

Po dodaniu nowego skryptu z `class_name` (np. `PlanEditor`) trzeba raz odświeżyć cache klas globalnych: `"%GODOT_BIN%" --headless --path . --import`. CI robi ten krok przed testami.

Flaga `--ignoreHeadlessMode` jest wymagana, ponieważ GdUnit4 domyślnie odmawia pracy w trybie headless. Nasze testy nie symulują wejścia przez `Input` — kilka testów sceny tworzy `InputEvent` i podaje go wprost do `_unhandled_input` koordynatora, więc to ograniczenie ich nie dotyczy.

### Komenda alternatywna — runner dostarczony z GdUnit4 (zweryfikowana lokalnie)

```bat
call addons\gdUnit4\runtest.cmd -a tests
```

Ostatnia potwierdzona weryfikacja tej komendy: exit code 0, **92/92** — sprzed dodania suity `tests/test_scenario.gd`. Liczby nie przepisujemy bez ponownego uruchomienia; komenda podstawowa jest zweryfikowana na pełnym, bieżącym zestawie. Uwaga: `runtest.cmd` uruchamia właściwy przebieg **w trybie okienkowym**, nie headless, i w tym repozytorium działa poprawnie wyłącznie wywołany z CMD lub PowerShell. Wywołany przez Git Bash zawiesza się bez wypisania czegokolwiek. Do CI używaj komendy podstawowej.

Raporty XML i HTML lądują w `reports/` (katalog ignorowany przez Git).

### Regresja golden log

`tests/test_l0_golden_log.gd` porównuje bieżące przebiegi z **pięcioma** zatwierdzonymi
artefaktami — po jednym na każdy terminalny wynik silnika L0 i dwa dla zagadki (od L1-C):

| Fixture | Ścieżka | Outcome |
|---|---|---|
| `tests/fixtures/l0_incident_golden_log.txt` | wykrycie intruza przez strażnika | `INTRUDER_DETECTED`, tick 38 |
| `tests/fixtures/l0_success_golden_log.txt` | intruz kończy trasę | `INTRUDER_SUCCESS`, tick 40 |
| `tests/fixtures/l0_tick_limit_golden_log.txt` | wyczerpanie limitu ticków | `TICK_LIMIT`, tick 20 |
| `tests/fixtures/l0_puzzle_default_golden_log.txt` | plan domyślny przegrywa, strażnik nie widzi intruza | `INTRUDER_SUCCESS`, tick 40 |
| `tests/fixtures/l0_puzzle_solution_golden_log.txt` | plan referencyjny: kamera namierza, strażnik zatrzymuje | `INTRUDER_DETECTED`, tick 32 |

Warianty sukcesu i limitu to te same dane z `ScenarioL0.create()` z jednym świadomie
zmienionym polem (odpowiednio: mniejszy zasięg widzenia strażnika, krótszy `max_ticks`).
Plan domyślny to `ScenarioL0.create_puzzle()`. Plan referencyjny jest zapisany w teście
jawnie: węzeł 3 przesunięty z `(16,7)` na `(16,8)` i kamera przeniesiona na `(12,9)`, skierowana w dół.
Każda z tych dwóch zmian osobno przegrywa (`tests/test_puzzle_design.gd`).
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

### Walidacja danych scenariusza

`tests/test_scenario.gd` pilnuje dwóch rzeczy, których nie widać w samym przebiegu incydentu:

- **`ScenarioL0.validate()` zgłasza błędne dane wejściowe** — waypoint albo trasę poza siatką,
  dziurę lub skos w trasie, niekardynalny kierunek patrzenia, ujemny zasięg, zerowy `max_ticks`,
  start strażnika różny od pierwszego waypointu, kamerę na trasie intruza albo na waypoincie.
  Zwraca **wszystkie** problemy naraz, nie tylko pierwszy. Edytor planu pokazuje graczowi pierwszy z nich. `Simulation.initialize()` zatrzymuje
  się na niepoprawnych danych jawnym komunikatem, zamiast uruchamiać bezwartościowy przebieg.
- **`ScenarioL0.duplicate_data()` kopiuje każde pole.** Test przechodzi po właściwościach klasy
  przez refleksję, więc nowe pole, którego ktoś zapomni dopisać do kopii, zapala test — zamiast
  po cichu przeciekać między przebiegami i psuć determinizm. Niezależność tablic sprawdzona osobno.

Czułość drugiego testu jest potwierdzona: tymczasowe pole pominięte w `duplicate_data()` zapala go
z komunikatem wskazującym nazwę pola.

## Zakres L0

- Siatka logiczna 20 × 20, trzymana w pamięci, a nie jako 400 node'ów.
- Jeden strażnik, cztery waypointy patrolu, FSM `PATROL / SUSPICION / ALARM / RETURN`.
- Jeden intruz na jawnej trasie, FSM `MOVE / DETECTED / SUCCESS`.
- Jedna statyczna kamera z polem widzenia liczonym czysto matematycznie (w L0 wykrywała intruza; od L1-C tylko go namierza).
- Sztywny tick logiczny 10 Hz, niezależny od FPS i renderowania.
- Event log o stałym schemacie `tick | subject | event | reason`.
- UI: sterowanie klawiaturą i przyciskami, HUD ze stanem, komunikatem końcowym i panelem zdarzeń.
- Testy GdUnit4 uruchamiane bez otwierania okna gry.

Incydent z `ScenarioL0.create()` kończy się w 38 ticku wykryciem intruza przez strażnika, trzy komórki przed końcem jego trasy.

## Zakres L1-A

- Faza PLAN: edytor czterech węzłów patrolu (liczba stała) i kamery — przeciąganie i obrót kamery. Edytor zmienia wyłącznie roboczą kopię danych scenariusza; rdzeń dostaje ją przez `Simulation.initialize()` i nic nie wie o UI.
- Faza RUN: ta sama deterministyczna noc co w L0, z pełnym sterowaniem przebiegiem. Powrót do planu zachowuje plan.
- Plan domyślny przegrywa, plan referencyjny wygrywa — oba pilnowane golden logami.

## Zakres L1-C

- Reguła „kamera namierza, strażnik zatrzymuje”: kamera nie wykrywa, tylko namierza; namierzony intruz zostaje zatrzymany po jednym ticku widoczności przez strażnika.
- Patrol zagadki `(10,4) (16,4) (16,7) (10,7)`: sama kamera nie wygrywa w żadnym z 1420 ustawień (test wyczerpujący), plan referencyjny wymaga jednocześnie zmiany patrolu i kamery.
- Trzy golden logi L0 bez zmian; dwa golden logi zagadki wymienione świadomie (`docs/DECISIONS.md`, 2026-09-24, L1-C).

## Jak dodać poziom

Poziom to plik JSON w `levels/` (format `format_version: 1`, decyzja: `docs/DECISIONS.md`, 2026-09-24, E7). Wzór — plan domyślny zagadki, `levels/puzzle_01.json`:

```json
{
  "format_version": 1,
  "grid": [20, 20],
  "guard": {
    "start": [10, 4],
    "facing": [1, 0],
    "view_range": 6,
    "waypoints": [[10, 4], [16, 4], [16, 7], [10, 7]]
  },
  "intruder": {
    "route_corners": [[18, 18], [1, 18], [1, 12], [18, 12]]
  },
  "camera": {
    "position": [3, 3],
    "facing": [0, 1],
    "range": 5
  },
  "max_ticks": 400
}
```

- Współrzędne i rozmiary to `[x, y]` z liczbami całkowitymi; kierunki (`facing`) wyłącznie kardynalne: `[1, 0]`, `[-1, 0]`, `[0, 1]`, `[0, -1]`.
- `guard.start` musi być równy pierwszemu z **dokładnie czterech** `waypoints`.
- `intruder.route_corners` to narożniki trasy; kolejne narożniki muszą leżeć w jednej osi, a trasa między nimi rozwija się komórka po komórce.
- Kamera nie może stać na trasie intruza ani na węźle patrolu.
- Zestaw pól jest zamknięty: brakujące albo nieznane pole, liczba niecałkowita czy zły typ odrzucają cały plik z komunikatem wskazującym pole. `LevelData.parse(text)` zwraca `{scenario, problems}`.
- Wyjątek: zduplikowany klucz w obiekcie JSON nie jest wykrywany — parser JSON Godota bierze ostatnią wartość. Każde pole wpisuj raz.

Sprawdzenie nowego pliku bez uruchamiania gry — w teście GdUnit4 albo skrypcie:

```gdscript
var result := LevelData.parse(FileAccess.get_file_as_string("res://levels/moj_poziom.json"))
print(result["problems"])   # pusta lista = poziom poprawny
```

Edytor planu wczytuje dziś wyłącznie `levels/puzzle_01.json`; wybór poziomu w UI należy do kolejnego etapu (E4). Pliki `levels/*.json` trafiają do buildu Web bez zmian w presecie eksportu.

## Świadome ograniczenia tej iteracji

- **Edytor zmienia tylko patrol i kamerę.** Trasa intruza, zasięgi, liczba waypointów i limit ticków pochodzą z pliku poziomu (`levels/puzzle_01.json`). Planu gracza nie da się zapisać.
- Brak pathfindingu: intruz ma kompletną listę komórek, strażnik chodzi regułą „najpierw oś X, potem oś Y". Żadnego AStar, NavMesh ani `NavigationAgent2D`.
- Brak ścian i pól zablokowanych: w danych scenariusza nie istnieje takie pojęcie, więc nie ma też okluzji ani algorytmu linii widzenia — FOV to czysty test stożka.
- Brak dźwięku, animacji, shaderów, zapisu, ekonomii, metaprogresji i generowania proceduralnego.
- Strażnik w stanie `SUSPICION` stoi w miejscu, więc `RETURN` trwa zwykle jeden tick. Przejazd powrotny jest pokryty osobnym testem FSM.
- Placeholdery wizualne przeskakują między komórkami. Interpolacja byłaby czysto kosmetyczna.

## Struktura

```text
levels/              poziomy jako dane (JSON, format_version 1)
scripts/core/        rdzeń domenowy (RefCounted, zero node'ów), w tym parser poziomu
scripts/actors/      FSM strażnika i intruza, kalkulator FOV
scripts/presentation/ widok poziomu, widok podmiotu, edytor planu, koordynator faz i czasu
scripts/ui/          HUD
scenes/              main.tscn, level_l0.tscn
tests/               testy GdUnit4
tests/fixtures/      pięć zatwierdzonych golden logów (trzy wyniki L0, dwa plany zagadki)
docs/                MVP_L0, ARCHITECTURE, DECISIONS, PLAYTEST
addons/gdUnit4/      vendorowany plugin w przypiętej wersji 6.2.1
```

Granicę między rdzeniem a prezentacją opisuje [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
