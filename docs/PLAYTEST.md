# Playtest — OBIEKT '84

Ślepy test z osobą spoza projektu. Wyniki zasilają dwa otwarte kryteria z [MVP_L0.md](MVP_L0.md) i arkusz decyzji GO/KILL.
Cel testów: sprawdzić, czy pętla **ustaw patrol i kamerę → uruchom noc → zobacz, gdzie intruz przeszedł → popraw** bawi bez niczego więcej.

Jedna sesja to jeden tester i najwyżej 20 minut. **Nie podpowiadaj i nie tłumacz reguł.** Tester dostaje tylko link i stałe wprowadzenie (trzy zdania, niżej).

---

## Przed sesją (prowadzący, 2 min)

- [ ] Otwórz <https://emsior.github.io/obiekt84/> w świeżej karcie. Plansza i HUD są widoczne, nagłówek brzmi `PLAN OBRONY`.
- [ ] Wpisz niżej commit wdrożenia. Znajdziesz go na github.com/emsior/obiekt84/actions: ostatni zielony przebieg na `main`.
- [ ] Przygotuj stoper. Mierzysz dwa czasy (patrz „Pomiary”).
- [ ] Jeśli testujesz inny wariant zagadki niż domyślny: wariant to podmieniony plik `levels/puzzle_01.json` (bez zmian w kodzie, `README.md`, „Jak dodać poziom”). Zapisz jego nazwę obok commita — wyniki różnych wariantów nie trafiają do jednego wiersza arkusza.
- [ ] Tester korzysta z myszy. Z klawiatury potrzebna jest najwyżej Spacja.

**Tester (inicjały / pseudonim):** __________  **Data:** __________  **Commit:** __________  **Wariant zagadki:** __________  **Prowadzący:** __________

Doświadczenie testera z grami logicznymi / taktycznymi: ☐ żadne ☐ trochę ☐ dużo

---

## Wprowadzenie — powiedz dokładnie to i nic więcej

> „Jesteś szefem ochrony obiektu. Intruz przyjdzie w nocy. Ustaw ochronę tak, żeby go zatrzymać.”

Na pytania o zasady odpowiadaj: „Spróbuj i zobacz, co się stanie.”

---

## Przebieg

Gra trwa do pierwszej wygranej albo 15 minut. Notuj na bieżąco. Po każdej nocy mierz dwa czasy od pojawienia się wyniku: do powrotu do planu (P2a) i do uruchomienia kolejnej nocy (P2b).

| Noc | Zmiana w planie przed nocą | Wynik (`DANE WYKRADZIONE` / `OBIEKT ZABEZPIECZONY`) | P2a: wynik → plan [s] | P2b: wynik → kolejna noc [s] |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |

Więcej nocy dopisz pod tabelą.

---

## Pomiary

**P1. Czas do pierwszego działania.** Od otwarcia strony do pierwszego przeciągnięcia albo kliknięcia na planszy: ______ s

**P2a. Powrót do planu.** Dla każdej przegranej nocy: czas od pojawienia się wyniku do powrotu do fazy PLAN z zachowanym planem. Mierzy tarcie interfejsu, nie namysł.
Mediana: ______ s. **Kryterium MVP „powrót do planu < 20 s”:** mediana P2a < 20 s → ☐ spełnione ☐ niespełnione

**P2b. Od porażki do kolejnej nocy.** Dla każdej przegranej nocy: czas od pojawienia się wyniku do uruchomienia kolejnej nocy — razem z namysłem i przestawianiem planu. Informacyjnie, odpowiada E5 planu nadrzędnego („< 20 s od porażki do kolejnego runu”); nie rozstrzyga kryterium MVP.
Mediana: ______ s

**P3. Ukończenie.** ☐ wygrana bez pomocy ☐ wygrana po podpowiedzi ☐ brak wygranej w 15 min
Liczba nocy do pierwszej wygranej: ______  Czas do pierwszej wygranej: ______ min

**P4. Moment niezrozumienia.** Pierwsze zawahanie albo pierwsze pytanie. Co było wtedy na ekranie i jakie padły słowa?

_______________________________________________________________________

---

## Pytania po sesji (dopiero po zakończeniu gry — wcześniej podpowiadałyby)

**Q1. Co robi kamera?** Zapisz odpowiedź dosłownie: ____________________________________

**Q2. Co robi strażnik?** Zapisz odpowiedź dosłownie: ____________________________________

**Kryterium MVP „gracz rozumie regułę z ekranu”:** obie odpowiedzi zgodne z regułą (kamera **namierza**, strażnik **zatrzymuje**) → ☐ tak ☐ częściowo ☐ nie

**Q3. Dlaczego pierwsza noc skończyła się przegraną?** (tylko jeśli była przegrana) ______________________________________________

**Q4. Jak bardzo podobała Ci się gra? (1–10)** ______

**Q4b. Jak czytelne było, co się stało w nocy? (1–10)** ______

**Q5. Chcesz zagrać w kolejny poziom?** ☐ tak ☐ może ☐ nie — do progu „chce kolejnego poziomu” liczy się wyłącznie „tak”.

**Q6. Co było najbardziej frustrujące?** ______________________________________________

**Q7. Co było najfajniejsze?** ________________________________________________________

---

## Obserwacje prowadzącego

Gdzie skupiał się wzrok — plansza czy panel boczny: ______________________________

Czy linia „zasada: kamera namierza — strażnik zatrzymuje” została zauważona: ☐ tak ☐ nie ☐ nie wiadomo

Czy `NAMIERZONY` przy intruzie albo `MARKED` w panelu zdarzeń zostały zauważone: ☐ tak ☐ nie ☐ nie wiadomo

Czy padło użycie osi czasu albo cofania: ☐ tak ☐ nie

Czy faza nocy nudziła (wzrok gdzie indziej, klikanie „Szybko”): ☐ tak ☐ nie — notatka: ________________

---

# Arkusz zbiorczy — 12 testerów

Jeden wiersz na sesję. Progi pochodzą z kryterium KILL planu nadrzędnego (sekcja 5) i z exit criterion playtestu r1 (tydzień 5).

**Uwaga:** kryterium KILL mówi o ukończeniu **L0–L2**. Dopóki gra ma jedną zagadkę (przed E4), wiersz „Ukończenie” mierzy wyłącznie bieżący poziom i jest przybliżeniem — 8/12 na jednym poziomie **nie** oznacza spełnionego kryterium KILL.

| # | Commit / wariant | Wygrana bez pomocy (P3) | Noce do wygranej | Mediana P2a [s] | Mediana P2b [s] | Rozumie regułę (Q1+Q2) | Satysfakcja 1–10 (Q4) | Czytelność 1–10 (Q4b) | Chce więcej: „tak” (Q5) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | | |
| 2 | | | | | | | | | |
| 3 | | | | | | | | | |
| 4 | | | | | | | | | |
| 5 | | | | | | | | | |
| 6 | | | | | | | | | |
| 7 | | | | | | | | | |
| 8 | | | | | | | | | |
| 9 | | | | | | | | | |
| 10 | | | | | | | | | |
| 11 | | | | | | | | | |
| 12 | | | | | | | | | |

| Próg | Wymaganie | Wynik |
|---|---|---|
| Ukończenie bez pomocy (bieżący poziom — przybliżenie KILL „L0–L2”) | ≥ 8 / 12 | |
| Chce kolejnego poziomu (tylko „tak”) | ≥ 7 / 12 | |
| Mediana satysfakcji | ≥ 7 / 10 | |
| Mediana czytelności (playtest r1) | ≥ 7 / 10 | |
| Powrót do planu (MVP, P2a) | mediana P2a < 20 s u ≥ 8 / 12 | |
| Rozumie regułę z ekranu (MVP) | „tak” u ≥ 8 / 12 | |

Kryteria MVP „powrót do planu < 20 s” i „gracz rozumie regułę z ekranu” zaznacza się w `MVP_L0.md` dopiero na podstawie tego arkusza, nie na podstawie oceny autora.

---

## Co jest sprawdzane automatycznie albo przed wydaniem

Tego nie weryfikuj na sesji:

- geometrię HUD (mieści się w viewporcie, nic nie nachodzi) pilnuje `tests/test_main_scene.gd`;
- determinizm (ten sam plan zawsze daje tę samą noc) pilnują testy rdzenia i golden logi;
- techniczną sprawność buildu Web sprawdza smoke test z `README.md`, sekcja „Build Web lokalnie”, wykonywany przed każdym wydaniem;
- czytelność wizualną (hierarchia nagłówka nad podtytułem, kolory stożków zależne od stanu strażnika, białe obrysy wyróżnienia, znaczniki osi czasu, ocena „czy nie przytłacza”) sprawdza przegląd zrzutów z prawdziwego okna przy każdej zmianie UI — **to nie jest test automatyczny**; testy pilnują logiki (kolor wyniku, lista wyróżnionych komórek, geometria HUD), nie wyglądu.

Sesja ma zmierzyć to, czego testy nie widzą: **czy gracz rozumie, co się stało, i czy chce spróbować jeszcze raz**.

---

## Historia

- **2026-09-22 — pierwszy przebieg okienkowy L0** (12 punktów, D3D12, 1280 × 800). Punkty 1–11 potwierdzone zrzutami, punkt 12 („czy interfejs nie przytłacza”) oceniony przez właściciela: nie przytłacza. Checklista L0 i jej warianty `1`/`2`/`3` zniknęły z UI w L1-A. Pełna treść jest w historii gita tego pliku (przed L1-E).
