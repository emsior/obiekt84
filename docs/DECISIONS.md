# Dziennik decyzji

Format wpisu: data, decyzja, uzasadnienie, konsekwencje.

---

## 2026-09-21 — Godot 4.x jako silnik

**Decyzja:** projekt stoi na Godot 4.7.2.stable.official, z `config/features = PackedStringArray("4.7", "Forward Plus")`.

**Uzasadnienie:** projekt szablonowy zastany w repozytorium był już w tej wersji, a lokalnie dostępna binarka to dokładnie 4.7.2.

**Konsekwencje:** otwarcie projektu wymaga Godota 4.7.x. Zejście na starszą gałąź wymagałoby zmiany `config/features`.

---

## 2026-09-21 — GDScript zamiast C#

**Decyzja:** cała logika w GDScript.

**Uzasadnienie:** L0 nie ma wymagań wydajnościowych, a GDScript eliminuje zależność od .NET SDK w CI i skraca pętlę zwrotną.

**Konsekwencje:** brak wariantu mono. Gdyby pojawił się C#, `runtest.cmd` uruchamia dodatkowo `dotnet build`.

---

## 2026-09-21 — GdUnit4 jako jedyny framework testów

**Decyzja:** GdUnit4, bez własnego runnera, bez GUT, bez `assert()` uruchamianego ze sceny.

**Uzasadnienie:** wymóg projektu. GdUnit4 daje raportowanie exit code, parametryzację testów i automatyczne wykrywanie orphan nodes — wszystkie trzy są potrzebne do kontraktu L0.

**Konsekwencje:** plugin jest twardą zależnością projektu i musi być obecny, żeby testy w ogóle się uruchomiły.

---

## 2026-09-21 — Przypięta wersja GdUnit4: v6.2.1, mimo braku deklaracji zgodności z 4.7.2

**Decyzja:** vendorowana wersja **6.2.1**, tag **`v6.2.1`**, źródło <https://github.com/godot-gdunit-labs/gdUnit4>, archiwum źródłowe przypiętego tagu (SHA-256 `ffb48847c46f386bf0c7a716fd68c6dace7d67730775cf7f748adce8ef3ed794`). Skopiowana wyłącznie zawartość `addons/gdUnit4/` do `addons/gdUnit4/`, bez zagnieżdżenia.

**Uzasadnienie:** v6.2.1 to najnowsze stabilne wydanie. Tabela zgodności tej wersji wymienia Godota do **4.7.1 włącznie** — **4.7.2 nie jest wymienione**, także w gałęzi `master`. Jednocześnie jedyna twarda bramka wersji w `addons/gdUnit4/plugin.gd` to **minimum** `Engine.get_version_info().hex < 0x40500`, czyli Godot ≥ 4.5; górnego ograniczenia nie ma, więc 4.7.2 ją przechodzi. Różnica to jeden patch ponad zadeklarowane maksimum. Dodatkowo v6.2.1 zawiera poprawkę `GD-1291` eliminującą fałszywie dodatnie wykrycia orphan nodes, istotną dla testu integracyjnego. Decyzję podjął właściciel projektu, świadomy braku deklaracji.

**Konsekwencje:** ryzyko rozjazdu z nieudokumentowaną zmianą w 4.7.2 jest akceptowane i natychmiast wykrywalne — pełny przebieg testów jest zielony (58/58, exit 0). **Wersji nie zmieniamy bez nowego wpisu w tym pliku.** Gdy pojawi się wydanie GdUnit4 deklarujące 4.7.2, warto je podbić i odnotować tutaj.

---

## 2026-09-21 — Testy headless jako podstawowy tryb walidacji

**Decyzja:** kanoniczna komenda to bezpośrednie wywołanie `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` z `--headless` i `--ignoreHeadlessMode`.

**Uzasadnienie:** dostarczony `runtest.cmd` uruchamia właściwy przebieg **w trybie okienkowym** i w tym środowisku zawiesza się wywołany przez Git Bash (działa z CMD i PowerShell, exit 0). Wywołanie bezpośrednie jest w pełni headless i działa z każdej powłoki. GdUnit4 domyślnie odmawia pracy headless, stąd `--ignoreHeadlessMode`; nasze testy nie używają `InputEvent`, więc ostrzeżenie ich nie dotyczy.

**Konsekwencje:** CI używa komendy bezpośredniej. `runtest.cmd` zostaje jako wariant lokalny, opisany w README wraz z jego ograniczeniem.

---

## 2026-09-21 — Rdzeń oddzielony od Scene Tree

**Decyzja:** logika domenowa to klasy `RefCounted` w `scripts/core/` i `scripts/actors/`. Scene Tree nie jest źródłem prawdy.

**Uzasadnienie:** jedyny sposób, żeby pełny przebieg incydentu dało się wykonać w pętli `for` 50 razy w jednym procesie testowym, bez renderowania i bez czekania na czas rzeczywisty.

**Konsekwencje:** prezentacja komunikuje się z rdzeniem wyłącznie przez `step()`, `reset()` i snapshot. Rdzeń nie tworzy node'ów, więc orphan nodes są wyłącznie problemem testu integracyjnego.

---

## 2026-09-21 — `Vector2i` jako logiczna pozycja

**Decyzja:** wszystkie pozycje i kierunki to `Vector2i`; kierunki wyłącznie kardynalne.

**Uzasadnienie:** liczby całkowite eliminują błąd zaokrąglenia jako źródło niedeterminizmu. Porównania pozycji są dokładne.

**Konsekwencje:** ruch to najwyżej jedna komórka na tick. Przeliczenie na piksele należy wyłącznie do warstwy widoku.

---

## 2026-09-21 — Brak fizyki Godota w logice

**Decyzja:** FOV i wykrycie liczymy całkowitoliczbowym testem stożka. Zero `Area2D`, `CollisionShape2D`, `RayCast2D`, zapytań do serwera fizyki i `atan2()`. Warstwa prezentacji też nie zawiera node'ów fizycznych.

**Uzasadnienie:** silnik fizyki jest zależny od kroku czasowego i kolejności wewnętrznej, czyli jest źródłem niedeterminizmu.

**Konsekwencje:** granica zasięgu i granica kąta są jawnie zdefiniowane jako **widoczne** i przetestowane. Brak zakazu jest pilnowany testem `test_presentation_contains_no_physics_nodes`.

---

## 2026-09-21 — Stały tick 10 Hz

**Decyzja:** `TICKS_PER_SECOND = 10`. Timer prezentacji nie jest zegarem domenowym; jeden `timeout` to dokładnie jeden `step()`.

**Uzasadnienie:** oddziela tempo wyświetlania od kroku logiki. Wynik zależy od liczby wywołań `step()`, nie od tego, kiedy nastąpiły.

**Konsekwencje:** jitter Timera i spadki FPS nie wpływają na wynik. Test integracyjny wyzwala ticki jawną emisją sygnału Timera, bez czekania na czas rzeczywisty.

---

## 2026-09-21 — Kolejność faz ticka i priorytety

**Decyzja:** dziewięć faz w stałej kolejności (opis w `ARCHITECTURE.md`). Przy równoczesnym wykryciu priorytet ma kamera, potem strażnik. Wykrycie wyprzedza sukces intruza w tym samym ticku.

**Uzasadnienie:** bez jawnego rozstrzygnięcia remisów wynik zależałby od kolejności wywołań, czyli od przypadku.

**Konsekwencje:** zmiana kolejności faz zmienia event log, więc łamie test 50/50. Wymaga osobnej decyzji tutaj.

---

## 2026-09-21 — Brak interaktywnego edytora planowania w tej iteracji

**Decyzja:** konfiguracja incydentu żyje w `scripts/core/scenario_l0.gd` jako jawne dane. UI ogranicza się do Start, Pauza/Wznów, Restart.

**Uzasadnienie:** celem L0 jest udowodnienie, że pętla symulacji jest deterministyczna i czytelna. Edytor kamer i waypointów to praca, która nie zmniejsza tego ryzyka.

**Konsekwencje:** zmiana konfiguracji incydentu wymaga edycji kodu. To świadome ograniczenie, nie brak — opisane w README.

---

## 2026-09-21 — `SUSPICION` nie porusza strażnikiem; `RETURN` domknięty o re-akwizycję

**Decyzja:** w stanie `SUSPICION` strażnik stoi w miejscu. Punktem wznowienia jest pozycja w chwili przerwania patrolu. Dodano przejście `RETURN → SUSPICION` przy ponownym dostrzeżeniu celu.

**Uzasadnienie:** kontrakt L0 nie wymaga, żeby strażnik szedł w stronę celu — dodanie „badania terenu" byłoby funkcją spoza zakresu. Przejście `RETURN → SUSPICION` tylko domyka maszynę stanów; bez niego strażnik byłby ślepy podczas powrotu.

**Konsekwencje:** ponieważ strażnik nie schodzi ze ścieżki, `RETURN` trwa w praktyce jeden tick. Przejazd powrotny jest pokryty osobnym testem FSM z przesuniętym punktem wznowienia. Tabela dozwolonych przejść (`GuardFsm.ALLOWED_TRANSITIONS`) jest jedynym źródłem prawdy dla testu „brak niedozwolonych przejść".

---

## 2026-09-21 — Zmiana nazwy katalogu i projektu

**Decyzja:** katalog projektu to `E:\OBJEKT\obiekt84`, `config/name = "OBIEKT '84"`.

**Uzasadnienie:** poprzednia nazwa katalogu `object-'84` zawierała apostrof, który psuje skrypty powłoki, pliki `.cmd` i ścieżki w CI. Nazwa projektu została ujednolicona z nazwą roboczą.

**Konsekwencje:** `config/features`, renderer (`d3d12`) i silnik fizyki 3D (Jolt) pozostały nietknięte, mimo że L0 ich nie używa.

---

## 2026-09-21 — Regresja golden log dla incydentu L0

**Decyzja:** zatwierdzony przebieg incydentu L0 jest zapisany jako artefakt repozytorium `tests/fixtures/l0_incident_golden_log.txt` i porównywany przez `tests/test_l0_golden_log.gd`. Format: plik tekstowy z dwiema sekcjami — `[EVENT_LOG]` z kanonicznym logiem (`tick|subject|event|reason`) i `[FINAL_STATE]` z kanonicznym snapshotem (`klucz=wartość`). Fixture **nigdy** nie jest nadpisywany przez test; aktualizuje się wyłącznie świadomie, razem ze zmianą zasad L0 i wpisem w tym pliku.

**Uzasadnienie:** test 50/50 dowodzi, że przebiegi są **wzajemnie** identyczne, ale przeszedłby także wtedy, gdyby zmiana reguł przesunęła wszystkie 50 przebiegów tak samo. Golden log domyka tę lukę — wiąże wynik z zatwierdzonym zachowaniem. Format tekstowy wybrano zamiast JSON, bo rdzeń **już** produkuje obie kanoniczne reprezentacje (`get_canonical_log()`, `get_canonical_snapshot()`); JSON wymagałby drugiego serializatora i wprowadzał ryzyko zależności od kolejności kluczy `Dictionary`. Publiczne API rdzenia nie zostało zmienione.

**Konsekwencje:** każda zmiana reguł FOV, FSM, kolejności faz ticka albo danych scenariusza zapali ten test na czerwono z dokładnym wskazaniem pierwszego różniącego się zdarzenia. **Czerwonego testu nie wolno „naprawiać" regeneracją fixture'u** — najpierw trzeba ustalić, czy zmiana zachowania była zamierzona. Skuteczność mechanizmu zweryfikowano eksperymentalnie: tymczasowa zmiana `guard_view_range` z 6 na 7 wywołała failure ze wskazaniem indeksu 6 i wartości `37|guard_01|SUSPICION|…` kontra `36|guard_01|SUSPICION|…`; zmianę cofnięto.

---

## 2026-09-21 — Wariant sukcesu jako lokalna modyfikacja danych, bez helpera w rdzeniu

**Decyzja:** druga ścieżka terminalna (`INTRUDER_SUCCESS`) jest pokryta fixturem `tests/fixtures/l0_success_golden_log.txt`. Wariant powstaje przez pobranie świeżych danych z `ScenarioL0.create()` i ustawienie w teście jednego pola: `guard_view_range = 4`. **Nie dodano helpera `create_success_variant()` w `ScenarioL0`** ani żadnej innej zmiany w rdzeniu.

**Uzasadnienie:** `ScenarioL0.create()` za każdym razem buduje nowy obiekt z nowymi tablicami, a `Simulation.initialize()` i tak wykonuje `duplicate_data()`. Modyfikacja zwróconego obiektu jest więc całkowicie izolowana — nie ma współdzielonego stanu, który mogłaby zepsuć. Helper w rdzeniu rozszerzałby publiczne API o dane istotne wyłącznie dla testu. Wartość 4 wybrano po pomiarze wszystkich kandydatów: daje 11 zdarzeń i jako jedyna pokrywa przy okazji pełny cykl `SUSPICION → RETURN → PATROL` (strażnik dostrzega intruza na jeden tick, gubi cel, wraca do patrolu, intruz kończy trasę w 40 ticku). Warianty 1–3 dają 8–9 zdarzeń i strażnik nic nie widzi.

**Konsekwencje:** sukces wynika z normalnej pracy silnika na innych danych wejściowych — nie ma wstrzykiwania zdarzeń, wymuszania outcome ani omijania `step()`. Osobny test pilnuje, że wariant nie przecieka do danych domyślnych. Gdyby w przyszłości pojawił się trzeci wariant, warto rozważyć wspólny helper testowy — ale dopiero wtedy, nie „na zapas".

---

## 2026-09-21 — Trzeci golden fixture: terminalna ścieżka TICK_LIMIT

**Decyzja:** ostatni terminalny wynik silnika (`OUTCOME_TICK_LIMIT`) jest pokryty fixturem `tests/fixtures/l0_tick_limit_golden_log.txt`. Wariant powstaje przez pobranie świeżych danych z `ScenarioL0.create()` i ustawienie w teście jednego pola: `max_ticks = 20`. Podobnie jak wariant sukcesu, **żyje wyłącznie w testach** — w `scripts/core/` nie ma ani helpera, ani zmiany API.

**Uzasadnienie wyboru limitu 20:** wykrycie następuje w 38 ticku, a sukces w 40, więc każdy limit ≤ 37 daje `TICK_LIMIT`. Wartość 20 jest kompromisem między minimalizmem a wartością diagnostyczną: log zawiera trzy minięte waypointy (ticki 1, 7, 15) plus wpis terminalny, a limit wypada **w trakcie** czwartego boku patrolu, a nie na waypoincie — dzięki temu widać wyraźnie, że przebieg został ucięty limitem, a nie zbiegiem okoliczności. Limit 1 dałby dwa zdarzenia i zerową wartość diagnostyczną, limit 37 rozciągałby log bez powodu.

**Zabezpieczenie przed wcześniejszym wykryciem lub sukcesem:** nie było potrzebne żadne dodatkowe wyłączanie detekcji. Wystarczyło, że limit wypada przed 38 tickiem. Test jawnie to weryfikuje: sprawdza, że intruz kończy w stanie `MOVE`, a log nie zawiera zdarzeń `DETECTED` ani `SUCCESS`. Reguły FOV, FSM i detekcji pozostały nietknięte.

**Kolejność warunków, potwierdzona empirycznie:** w fazie 7 `_resolve_outcome()` sprawdza kolejno `DETECTED` → `SUCCESS` → `tick >= max_ticks`, więc **tick limit ma najniższy priorytet**. Uruchomienie z `max_ticks = 38` kończy się `INTRUDER_DETECTED`, nie `TICK_LIMIT` — mimo że w tym samym ticku limit też jest osiągnięty.

**Konsekwencje:** wszystkie trzy terminalne wyniki silnika mają teraz golden regression. Zmiana kolejności faz, warunków terminalnych albo reguł patrolu zapali odpowiedni fixture ze wskazaniem pierwszej różnicy. Zmiana któregokolwiek fixture'u wymaga świadomej decyzji i wpisu w tym pliku.

---

## 2026-09-21 — Kontrakt priorytetu wyników terminalnych

**Decyzja:** gdy w tym samym ticku prawdziwe są jednocześnie wykrycie intruza i warunek `tick >= max_ticks`, wynikiem jest **`INTRUDER_DETECTED`, nie `TICK_LIMIT`**. Reguła jest pilnowana testem `tests/test_simulation.gd::test_detection_has_priority_over_tick_limit_on_same_tick`.

**Uzasadnienie:** priorytet wynika wyłącznie z kolejności gałęzi `if/elif` w `Simulation._resolve_outcome()` (`DETECTED` → `SUCCESS` → `tick >= max_ticks`). Do tej pory była to własność udokumentowana i zmierzona, ale **niepilnowana żadnym testem**. Sprawdzono to eksperymentalnie: po tymczasowym odwróceniu dwóch gałęzi **wszystkie 16 testów golden log przeszło bez zmian**, bo w żadnym z trzech zatwierdzonych przebiegów remis nie występuje. Nowy test tworzy remis jawnie, ustawiając `max_ticks = 38` na świeżych danych — dokładnie w ticku, w którym zapada wykrycie.

**Konsekwencje:** odwrócenie kolejności warunków terminalnych natychmiast zapala ten jeden test, ze wskazaniem błędnego outcome i błędnego powodu wpisu `FINISHED`. Test nie jest czwartym golden fixturem — sprawdza semantyczny kontrakt, a nie pełny przebieg. Zmiana kolejności warunków wymaga świadomej decyzji i wpisu w tym pliku.

---

## 2026-09-21 — Vertical slice L0: dostęp prezentacji do danych i rozmiar okna

**Decyzja 1 — `max_ticks` w snapshocie.** HUD pokazuje `tick / max_ticks`, a limit nie był dostępny poza rdzeniem. Dodano jedno read-only pole do `SimulationState.to_snapshot()`. **Nie ruszono `to_canonical()` ani `canonical_field_names()`**, więc wszystkie trzy golden fixture'y pozostają ważne bez zmian. To jedyna zmiana w `scripts/core/` w tej turze i jest zgodna z zasadą „najpierw dane już dostępne, potem minimalny accessor".

**Decyzja 2 — restart tworzy nową instancję `Simulation`.** Wcześniej Restart wołał `reset()` na tej samej instancji. Vertical slice wymaga świeżego scenariusza i świeżej symulacji, więc `_on_restart_requested()` buduje oba od nowa. To realna zmiana kontraktu sceny: testy integracyjne odczytują teraz `_simulation` ponownie po restarcie, zamiast trzymać starą referencję. `reset()` w rdzeniu pozostaje nietknięty i nadal jest pokryty testami core.

**Decyzja 3 — viewport 1280 × 800.** Domyślne 1152 × 648 nie mieści planszy 560 px razem z HUD, legendą sterowania i panelem dwunastu zdarzeń. Zmieniono wyłącznie `window/size/viewport_*` w `[display]`; renderer, `config/features` i ustawienia fizyki pozostały nietknięte.

**Konsekwencje:** granica core/presentation nie przesunęła się — rdzeń nadal nie zna sceny, nie czyta inputu i nie widzi delty. Wejście z klawiatury obsługuje wyłącznie `simulation_runner.gd` przez `_unhandled_input`. Widok nie ma własnej implementacji FOV: stożki rysuje tą samą funkcją `FovCalculator`, której używa rdzeń, wyłącznie w celach ilustracyjnych.

---

## 2026-09-21 — Warianty incydentu jako dane wejściowe w warstwie prezentacji

**Decyzja:** trzy warianty L0 (wykrycie, sukces intruza, limit ticków) są wybieralne z UI. Ich konfiguracja — `guard_view_range = 4` i `max_ticks = 20` na świeżych danych z `ScenarioL0.create()` — żyje w `scripts/presentation/simulation_runner.gd`. **Nie dodano `ScenarioL0.create_success_variant()` ani żadnego innego publicznego API w rdzeniu.**

**Uzasadnienie:** wariant to zestaw danych wejściowych, nie mechanika. Rdzeń nie potrzebuje wiedzieć, że ktoś chce obejrzeć inne zakończenie — `Simulation` przyjmuje dowolny `ScenarioL0` i pracuje tymi samymi regułami. Konfiguracja dwóch pól powtarza się między testami a koordynatorem, ale to powtórzenie **danych**, nie logiki gry; wyciąganie jej do rdzenia rozszerzyłoby publiczne API o coś potrzebne wyłącznie prezentacji i testom.

**Konsekwencje:** wszystkie trzy zakończenia da się zobaczyć bez edytowania kodu, a rdzeń pozostaje nietknięty — ta tura nie zmieniła ani jednej linii w `scripts/core/` i `scripts/actors/`. Gdyby warianty kiedyś stały się częścią rozgrywki (wybór misji), trzeba będzie je przenieść do danych domenowych i odnotować to tutaj.

---

## 2026-09-22 — Przewijanie przebiegu przez odtworzenie, nie przez historię stanów

**Decyzja:** cofanie i przewijanie w UI (`,`, `Home`, `End`, klik w oś czasu) realizuje `seek_to_tick(n)`, które buduje **świeżą** `Simulation` na tych samych danych i wykonuje dokładnie `n` kroków. Nie ma historii snapshotów, stosu undo ani zapisywania stanów pośrednich.

**Uzasadnienie:** historia stanów kosztowałaby pamięć, wymagała serializacji całego `SimulationState` i wprowadziła drugie źródło prawdy o przeszłości przebiegu — czyli dokładnie to, czego architektura L0 unika. Odtworzenie jest darmowe, bo przebieg ma kilkadziesiąt ticków, a rdzeń nie ma żadnego wejścia poza danymi scenariusza. Przy 38 tickach przewinięcie to 38 wywołań `step()`.

**Konsekwencje — i to jest istotne:** determinizm przestał być wyłącznie właściwością testów, a stał się **warunkiem poprawności funkcji, której używa człowiek**. Gdyby rdzeń przestał być deterministyczny, przewijanie zaczęłoby pokazywać inny przebieg niż ten, który tester przed chwilą oglądał — i byłoby to widoczne gołym okiem, bez patrzenia w testy. Testy 50/50 i golden logi pozostają pierwszą linią obrony, ale przewijanie jest teraz drugą, działającą w czasie rzeczywistym.

Praktyczna konsekwencja dla przyszłych zmian: **każde wprowadzenie stanu, który nie wynika z danych scenariusza i liczby wywołań `step()`, złamie przewijanie.** Dotyczy to w szczególności jakiejkolwiek losowości, zależności od czasu systemowego i trzymania stanu w node'ach. Zakazy z `CLAUDE.md` mają więc od teraz widoczny objaw naruszenia, nie tylko czerwony test.

---

## 2026-09-23 — Czcionki DejaVu dołączone do repozytorium zamiast `SystemFont`

**Decyzja:** w `assets/fonts/` leżą dwie niezmodyfikowane czcionki DejaVu (licencja Bitstream Vera, `assets/fonts/LICENSE_DejaVu.txt`): `DejaVuSansMono.ttf` dla panelu statusu, legendy i event logu (`hud.gd`, `MONOSPACE_FONT`) oraz `DejaVuSans.ttf` jako domyślna czcionka projektu (`gui/theme/custom_font`). Decyzję zatwierdził właściciel („ok czcionka”), bo zasady repo zabraniają dodawania assetów bez decyzji.

**Uzasadnienie:** `SystemFont` działał tylko na desktopie z zainstalowaną czcionką monospace. W eksporcie Web (GitHub Pages) i w kontenerze CI Godot cofał się do czcionki proporcjonalnej. Skutki: 6 testów układu HUD czerwonych wyłącznie w CI, nachodzące na siebie wiersze legendy i logu w przeglądarce oraz puste kwadraty zamiast znaczników `●`, `○`, `►`. Domyślna czcionka Godota nie ma tych znaków, a w przeglądarce nie ma systemowego fallbacku. Obie czcionki DejaVu je mają.

**Konsekwencje:** wygląd jest identyczny na Windows, w CI i w przeglądarce. Build Web rośnie o ok. 1,1 MB (przy 39 MB wasm). Krok instalujący fontconfig w CI został usunięty, bo testy nie zależą już od systemu.
