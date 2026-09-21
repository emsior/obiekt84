# Instrukcje trwałe — OBIEKT '84

Te zasady obowiązują w każdej kolejnej sesji pracy nad tym repozytorium.

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
- Interaktywny edytor planowania (ustawianie kamer i waypointów) **nie należy do tej iteracji**.

## Git

- **Nie wykonywać `git push` bez osobnej, jednoznacznej zgody.**
- **Nie wykonywać commita bez komendy `COMMIT`.**
- Nie ignorować `tests/`, `docs/`, `scenes/`, `scripts/`, `addons/gdUnit4/`, `README.md` ani `CLAUDE.md`.

## Zależności

- **Nie zmieniać wersji GdUnit4 bez decyzji zapisanej w `docs/DECISIONS.md`.** Wersja jest przypięta do tagu `v6.2.1`.
- Nie pobierać assetów graficznych ani dźwiękowych. Placeholdery robimy z node'ów Godota i `_draw()`.
