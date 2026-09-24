# MVP L0 — kryteria

## Zakres

Jeden ręcznie skonfigurowany incydent: siatka 20 × 20, jeden strażnik z czterema waypointami, jedna statyczna kamera, jeden intruz na jawnej trasie, tick logiczny 10 Hz, event log.

Wokół tego narosła warstwa prezentacji, której zadaniem jest **pokazać decyzje silnika człowiekowi**: trzy warianty incydentu wybierane z UI, trzy tempa podglądu, wyróżnienie ticków decyzji na planszy i w logu, oś czasu przebiegu oraz przewijanie w obie strony.

Konfiguracja samego incydentu jest nadal danymi w kodzie (`scripts/core/scenario_l0.gd`), nie interaktywnym edytorem. Warianty to te same dane z jednym zmienionym polem, a nie osobne scenariusze.

## Sukces L0

- [x] 50/50 uruchomień headless daje identyczny kanoniczny event log.
- [x] 50/50 uruchomień daje identyczny końcowy snapshot.
- [x] Tester widzi w UI patrol i wynik incydentu.
- [x] Tester potrafi uruchomić, zatrzymać i zresetować poziom.
- [x] Reset zajmuje mniej niż 20 sekund z perspektywy testera.
- [x] Stan po resecie jest identyczny ze stanem początkowym.
- [x] Core działa bez uruchamiania sceny.

Wszystkie kryteria są odhaczone. Podstawa dla każdego jest podana niżej — część pochodzi z testów headless, część z obejrzenia działającego okna.

## Porażka L0

Każdy z poniższych punktów oznacza, że L0 nie jest gotowy:

- różne logi dla identycznych danych wejściowych;
- desynchronizacja UI względem stanu rdzenia;
- pozycja node'a wpływająca na wynik symulacji;
- zależność wyniku od FPS;
- zależność wyniku od czasu systemowego;
- orphan nodes po testach integracyjnych;
- reset nieodtwarzający stanu początkowego;
- konieczność ręcznego klikania, żeby wykonać testy rdzenia.

## Stan bieżący (2026-09-23)

Zestaw testów: **107 przypadków, 0 błędów, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit code 0.**

Trzy terminalne zakończenia silnika, wszystkie dostępne z UI i wszystkie pokryte golden fixture'em:

| Wariant | Przebieg | Wynik |
|---|---|---|
| Wykrycie | strażnik dostrzega intruza w 37 ticku (`SUSPICION`), potwierdza w 38 (`ALARM`) | `INTRUDER_DETECTED`, tick 38 |
| Sukces intruza | strażnik widzi cel na jeden tick, gubi go i wraca do patrolu | `INTRUDER_SUCCESS`, tick 40 |
| Limit ticków | przebieg urywa się przed jakimkolwiek wykryciem | `TICK_LIMIT`, tick 20 |

**Pierwszy przebieg okienkowy — wykonany.** Projekt uruchomiony w prawdziwym oknie (D3D12, GTX 1080, exit 0). Wszystkie trzy zakończenia obejrzane na zrzutach z żywego rendera: czerwone `INTRUZ WYKRYTY — tick 38`, zielone `INTRUZ DOTARŁ DO CELU — tick 40`, pomarańczowe `LIMIT TICKÓW WYCZERPANY — tick 20`. Potwierdzone wizualnie: układ mieści się bez ucięć i nachodzeń, czcionka o stałej szerokości działa, kolumny event logu się zgadzają, białe wyróżnienie decyzji jest czytelne także na czerwonym stożku `ALARM`, znaczniki osi czasu są widoczne.

Ocenę „czy interfejs nie przytłacza" wystawił właściciel projektu po otwarciu okna: **nie przytłacza**.

**Poprawki czytelności wynikłe z obejrzenia**, nie ze zgadywania: przywrócona hierarchia nagłówka nad podtytułem, znaczniki osi czasu na pełną wysokość, ciemny pierścień odcinający aktorów od tła (strażnik w stanie `ALARM` znikał we własnym czerwonym stożku), turkusowy stożek kamery zamiast niebieskiego (zlewał się z trasą intruza).

**Co pozostaje poza L0:** ściany i pola zablokowane nie istnieją w danych scenariusza, interaktywny edytor planowania jest świadomie odłożony, a konfiguracja incydentu poza trzema wariantami nadal wymaga edycji kodu. To zakres L1, nie brak w L0.

## L1-A — „PLAN → RUN” (2026-09-24)

Cel: build przestaje być odtwarzaczem incydentu i staje się grą. W fazie PLAN gracz przeciąga cztery węzły patrolu i kamerę (klik obraca kamerę), w fazie RUN ogląda deterministyczną noc, a po wyniku wraca do planu z zachowanym planem. Decyzja i granica rdzeń/prezentacja: [DECISIONS.md](DECISIONS.md), wpis z 2026-09-24. Trzy warianty L0 zniknęły z UI — żyją wyłącznie w testach golden log.

### Kryteria

- [x] **Domyślny plan przegrywa.** `ScenarioL0.create_puzzle()` → `INTRUDER_SUCCESS` w 40 ticku. Strażnik dostrzega intruza w 32, gubi w 33 i wraca do patrolu. Testy: `test_l0_golden_log.gd::test_puzzle_default_ends_with_intruder_success` + golden `l0_puzzle_default_golden_log.txt`; determinizm: `test_simulation.gd::test_fifty_independent_puzzle_runs_are_identical`. *Stan L1-A; od L1-C dane zagadki są inne — patrz sekcja L1-C.*
- [x] **Rozwiązanie referencyjne wygrywa.** W L1-A: ten sam patrol, kamera przeniesiona na `(17,9)` i skierowana w dół → `INTRUDER_DETECTED` przez kamerę w 36 ticku. *Od L1-C kamera nie wykrywa — rozwiązanie referencyjne i jego testy są opisane w sekcji L1-C.*
- [ ] **Powrót do planu < 20 s.** Technicznie to jeden klawisz (`P`) albo jeden przycisk, bez przeładowania sceny. Kryterium z perspektywy gracza czeka na obejrzenie przez właściciela.
- [x] **Plan przeżywa RUN.** Po powrocie z przerwanej i z zakończonej nocy draft jest identyczny, a edycja w trakcie nocy nie zmienia działającej `Simulation` ani danych jej restartu. Testy: `test_plan_editor.gd::test_plan_survives_run_and_return`, `test_editing_changes_draft_not_running_simulation`.
- [x] **Build Web na Pages gra się myszą bez klawiatury poza Spacją.** Pokryte strukturalnie: korzeń HUD nie łapie myszy, przyciski nie przejmują fokusu, każda akcja ma przycisk (`test_main_scene.gd::test_hud_does_not_steal_mouse_or_space`). Potwierdzone na Pages po pushu — podpunkt niżej.
  - **L1-B, 2026-09-24 — lokalny build Web (`build/web/`, serwer HTTP 127.0.0.1) przetestowany myszą w Chromium:** obrót kamery kliknięciem, przeciąganie kamery i węzła, odrzucenie kamery na trasie z czerwonym komunikatem, przycisk *Uruchom noc* → `DANE WYKRADZIONE — tick 40`, *Wróć do planu* z zachowanym planem, kamera (17,9)↓ → `OBIEKT ZABEZPIECZONY — tick 36`, klik w oś czasu. Konsola bez błędów, wszystkie żądania 200. Test ujawnił, że pełnoekranowy `Background` (`ColorRect`) zjadał kliknięcia na planszy i osi czasu — naprawione (`mouse_filter = IGNORE`), pilnuje tego `test_main_scene.gd::test_board_mouse_input_reaches_runner_through_viewport`. Kryterium zostaje `[ ]` do sprawdzenia na **Pages** po pushu.
  - **Pages, 2026-09-24 — potwierdzone** na `https://emsior.github.io/obiekt84/` po pushu `7e9e6bb` (CI run 36021972202: testy, eksport Web i wdrożenie Pages zielone), w Chromium, samą myszą: faza PLAN bez osi czasu; obrót kamery kliknięciem (4 kliknięcia = pełny obrót); przycisk *Uruchom noc* → plan domyślny `DANE WYKRADZIONE — tick 40`; *Wróć do planu*; przeciągnięcie kamery na (12,9) → nadal `DANE WYKRADZIONE — tick 40`, przy intruzie `NAMIERZONY`, w logu `31 MARKED`; przeciągnięcie węzła 3 z (16,7) na (16,8) → `OBIEKT ZABEZPIECZONY — tick 32` (`ALARM intruder_marked_by_camera`, `DETECTED guard_alarm`); klik w oś czasu → tick 20; powrót do planu z zachowanym planem. Konsola: tylko trzy wiersze startowe Godota, bez błędów; wszystkie 5 żądań → 200; build jednowątkowy, `crossOriginIsolated = false`.

## L1-C — „Kamera namierza, strażnik zatrzymuje” (2026-09-24)

Cel: wygrana ma wymagać ułożenia patrolu. W L1-A sama kamera wygrywała w 613 z 1420 ustawień, a żadna para węzeł × kamera nie wymagała obu. Teraz kamera tylko namierza intruza, a zatrzymuje go strażnik — po namierzeniu wystarcza mu jeden tick widoczności. Decyzja, liczby i ich źródła: [DECISIONS.md](DECISIONS.md), wpis L1-C.

### Kryteria

- [x] **Sama kamera nigdy nie wygrywa.** Patrol domyślny × wszystkie 1420 dozwolonych ustawień kamery → 0 wygranych. Test wyczerpujący: `test_puzzle_design.gd::test_camera_alone_never_wins_with_default_patrol`.
- [x] **Plan domyślny przegrywa.** Strażnik w ogóle nie widzi intruza, `INTRUDER_SUCCESS` w 40 ticku. Testy: `test_puzzle_design.gd::test_default_plan_loses_and_guard_never_sees_intruder` + golden `l0_puzzle_default_golden_log.txt`.
- [x] **Rozwiązanie referencyjne wymaga patrolu i kamery naraz.** Węzeł 3 na `(16,8)` + kamera `(12,9)` w dół → `MARKED` w 31, alarm strażnika w 32, `INTRUDER_DETECTED`. Każda z tych zmian osobno przegrywa. Testy: `test_puzzle_design.gd::test_reference_solution_requires_both_patrol_and_camera`, `test_l0_golden_log.gd::test_puzzle_solution_ends_with_guard_alarm_after_camera_mark` + golden `l0_puzzle_solution_golden_log.txt`, pętla gry przez edytor: `test_plan_editor.gd::test_player_can_turn_loss_into_win_through_editor`.
- [x] **Trzy golden logi L0 bez zmian.** Diff pusty; testy golden L0 zielone.
- [ ] **Gracz rozumie regułę z ekranu.** W planie linia „zasada: kamera namierza — strażnik zatrzymuje”, w nocy `NAMIERZONY` przy intruzie i `MARKED` w panelu zdarzeń. Do obejrzenia przez właściciela.
