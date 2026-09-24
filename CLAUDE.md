# Instrukcje trwałe — OBIEKT '84

Te zasady obowiązują w każdej kolejnej sesji pracy nad tym repozytorium.

## Kontekst projektu (scalone z `D:\obiekt84\CLAUDE.md`, 23.09.2026)

- **To repo jest jedynym źródłem prawdy gry:** `E:\OBJEKT\obiekt84`. Stara linia z `D:\obiekt84` (2 commity, własny runner, `sim/`) leży w `D:\_archive\obiekt84_old_v0` — **nie pracować tam, nie scalać stamtąd kodu**.
- Repo zdalne: `github.com/emsior/obiekt84` (publiczne po pierwszym pushu). Push wyłącznie skryptem `D:\_archive\OBIEKT84_SYNC_I_PUSH.ps1`, uruchamianym ręcznie przez właściciela.
- **To 8-tygodniowy test komercyjno-projektowy, nie projekt bez końca.** Bramka GO/KILL: **16.11.2026**. Plan: `PLAN_OBIEKT84_od-konca_v0.md` (projekt „PROCH PC company" / `workspace\Claude outputs\`).
- Priorytet dochodowy właściciela to DaaS Engine (`D:\daas-engine`). Gra jest **drugim torem**. Nie proponuj przenoszenia czasu z DaaS tutaj.
- Stos: **Godot 4.7.2** (`C:\Users\proch\Desktop\Godot_v4.7.2-stable_win64_console.exe`), GDScript, **GdUnit4 6.2.1**. Baza testów 23.09: **107/107** (6 suit, headless).
- Testy z terminala:
  `godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c`

## Marka i OPSEC

- 🚫 **Zakaz nazwiska właściciela** w kodzie, commitach, README i dokumentach. Marka: **Proch PC / PPC**.
- Kontakt i tożsamość gita: **`prochpc@gmail.com`**. Starego prywatnego adresu nie używamy w nowych treściach ani commitach. Historia sprzed 23.09 zostaje bez zmian (decyzja właściciela).
- 🚫 Zero słownictwa hazardowego (art. 110a k.k.s.).
- Git w tym repo: `user.name = PPC`, `user.email = prochpc@gmail.com`.

## Priorytet

Priorytetem jest **działający i deterministyczny L0**, nie architektura pod przyszłe poziomy.

## Rdzeń

- Rdzeń (`scripts/core/`, `scripts/actors/`) musi być testowalny **bez UI**. Testy rdzenia nie wolno uzależniać od sceny.
- **Scene Tree nie jest źródłem prawdy.** Pozycje logiczne, stany FSM, numer ticka, wykrycie, waypointy, trasa, wynik i event log żyją wyłącznie w rdzeniu.
- Klasy domenowe rozszerzają `RefCounted`. Nie tworzą i nie usuwają node'ów, nie używają `SceneTree`, `get_tree()`, `get_node()`, `NodePath`, inputu, Timerów, fizyki Godota ani `await`.
- **Brak logiki zależnej od `delta`.** Zakazane w rdzeniu: `_process`, `_physics_process`, `delta`, `Time`, zegar systemowy, `randomize()`, `randi()`, `randf()`, stan klawiatury i myszy, kolejność callbacków sceny, sygnały jako ukryty mechanizm sterowania kolejnością logiki.
- **Zakaz fizyki Godota w rdzeniu i w FOV.** FOV liczymy całkowitoliczbowo: `dist² ≤ range²`, `dot > 0`, `cross² ≤ dot²`. Bez `Area2D`, `CollisionShape2D`, `RayCast2D`, zapytań do `PhysicsDirectSpaceState2D` i bez `atan2()`.
- **Pozycje logiczne to `Vector2i`.** Kierunki wyłącznie kardynalne. Żadnych floatów jako źródła prawdy dla ruchu, zasięgu ani wykrycia.
- Gdy kolejność iteracji wpływa na wynik, używamy uporządkowanej tablicy albo jawnego sortowania po stabilnym kluczu. Kolejność iteracji `Dictionary` nie jest kontraktem symulacji.
- Kolejność faz ticka jest ustalona i udokumentowana w `docs/ARCHITECTURE.md`. Nie zmieniamy jej bez wpisu w `docs/DECISIONS.md`.

## Prezentacja

- Warstwa prezentacji tylko **czyta snapshot** i woła publiczne API rdzenia. Nigdy nie zapisuje do stanu domenowego.
- Timer prezentacji **nie jest zegarem domenowym**. Jeden timeout to dokładnie jeden jawny `step()`.
- Żadnych node'ów fizycznych w scenach: `Area2D`, `CollisionShape2D`, `CollisionPolygon2D`, `RayCast2D`, `ShapeCast2D`, `CharacterBody2D`, `RigidBody2D`, `StaticBody2D`, `AnimatableBody2D`, `NavigationAgent2D`. Pilnuje tego `tests/test_main_scene.gd`.

## Testy

- **Każda zmiana logiki wymaga uruchomienia testów.** Komenda i wynik — w `README.md`.
- Testy rdzenia nie używają Timerów, FPS, sceny, inputu ani czasu rzeczywistego.
- Orphan nodes to odpowiedzialność testu integracyjnego sceny. Rdzeń nie tworzy node'ów w ogóle.
- Nie zastępujemy GdUnit4 własnym runnerem, GUT-em ani `assert()` ze sceny.

## Zakres

- **Nie dodawać funkcji spoza aktualnego scope.** Poza zakresem pozostają: kampania, roguelite, metaprogresja, generowanie proceduralne, ekonomia, ekwipunek, zapis, limit czasu na planowanie, strefy behawioralne, elementy L2, pathfinding, AStar, NavMesh, dźwięk, animacje, shadery, multiplayer, event bus, ECS, service locator i DI container.
- **L1-A ma interaktywny edytor planowania:** przeciąganie czterech waypointów patrolu (liczba stała) i kamery oraz obrót kamery. Edytor zmienia wyłącznie roboczą kopię `ScenarioL0` w prezentacji; rdzeń dostaje ją przez `initialize()` (`docs/DECISIONS.md`, 2026-09-24). Ściany, LOS, pathfinding, zmienna liczba waypointów, edycja trasy intruza i zasięgów oraz strefy behawioralne **nadal są poza zakresem**.

## Git

- **Nie wykonywać `git push` bez osobnej, jednoznacznej zgody.**
- **Nie wykonywać commita bez komendy `COMMIT`.**
- Nie ignorować `tests/`, `docs/`, `scenes/`, `scripts/`, `addons/gdUnit4/`, `README.md` ani `CLAUDE.md`.

## Zależności

- **Nie zmieniać wersji GdUnit4 bez decyzji zapisanej w `docs/DECISIONS.md`.** Wersja jest przypięta do tagu `v6.2.1`.
- Nie pobierać assetów graficznych ani dźwiękowych. Placeholdery robimy z node'ów Godota i `_draw()`.
