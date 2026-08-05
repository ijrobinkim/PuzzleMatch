# RoyalPuzzle 세션 정리 (2026-08-04 ~ 08-05)

**저장소:** https://github.com/ijrobinkim/PuzzleMatch
**배포 링크:** https://ijrobinkim.github.io/PuzzleMatch/
**엔진:** Godot 4.7 (GL Compatibility 렌더러)

## 1. 기획 & 엔진 선정

- Royal Match/Royal Kingdom 스타일 매치-3 (그리드 매치 + 성 리노베이션 메타) 구상
- 엔진 비교(Unity / **Godot** / LÖVE2D / Defold / Phaser) → 무료·2D 툴링·이 환경의 Godot 스킬 생태계 고려해 Godot 4 선정
- 저작권/상표 리스크 검토: 매치-3 메커니즘 자체는 자유, 아트/사운드/게임명·로고는 독자 제작 필요 (Tetris v. Xio 판례, King사 상표 분쟁 사례 참고)

## 2. 프로젝트 스캐폴딩

- Split 디렉터리 구조(assets/scenes/scripts/resources), 포트레이트 뷰포트(1080×1920)
- 오토로드 4종: `GameManager`, `EventBus`, `AudioManager`, `SaveManager`
- Git 저장소 초기화 → GitHub(`ijrobinkim/PuzzleMatch`) 연결·푸시

## 3. GitHub Actions 웹배포 파이프라인

- Godot Web export 설정 (`variant/thread_support=false` — GitHub Pages가 COOP/COEP 헤더 미지원이라 필수)
- 서드파티 액션(`firebelley/godot-export`) → 로그가 불투명해 디버깅 불가 → **Godot CLI 직접 호출 방식**으로 교체
- 까다로운 버그 하나 해결: `"Cannot export... due to configuration errors:"` 뒤에 아무 내용 없이 실패 — 원인은 `vram_texture_compression/for_mobile=true`가 프로젝트의 ETC2/ASTC 임포트 설정 없이 켜져 있어서 발생한 **Godot 엔진 자체의 에러 메시지 미출력 버그**. 옵션 비활성화로 해결
- 재사용 가능한 가이드 문서 작성 (`docs/github-pages-web-deploy.md`)

## 4. 매치-3 보드 설계 & 구현 계획

- Brainstorming으로 스코프 확정: 드래그+탭 둘 다 지원, 보너스 타일(4매치=줄무늬, 5매치/L자=폭탄)+이동 횟수 제한 포함, 그리드 크기는 설정 가능하게, 아트는 sprite-gen 플레이스홀더
- 아키텍처: **BoardModel**(순수 데이터 클래스, 씬트리 의존 없음 → 유닛테스트 가능) + **BoardView**(Node2D, Tween 애니메이션) 분리
- 설계 스펙(`docs/superpowers/specs/2026-08-04-match3-board-design.md`) + 14개 태스크 구현 계획(`docs/superpowers/plans/2026-08-04-match3-board.md`) 작성

## 5. 구현 (Subagent-driven, Task 1~9)

GUT 테스트 프레임워크 → LevelData → sprite-gen 플레이스홀더 아트(타일 6종+보너스 오버레이 2종) → BoardModel(그리드 초기화 → 매치 판정 → attempt_swap → 캐스케이드/중력/리필/보너스/스코어 → 데드락 감지·재섞기) 순서로 태스크별 구현+리뷰 반복.

**리뷰 과정에서 발견·수정한 실제 버그:**

- `find_matches()`가 빈 칸(EMPTY_TYPE)도 매치로 인식해 무한루프 발생
- 데드락 테스트에 쓴 "체크보드 패턴"이 수학적으로 잘못된 전제(실제로는 항상 유효한 수가 존재함) → 3×3 라틴스퀘어로 교체
- 데드락 시 자동 재섞기가 다른 태스크의 작은 테스트 보드를 우연히 초기화시켜버리는 상호작용 버그

## 6. Task 10~14 + 작업 방식 전환

- Task 10 구현 중 세션 한도 도달 → **Antigravity(agy) CLI**로 이후 작업 전환
- Orca 오케스트레이션으로 agy를 에이전트로 등록 시도 → Orca가 agy를 네이티브로 지원하지 않아 실패(런타임 연결 끊김, 잘못된 워크트리로 연결 등) → agy 권한 설정(`trustedWorkspaces`) 수정 + 실행 가이드 문서 작성 후 사용자가 직접 agy로 진행
- Task 10 리뷰 + Task 11(BoardView 렌더링) + Task 12(드래그/탭 입력) + Task 13(EventBus 연동, 승패 오버레이, 플레이 화면) + Task 14(수동 검증) 전부 완료 → main 머지·배포

## 7. 실기기(모바일) 테스트 & 버그 수정 4라운드

| 증상 | 원인 | 수정 |
|---|---|---|
| 화면 크기 안 맞음, 터치 이상 | `Sprite2D.centered=true` 기본값과 좌상단 기준 좌표계산 불일치 | `centered=false` + `CELL_SIZE`를 스프라이트 원본 크기(128)로 통일 + 보드 화면 중앙 정렬 |
| 매치 성공해도 타일이 실제로 안 바뀜 | 스왑 사실을 View에 알려주는 신호가 없었음 | `swap_committed` 신호 추가, BoardView가 타일 매핑 갱신+애니메이션 |
| 보너스 아이템 아이콘이 칸 밖으로 튀어나옴 | `BonusOverlay`가 모서리 기준으로 회전(45°/90°) | `centered=true`+칸 중심으로 위치 이동해 회전축 보정 |
| 매치 실패 시 한쪽 타일이 원위치 복귀 안 됨 | 복귀 애니메이션 코드에 복붙 실수 (`a→a` 자리에 둘 다 이동) | 각자 원래 자리로 정확히 복귀하도록 수정 |

## 8. 프로젝트 컨벤션 확정

- **배포마다 버전 올리기**: `game_manager.gd`의 `GAME_VERSION`(형식 `0.0.1.x`)을 push마다 증가, 화면 상단에 표시해서 실제 배포 확인용으로 사용

## 9. 이후 사용자가 agy로 직접 확장한 부분 (참고)

세션 후반, 사용자가 agy를 통해 직접 로켓/스피너/폭탄/일렉트로볼 등 다양한 보너스 아이템, 아이템 콤보 시스템, 힌트 표시, 디버그 로그 콘솔, 배포 캐시버스팅 등을 대폭 추가 (버전 `0.0.1.14`까지 진행). 이 부분은 코드 변경 알림으로만 확인됐고 내가 직접 구현한 내용은 아님.

---

총 45개 커밋. 현재 상태: 8x8 매치-3 보드 + 다양한 보너스 아이템/콤보 시스템까지 구현되어 GitHub Pages에서 실기기 플레이 가능.
