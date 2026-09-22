# Architektura L0

Dokument opisuje wyłącznie to, co istnieje w L0. Nie opisuje hipotetycznej przyszłej gry.

## Granica core / presentation

```text
scripts/core/  +  scripts/actors/      scripts/presentation/  +  scripts/ui/
──────────────────────────────────     ────────────────────────────────────
klasy RefCounted                       node'y Godota
zero node'ów                           Node2D, Control, Button, Label, Timer
zero SceneTree                         Timer wywołuje step()
zero delty i czasu rzeczywistego       czyta snapshot i kopię logu, rysuje
zero inputu                            czyta klawiaturę i mysz
        ── snapshot, kopia event logu ──▶
        ◀── initialize() / step() ──
```

Przepływ jest jednokierunkowy. Rdzeń nie wie, że istnieje scena. Prezentacja nie może zapisać niczego do rdzenia: snapshot i event log są kopiami, a jedyne wejścia zapisujące to `initialize()` i `step()`.

`Simulation.reset()` istnieje w API rdzenia i jest pokryty testami core, ale **prezentacja go nie używa** — restart, zmiana wariantu i przewijanie budują świeżą `Simulation` przez `initialize()`. Powód w sekcji o przewijaniu niżej.

## Źródło prawdy

Źródłem prawdy jest `SimulationState`. Scene Tree **nie** przechowuje pozycji logicznych, stanów FSM, numeru ticka, faktu wykrycia, waypointów, trasy intruza, wyniku incydentu ani event logu.

Transformacja node'a jest wynikiem prezentacji. Nie wraca do rdzenia, nie wpływa na FOV, ruch, event log ani wynik i nie jest częścią snapshotu domenowego.

## Stały tick 10 Hz

`Simulation.TICKS_PER_SECOND = 10`, `SECONDS_PER_TICK = 0.1`.

To częstotliwość **logiczna**, nie klatkowa. Rdzeń nigdy nie widzi `delta`. `Timer` w `main.tscn` jest wyłącznie tempem wizualnym: każdy `timeout` wywołuje dokładnie jeden jawny `step()`. Jitter Timera nie może zmienić wyniku, bo wynik nie zależy od tego, *kiedy* `step()` został wywołany — tylko od tego, **ile razy**.

Testy rdzenia wołają `step()` w pętli `for`, bez Timera i bez czekania.

## Przepływ jednego ticka

Kolejność faz jest stała i nigdy nie zależy od Scene Tree:

1. **Zwiększenie numeru ticka** — dokładnie raz, na początku kroku.
2. **Ruch intruza** — najwyżej do następnej komórki jawnej trasy.
3. **Ruch strażnika** — zależny od stanu FSM: `PATROL` idzie po waypointach, `RETURN` wraca do punktu wznowienia, `SUSPICION` i `ALARM` stoją.
4. **FOV kamery.**
5. **FOV strażnika.**
6. **Aktualizacja FSM** — najpierw strażnik, potem intruz.
7. **Rozstrzygnięcie wyniku terminalnego.**
8. **Dopisanie zdarzeń do logu** — z bufora zebranego w fazach 2–7, w kolejności powstania.
9. **Udostępnienie snapshotu** warstwie prezentacji.

**Priorytet wykrycia:** jeżeli w tym samym ticku intruza wykryją kamera i strażnik, powód zapisany w logu to `camera_detection`.

**Priorytet zakończenia:** wykrycie wyprzedza sukces. Jeżeli w tym samym ticku intruz dotrze na koniec trasy i zostanie wykryty, wynikiem jest `INTRUDER_DETECTED`.

Po osiągnięciu stanu terminalnego `step()` jest bezpiecznym no-op: nie zwiększa ticka, nie zmienia stanu i nie dopisuje zdarzeń.

## Model danych

Wszystkie pozycje to `Vector2i`. Kierunek patrzenia to jeden z czterech kierunków kardynalnych. Ruch zmienia pozycję najwyżej o jedną komórkę na tick.

Identyfikatory są stabilne: `guard_01`, `intruder_01`, `camera_01`.

Siatka 20 × 20 to para liczb w `Grid`, nie 400 node'ów.

## Ruch bez pathfindingu

- **Intruz** ma kompletną, jawną listę komórek. Osiągnięcie końca trasy bez wykrycia daje `SUCCESS`.
- **Strażnik** ma cztery waypointy. Reguła ruchu: **najpierw oś X, potem oś Y**, jedna komórka na tick, bez omijania przeszkód. Scenariusz jest ręcznie dobrany tak, żeby ta reguła wystarczała.

Żadnego AStar, NavMesh ani `NavigationAgent2D`.

## Matematyczne FOV

```gdscript
to_target = target - observer
to_target == Vector2i.ZERO            -> niewidoczny (ta sama komórka)
dist² > range²                        -> niewidoczny
dot = to_target · facing;  dot <= 0   -> niewidoczny (cel za obserwatorem)
cross = to_target × facing
cross² <= dot²                        -> widoczny (stożek 90°, 45° na stronę)
```

Wszystko na liczbach całkowitych. Granica zasięgu i granica kąta są **widoczne**. Brak okluzji ścian — w L0 nie ma ścian.

Widok rysuje stożki tą samą funkcją, ale wyłącznie w celach ilustracyjnych; niczego nie liczy na potrzeby logiki.

## Event log

Wpis: `{tick, subject, event, reason}`. Bez timestampów czasu rzeczywistego, bez losowych identyfikatorów, bez zależności od kolejności node'ów.

Kolejność wpisów wynika z kolejności faz ticka. Zdarzenia danego ticka są zbierane do bufora i dopisywane w fazie 8.

Serializacja kanoniczna: jeden wiersz na zdarzenie, stała kolejność pól:

```text
tick|subject|event|reason
```

Nie opieramy dowodu determinizmu na domyślnej serializacji `Dictionary`. Snapshot ma własną kanoniczną reprezentację — jawnie uporządkowaną listę pól `klucz=wartość`.

## Reset

`reset()` ustawia tick na `0`, przywraca stan początkowy strażnika i intruza, zeruje wynik i **kasuje log poprzedniego przebiegu**. `initialize()` nie generuje żadnych zdarzeń, więc stan po resecie jest nieodróżnialny od stanu po inicjalizacji.

Rdzeń trzyma własną kopię scenariusza, więc reset zawsze odtwarza te same dane wejściowe niezależnie od tego, co stało się z obiektem przekazanym do `initialize()`.

`reset()` jest używany przez testy rdzenia. **Warstwa prezentacji go nie woła** — Restart, zmiana wariantu i przewijanie budują świeżą `Simulation` przez `initialize()`, bo wariant może wnieść inne dane wejściowe, a `reset()` z definicji wraca do danych, z którymi instancja została zainicjalizowana.

## Warstwa prezentacji

Cztery skrypty, jasno rozdzielone odpowiedzialnościami:

| Plik | Odpowiedzialność |
|---|---|
| `scripts/presentation/simulation_runner.gd` | koordynator: właściciel wariantu, tempa, wejścia i cyklu życia `Simulation` |
| `scripts/presentation/level_view.gd` | rysuje planszę, aktorów, trasę i stożki ze snapshotu |
| `scripts/presentation/timeline_view.gd` | rysuje oś czasu przebiegu; odwzorowuje piksel na tick |
| `scripts/ui/hud.gd` | pasywny HUD: wyświetla to, co dostanie, i emituje intencje sygnałami |

Tylko koordynator dotyka `Simulation`. Widoki i HUD dostają gotowe dane i nie decydują o niczym: `level_view` dostaje listę komórek do wyróżnienia, `timeline_view` listę ticków ze zdarzeniami, HUD słownik `ui_state`. HUD nie zna FSM ani reguł — nie interpretuje zdarzeń, tylko oznacza wiersze wskazane przez koordynatora.

**Wejście** (klawiatura i mysz) obsługuje wyłącznie `simulation_runner.gd` w `_unhandled_input`. Rdzeń nigdy nie widzi inputu.

**Warianty incydentu** to wyłącznie różne dane wejściowe: świeże `ScenarioL0.create()` z jednym zmienionym polem (`guard_view_range` albo `max_ticks`). Konfiguracja żyje w koordynatorze, bo potrzebuje jej tylko prezentacja — rdzeń nie dostał API wariantów.

**Tempo podglądu** zmienia wyłącznie `wait_time` Timera. Liczba i kolejność wywołań `step()` są bez zmian, więc przebieg przy 0,5× i 2× daje identyczny kanoniczny log.

## Przewijanie przebiegu

`seek_to_tick(n)` nie cofa stanu i nie trzyma historii snapshotów. Buduje **świeżą** `Simulation` na tych samych danych i wykonuje dokładnie `n` kroków.

Działa to **wyłącznie dzięki determinizmowi rdzenia**: ten sam scenariusz zawsze daje ten sam przebieg, więc odtworzony tick jest identyczny z oryginalnym. To jedyne miejsce w UI, które korzysta z kontraktu determinizmu wprost — i jednocześnie jego praktyczny test: gdyby rdzeń przestał być deterministyczny, przewijanie zaczęłoby pokazywać inny przebieg niż ten, który tester przed chwilą oglądał.

Przewijanie zatrzymuje automatyczny przebieg, zachowuje wariant i tempo, a cofnięcie się przed tick terminalny zdejmuje stan końcowy.

## Jak działa test deterministyczny

`tests/test_simulation.gd::test_fifty_independent_runs_are_identical`:

1. Przebieg 0 tworzy **referencyjny** kanoniczny log i kanoniczny snapshot końcowy.
2. Przebiegi 1–49 wykonują się w pętli `for`. Każdy tworzy **świeżą instancję** `Simulation` i **świeże dane scenariusza** z `ScenarioL0.create()`.
3. Każdy przebieg kręci `step()` do stanu terminalnego, nie dłużej niż twardy limit 500 kroków.
4. Wynik jest porównywany z referencją **natychmiast**, a referencje do badanego przebiegu wygasają po powrocie z funkcji pomocniczej. W pamięci nigdy nie ma 50 symulacji ani 50 pełnych kopii logu.
5. Przy niezgodności komunikat asercji podaje numer przebiegu, pierwszy różniący się wiersz oraz wartość oczekiwaną i rzeczywistą.

Bez fuzzingu — dane wejściowe są w każdym przebiegu identyczne. Bez Timerów, sceny, inputu i czasu rzeczywistego.

Reset jest sprawdzany **osobnym** testem na tej samej instancji, a 20 cykli Start/Pauza/Restart — osobnym testem integracyjnym sceny.
