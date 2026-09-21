# Formularz playtestu L0

Jedna sesja, jeden tester, około 10 minut. Nie podpowiadaj — notuj, co tester robi sam.

**Tester:** ______________  **Data:** ______________  **Wersja / commit:** ______________

---

## Przebieg

1. Otwórz `main.tscn` i uruchom grę (F5). Nie tłumacz interfejsu.
2. Poproś testera, żeby „uruchomił incydent".
3. Pozwól obejrzeć całość do wyniku.
4. Poproś o powtórzenie próby.

---

## Pytania

**1. Czy tester rozumie, co robi Start?**

☐ tak ☐ z wahaniem ☐ nie — notatka: ______________________________________

**2. Czy rozumie, dlaczego intruz został wykryty?**

☐ tak ☐ częściowo ☐ nie — notatka: ______________________________________

**3. Czy event log pomaga wyjaśnić wynik?**

☐ tak ☐ tylko po podpowiedzi ☐ nie zauważył logu — notatka: ______________

**4. Czy potrafi użyć Pauzy i Restartu?**

☐ obu ☐ tylko jednego ☐ żadnego — notatka: ______________________________

**5. Czy po resecie stan wygląda identycznie?**

☐ tak ☐ nie wie ☐ zauważył różnicę — notatka: _____________________________

**6. Co było niejasne?**

_______________________________________________________________________

_______________________________________________________________________

**7. Czy tester chce uruchomić próbę ponownie po zmianie konfiguracji w przyszłej wersji?**

☐ tak, chętnie ☐ obojętnie ☐ nie — notatka: ______________________________

---

## Obserwacje prowadzącego

Ile sekund minęło, zanim tester kliknął cokolwiek: ______

Czy patrzył na siatkę czy na panel boczny: ______________________________

Pierwsza rzecz, o którą zapytał: ________________________________________

---

# Checklista manualna vertical slice L0

Do przejścia przed każdą sesją playtestu. Uruchom `F5` w edytorze albo `"%GODOT_BIN%" --path .`.

## Stan startowy

- [ ] Okno otwiera się, plansza 20 × 20 jest widoczna po lewej, HUD po prawej.
- [ ] Status pokazuje `PAUSED`, tick `0 / 400`.
- [ ] Widać trasę intruza, cztery waypointy, żółty marker celu, kamerę i strażnika.
- [ ] Stożki widzenia kamery i strażnika są widoczne.
- [ ] Panel zdarzeń jest pusty (`— brak zdarzeń —`).

## Sterowanie

- [ ] **N** przesuwa symulację dokładnie o jeden tick — licznik rośnie o 1, pozycje aktorów przeskakują o jedną komórkę.
- [ ] **Spacja** uruchamia przebieg, status zmienia się na `RUNNING`; drugie naciśnięcie zatrzymuje, status wraca na `PAUSED`.
- [ ] W pauzie tick nie rośnie.
- [ ] **Escape** zatrzymuje przebieg (status `PAUSED`) i nie robi nic więcej.
- [ ] **F** ukrywa i przywraca stożki widzenia; HUD odnotowuje `stożki: ukryte` / `widoczne`.
- [ ] **L** ukrywa i przywraca panel zdarzeń.
- [ ] Przyciski **Start**, **Pauza/Wznów**, **Restart** działają tak samo jak klawisze.

## Przebieg domyślny — wykrycie intruza

- [ ] Strażnik obchodzi prostokąt patrolu, w HUD pojawiają się wpisy `WAYPOINT_REACHED`.
- [ ] W 37 ticku strażnik przechodzi w `SUSPICION` — kolor strażnika i stożka zmienia się.
- [ ] W 38 ticku strażnik przechodzi w `ALARM`, intruz w `DETECTED`.
- [ ] Komunikat końcowy jest **czerwony**: `INTRUZ WYKRYTY — tick 38`.
- [ ] Status zmienia się na `FINISHED`, automatyczny przebieg zatrzymuje się sam.
- [ ] Dalsze naciskanie **N** i **Spacji** nic nie zmienia.

## Sukces intruza i limit ticków

Oba warianty wymagają zmiany danych scenariusza w `scripts/core/scenario_l0.gd` — w tej iteracji nie ma UI planowania.

- [ ] `guard_view_range = 4`: intruz dochodzi do celu, komunikat **zielony** `INTRUZ DOTARŁ DO CELU — tick 40`.
- [ ] `max_ticks = 20`: przebieg urywa się, komunikat **pomarańczowy** `LIMIT TICKÓW WYCZERPANY — tick 20`.

## Restart

- [ ] **R** ustawia tick na `0`, status na `PAUSED`, komunikat końcowy na `incydent w toku`.
- [ ] Panel zdarzeń jest pusty.
- [ ] Aktorzy wracają na pozycje startowe.
- [ ] Reset jest natychmiastowy — poniżej 20 sekund z perspektywy testera.
- [ ] Dwudziesty restart wygląda identycznie jak pierwszy.
