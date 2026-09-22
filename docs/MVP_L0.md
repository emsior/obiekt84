# MVP L0 — kryteria

## Zakres

Jeden ręcznie skonfigurowany incydent: siatka 20 × 20, jeden strażnik z czterema waypointami, jedna statyczna kamera, jeden intruz na jawnej trasie, tick logiczny 10 Hz, event log.

Wokół tego narosła warstwa prezentacji, której zadaniem jest **pokazać decyzje silnika człowiekowi**: trzy warianty incydentu wybierane z UI, trzy tempa podglądu, wyróżnienie ticków decyzji na planszy i w logu, oś czasu przebiegu oraz przewijanie w obie strony.

Konfiguracja samego incydentu jest nadal danymi w kodzie (`scripts/core/scenario_l0.gd`), nie interaktywnym edytorem. Warianty to te same dane z jednym zmienionym polem, a nie osobne scenariusze.

## Sukces L0

- [x] 50/50 uruchomień headless daje identyczny kanoniczny event log.
- [x] 50/50 uruchomień daje identyczny końcowy snapshot.
- [ ] Tester widzi w UI patrol i wynik incydentu. *(wymaga playtestu z człowiekiem)*
- [ ] Tester potrafi uruchomić, zatrzymać i zresetować poziom. *(wymaga playtestu)*
- [ ] Reset zajmuje mniej niż 20 sekund z perspektywy testera. *(wymaga playtestu; technicznie jest natychmiastowy)*
- [x] Stan po resecie jest identyczny ze stanem początkowym.
- [x] Core działa bez uruchamiania sceny.

Pozycje odhaczone są potwierdzone automatycznymi testami headless. Pozycje nieodhaczone wymagają obecności testera i są przedmiotem [PLAYTEST.md](PLAYTEST.md).

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

## Stan bieżący (2026-09-22)

Zestaw testów: **89 przypadków, 0 błędów, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit code 0.**

Trzy terminalne zakończenia silnika, wszystkie dostępne z UI i wszystkie pokryte golden fixture'em:

| Wariant | Przebieg | Wynik |
|---|---|---|
| Wykrycie | strażnik dostrzega intruza w 37 ticku (`SUSPICION`), potwierdza w 38 (`ALARM`) | `INTRUDER_DETECTED`, tick 38 |
| Sukces intruza | strażnik widzi cel na jeden tick, gubi go i wraca do patrolu | `INTRUDER_SUCCESS`, tick 40 |
| Limit ticków | przebieg urywa się przed jakimkolwiek wykryciem | `TICK_LIMIT`, tick 20 |

**Czego nadal nie wiemy:** warstwa prezentacji nie została ani razu zobaczona na ekranie. Całość powstała i była weryfikowana headless, więc czytelność układu, kolorów i wyróżnień pozostaje niesprawdzona. To jedyna rzecz dzieląca trzy nieodhaczone kryteria sukcesu od zamknięcia.
