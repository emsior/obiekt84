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

## Uruchomienie gry

W edytorze: **F5** (scena główna to `res://scenes/main.tscn`).

Z terminala, podstawiając własną ścieżkę do binarki Godota:

```bash
"%GODOT_BIN%" --path .
```

Sterowanie: **Start**, **Pauza/Wznów**, **Restart**. Restart przywraca dokładnie stan początkowy i zatrzymuje odtwarzanie.

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

Wynik ostatniego uruchomienia: **58 przypadków testowych, 0 błędów, 0 failures, 0 orphans, exit code 0.**

Flaga `--ignoreHeadlessMode` jest wymagana, ponieważ GdUnit4 domyślnie odmawia pracy w trybie headless. Nasze testy nie używają `InputEvent`, więc to ograniczenie ich nie dotyczy.

### Komenda alternatywna — runner dostarczony z GdUnit4 (zweryfikowana lokalnie)

```bat
call addons\gdUnit4\runtest.cmd -a tests
```

Exit code 0, 58/58 przypadków. Uwaga: `runtest.cmd` uruchamia właściwy przebieg **w trybie okienkowym**, nie headless, i w tym repozytorium działa poprawnie wyłącznie wywołany z CMD lub PowerShell. Wywołany przez Git Bash zawiesza się bez wypisania czegokolwiek. Do CI używaj komendy podstawowej.

Raporty XML i HTML lądują w `reports/` (katalog ignorowany przez Git).

## Zakres L0

- Siatka logiczna 20 × 20, trzymana w pamięci, a nie jako 400 node'ów.
- Jeden strażnik, cztery waypointy patrolu, FSM `PATROL / SUSPICION / ALARM / RETURN`.
- Jeden intruz na jawnej trasie, FSM `MOVE / DETECTED / SUCCESS`.
- Jedna statyczna kamera wykrywająca intruza czysto matematycznie.
- Sztywny tick logiczny 10 Hz, niezależny od FPS i renderowania.
- Event log o stałym schemacie `tick | subject | event | reason`.
- UI: Start, Pauza/Wznów, Restart.
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
docs/                MVP_L0, ARCHITECTURE, DECISIONS, PLAYTEST
addons/gdUnit4/      vendorowany plugin w przypiętej wersji 6.2.1
```

Granicę między rdzeniem a prezentacją opisuje [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
