# Zasady pracy w tym repozytorium

Nadrzędne reguły architektury, testowania i zakresu L0 są w [CLAUDE.md](CLAUDE.md).
Ten plik dokumentuje wyłącznie lokalny kontekst i ograniczenia operacyjne.

## Projekt

**OBIEKT '84**, pionowy wycinek L0. Godot 4.x, GDScript.
Rdzeń symulacji jest deterministyczny i oddzielony od Scene Tree — działa i jest
testowalny bez uruchamiania sceny. Framework testów: **GdUnit4**, wersja przypięta
i vendorowana w `addons/gdUnit4/`.

## Git

- **Nie wykonuj `git push`** bez wyraźnej zgody użytkownika.
- **Nie wykonuj commita** bez osobnej komendy `COMMIT`.
- **Nie używaj zbiorczego stagingu** — ani `git add .`, ani wariantów `-A` / `--all`.
- Staging wykonuj **jawnie**, podając nazwę pliku albo nazwę katalogu.
- Przed commitem pokaż `git status --short` oraz listę staged files.
- Nie ignoruj: `tests/`, `docs/`, `scripts/`, `scenes/`, `README.md`, `CLAUDE.md`,
  `addons/gdUnit4/`.

## Walidacja

- Po każdej zmianie logiki **uruchom testy GdUnit4**. Komenda jest w `README.md`.
- Testy rdzenia nie mogą wymagać sceny, Timerów, inputu ani czasu rzeczywistego.
- **Nie zmieniaj wersji GdUnit4** bez wpisu w `docs/DECISIONS.md`.

## Środowisko

- Globalny hook może blokować szerokie komendy stagingu, zanim w ogóle się wykonają.
  To zachowanie oczekiwane, nie awaria.
- Z tego powodu w poleceniach Git używaj **jawnych ścieżek**.
- **Nie próbuj omijać ani wyłączać tego hooka** — także pośrednio, przez łączenie
  komend, skrypty pomocnicze czy pliki wsadowe.
- Jeżeli hook zablokuje uzasadnione działanie, oznacz je jako `BLOCKED`, opisz
  co chciałeś zrobić i dlaczego, i **poproś użytkownika o decyzję**.
