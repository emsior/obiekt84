# MVP L0 — kryteria

## Zakres

Jeden ręcznie skonfigurowany incydent: siatka 20 × 20, jeden strażnik z czterema waypointami, jedna statyczna kamera, jeden intruz na jawnej trasie, tick logiczny 10 Hz, event log, UI ze Startem, Pauzą/Wznów i Restartem.

Konfiguracja incydentu jest danymi w kodzie (`scripts/core/scenario_l0.gd`), nie interaktywnym edytorem.

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

## Stan bieżący (2026-09-21)

Zestaw testów: **58 przypadków, 0 błędów, 0 failures, 0 orphans, exit code 0.**

Incydent kończy się w 38 ticku: strażnik dostrzega intruza w 37 ticku (`SUSPICION`), potwierdza w 38 (`ALARM`), intruz przechodzi w `DETECTED` trzy komórki przed końcem trasy.
