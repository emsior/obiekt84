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
