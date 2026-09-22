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

## Trzy warianty incydentu

Wybierane klawiszami `1` / `2` / `3` albo przyciskami w HUD. Żadnej edycji kodu.

- [ ] `1` — **Wykrycie**: HUD pokazuje `SCENARIUSZ: WYKRYCIE`, tick `0 / 400`. Po uruchomieniu Spacją przebieg kończy się **czerwonym** `INTRUZ WYKRYTY — tick 38`.
- [ ] `2` — **Sukces**: HUD pokazuje `SCENARIUSZ: SUKCES INTRUZA`, tick `0 / 400`, zasięg strażnika `4`. Przebieg kończy się **zielonym** `INTRUZ DOTARŁ DO CELU — tick 40`. W panelu zdarzeń widać pełny cykl `SUSPICION` → `RETURN` → `PATROL`.
- [ ] `3` — **Limit ticków**: HUD pokazuje `SCENARIUSZ: LIMIT TICKÓW`, tick `0 / 20`. Przebieg kończy się **pomarańczowym** `LIMIT TICKÓW WYCZERPANY — tick 20`. W logu **nie ma** zdarzeń `DETECTED` ani `SUCCESS`.

## Przełączanie wariantów

- [ ] Aktywny wariant ma wypełniony znacznik `●` na przycisku, pozostałe `○`.
- [ ] Zmiana wariantu w trakcie automatycznego przebiegu zatrzymuje go i restartuje.
- [ ] Po zmianie wariantu komunikat końcowy poprzedniego przebiegu **natychmiast znika** i wraca `incydent w toku`.
- [ ] Po zmianie wariantu panel zdarzeń jest pusty, tick `0`, status `PAUSED`.
- [ ] Limit ticków w HUD odpowiada wybranemu wariantowi (`400` albo `20`).
- [ ] **R** restartuje **ten sam** wariant, nie wraca do wykrycia.
- [ ] Przyciski robią dokładnie to samo co klawisze.

## Restart

- [ ] **R** ustawia tick na `0`, status na `PAUSED`, komunikat końcowy na `incydent w toku`.
- [ ] Panel zdarzeń jest pusty.
- [ ] Aktorzy wracają na pozycje startowe.
- [ ] Reset jest natychmiastowy — poniżej 20 sekund z perspektywy testera.
- [ ] Dwudziesty restart wygląda identycznie jak pierwszy.

## Tempo podglądu

Tempo zmienia wyłącznie odstęp między krokami. Wynik przebiegu musi być identyczny w każdym tempie.

- [ ] Po starcie HUD pokazuje `tempo: 1×   [Normalnie]`, aktywny przycisk `● Normalnie 1×`.
- [ ] `[` przełącza na `0,5×  [Wolno]`, `]` na `2×  [Szybko]`; marker `●` wędruje za wyborem.
- [ ] `[` przy 0,5× zostaje na 0,5×; `]` przy 2× zostaje na 2×.
- [ ] Przyciski tempa działają identycznie jak klawisze.

Dla **każdego** z trzech wariantów (`1`, `2`, `3`):

- [ ] Przy 0,5× da się zobaczyć przejście `SUSPICION → ALARM` — w wariancie wykrycia zmianę koloru strażnika i stożka między tickiem 37 a 38.
- [ ] W wariancie sukcesu przy 0,5× widać pełny cykl `SUSPICION` → `RETURN` → `PATROL` (ticki 38–40).
- [ ] Przy 2× przebieg wyraźnie przyspiesza, ale kończy się tym samym wynikiem i tym samym logiem.
- [ ] `N` wykonuje dokładnie jeden tick niezależnie od ustawionego tempa.

Zachowanie tempa:

- [ ] Zmiana tempa w trakcie przebiegu **nie** resetuje ticka ani nie czyści panelu zdarzeń.
- [ ] Zmiana tempa w trakcie przebiegu nie wykonuje dodatkowego ticka w chwili przełączenia.
- [ ] Po `R` wybrane tempo zostaje bez zmian.
- [ ] Po przełączeniu wariantu `1` / `2` / `3` wybrane tempo zostaje bez zmian.
- [ ] Po wyniku terminalnym zmiana tempa **nie** wznawia przebiegu — status zostaje `FINISHED`.

## Wyróżnienie decyzji

Cel: tester ma skojarzyć zmianę na planszy z wpisem w logu bez podpowiedzi.

- [ ] Przy zwykłym mijaniu waypointu (ticki 1, 7, 15, 21, 29, 35 w wariancie wykrycia) **nic nie jest wyróżnione** — brak białego obrysu i brak `►` w logu.
- [ ] W ticku 37 komórka strażnika dostaje biały obrys, a wiersz `SUSPICION` w panelu ma `►`.
- [ ] W ticku 38 wyróżnione są **dwie** komórki: strażnika i intruza; w logu `►` mają trzy wiersze (`ALARM`, `DETECTED`, `FINISHED`).
- [ ] Wyróżnienie znika przy następnym ticku.
- [ ] W wariancie sukcesu przy 0,5× widać kolejno wyróżnione ticki 38 (`SUSPICION`), 39 (`RETURN`), 40 (`PATROL` + `SUCCESS` + `FINISHED`).
- [ ] Ukrycie panelu zdarzeń klawiszem `L` nie wyłącza wyróżnienia na planszy.

## Oś czasu przebiegu

- [ ] Pod planszą widać pasek z podpisem `tick 0` po lewej i numerem horyzontu po prawej.
- [ ] W wariantach wykrycia i sukcesu horyzont wynosi `40`, w wariancie limitu `20`.
- [ ] Biały kursor przesuwa się w prawo z każdym tickiem; przebyta część paska jest jaśniejsza.
- [ ] Po zakończeniu przebiegu wykrycia widać dwie kreski: pomarańczową (tick 37) i czerwoną (tick 38).
- [ ] W wariancie sukcesu widać trzy kreski: 38, 39 i czerwoną 40.
- [ ] W wariancie limitu jedna czerwona kreska na końcu paska (tick 20).
- [ ] Rutynowe waypointy **nie** mają kresek na osi.
- [ ] Restart i zmiana wariantu czyszczą oś.

## Cofanie przebiegu

Cofanie nie jest mechanizmem undo — to odtworzenie przebiegu od zera do wskazanego ticka. Działa, bo rdzeń jest deterministyczny.

- [ ] Po zakończeniu wariantu wykrycia (`tick 38`) klawisz `,` cofa do ticka 37.
- [ ] Status przestaje być `FINISHED`, komunikat końcowy wraca na `incydent w toku`.
- [ ] Strażnik jest znowu w stanie `SUSPICION`, a jego komórka wyróżniona.
- [ ] `.` albo `N` doprowadza z powrotem do ticka 38 i **tego samego** wyniku.
- [ ] Wielokrotne cofanie i odtwarzanie nigdy nie zmienia wyniku ani panelu zdarzeń.
- [ ] Na ticku 0 `,` nic nie robi, a przycisk `◀ krok` jest wyszarzony.
- [ ] Cofanie zachowuje wybrany wariant i tempo.
- [ ] Cofanie zatrzymuje automatyczny przebieg.
- [ ] Przyciski `◀ krok [,]` i `krok [.] ▶` działają identycznie jak klawisze.

## Przewijanie osi czasu

- [ ] Nad paskiem widać podpis `przebieg: tick N   (kliknij, aby przewinąć)`.
- [ ] Kliknięcie w połowie paska przewija do ticka `20` (przy horyzoncie 40).
- [ ] Kliknięcie tuż przed prawym końcem przewija do ticka `38` i pokazuje wynik wykrycia.
- [ ] Kliknięcie na lewej krawędzi wraca do ticka `0`.
- [ ] Kliknięcie poza paskiem — na planszy albo w HUD — nic nie przewija.
- [ ] Trafienie działa też kilka pikseli nad i pod paskiem, nie trzeba celować co do piksela.
- [ ] `Home` wraca na tick 0, `End` dociąga do wyniku terminalnego.
- [ ] `End` w wariancie limitu zatrzymuje się na ticku 20, nie na 400.
- [ ] Przewinięcie zatrzymuje automatyczny przebieg i zachowuje wariant oraz tempo.

## Co jest już sprawdzane automatycznie

Poniższych punktów **nie trzeba** weryfikować okiem — pilnują ich testy w `tests/test_main_scene.gd`:

- każda kontrolka HUD mieści się w viewporcie 1280 × 800;
- żadne dwie kontrolki HUD nie nachodzą na siebie;
- plansza i oś czasu nie kolidują ze sobą ani ze słupkiem HUD;
- panel statusu, legenda i event log używają czcionki o stałej szerokości;
- kolumny event logu są wyrównane niezależnie od wyróżnienia wiersza.

Playtest ma więc skupić się na tym, czego geometria nie obejmuje: **kontraście, czytelności kolorów i tym, czy interfejs nie przytłacza**.
