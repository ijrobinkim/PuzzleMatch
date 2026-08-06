# 조약돌 타일/스페셜 아이템 교체 작업 현황 (2026-08-06)

## 1. 목표

기존 타일 아트(6색 모두 뾰족한 크리스탈/다이아몬드 모양)를 "로얄 킹덤" 스타일(둥글고 광택 있는 3D 토
스톤 재질)의 조약돌 블록으로 교체. 진행 중 요구사항이 한 번 바뀜:

1차: 조약돌 베이스 1개 → 6색 recolor (같은 달걀형 실루엣, 색만 다름)
2차(현재 목표, 진행 중): "로얄 킹덤"처럼 **색상마다 다른 테마 모양**을 쓰도록 변경
   - 빨강 = 방패(shield), 파랑 = 다이아(diamond gem), 초록 = 잎(4잎클로버),
     노랑 = 왕관(crown), 보라 = 성(castle), 주황 = 열쇠(key)
   - 재질/셰이딩 스타일(두꺼운 외곽선, 글로시 하이라이트, 3-4단 톤 셰이딩)은 6개 모두 동일하게 유지

스페셜 아이템(폭탄/로켓H/로켓V/스피너/일렉트로볼)도 같은 조약돌/스톤 재질로 리스킨하기로 함.

## 2. 현재 게임에 실제로 적용된 것 (`assets/sprites/board/`)

| 파일 | 상태 | 비고 |
|---|---|---|
| `tiles.png` | **교체됨 (2차 테마 모양)** | 방패/다이아/잎/왕관/성/열쇠 6종, 전부 agy로 생성 완료. 백업: `tiles.png.bak`(원본 크리스탈), `tiles.png.v1.bak`(1차 달걀형 recolor) |
| `item_rocket_h.png` | **교체됨** (`.bak` 보존) | 조약돌 재질 로켓(오른쪽 방향), agy로 생성 |
| `item_rocket_v.png` | **교체됨** (`.bak` 보존) | 조약돌 재질 로켓(위쪽 방향), agy로 생성 |
| `item_spinner.png` | **교체됨** (`.bak` 보존) | 초록 배경(`prompts/spinner-green.txt`)으로 재생성 성공, 4색 조약돌 날개 스피너 |
| `item_bomb.png` | 미교체 (원본 그대로) | agy 쿼터 소진(429)으로 생성 자체가 계속 안 됨 |
| `item_electro_ball.png` | 미교체 (원본 그대로) | agy 쿼터 소진(429)으로 생성 자체가 계속 안 됨 |

남은 작업은 **폭탄 + 일렉트로볼 2개뿐**. agy 쿼터가 풀리는 대로 아래 6번 명령 그대로 재시도.

## 3. sprite-gen 런 디렉터리

- `assets/generated/sprites/pebble-gem/` — 타일 패밀리, **6종 전부 완료 및 게임 반영 완료**
  - `idle`(회색 베이스, 잠금됨), 구버전 `red/blue/green/yellow/purple/orange`(1차 달걀형, 더 이상 사용 안 함)
  - 2차 테마 모양 6종: `red_shield`, `blue_diamond`, `green_leaf`, `yellow_crown`, `purple_castle`, `orange_key` — 전부 생성·추출·합성·게임 반영 완료 (`green_leaf`만 마젠타 키 사용, 나머지는 초록 키. 요청 파일의 기본 크로마키는 초록으로 되돌려둠)
  - 최종 합성 스트립: `tiles-pebble-v2.png` (768×128, 순서: 방패/다이아/잎/왕관/성/열쇠)
- `assets/generated/sprites/pebble-specials/` — 폭탄/로켓/스피너/일렉트로볼
  - 완료: `rocket_h`, `rocket_v`, `spinner` (전부 게임에 반영됨)
  - **미완료**: `bomb`, `electro_ball` — agy 429로 반복 실패. 프롬프트/레이아웃 가이드는 준비 완료(`prompts/bomb.txt`, `prompts/electro_ball.txt`), 요청 파일 기본 크로마키는 마젠타(둘 다 마젠타로 생성하면 됨, 소재색과 충돌 없음)

## 4. 이미지 생성 provider 이슈

### agy (Antigravity/Gemini)
- 초기엔 정상 작동 (idle 베이스, red/blue/green/yellow/purple/orange, rocket_h/rocket_v 성공)
- 이후 **429 Too Many Requests — 쿼터 소진**으로 중단. `spinner`, `bomb`, `electro_ball` 생성 불가.
- 쿼터 회복 시점 불명 (계정 플랜에 따른 리셋 주기 추정).

### codex 전환 시도
- 사용자가 "이미지 생성은 전부 codex로" 요청 → `npm install -g @openai/codex` 설치(v0.146.1), ChatGPT OAuth 로그인 완료 확인.
- **로컬 스킬 코드 버그 3개 발견 및 수정** (`C:\Users\rapku\.claude\skills\sprite-gen\sprite_gen\gen\codex_provider.py`, 이 머신의 벤더 스킬 사본에 직접 패치):
  1. Windows에서 `codex`는 `codex.cmd`(배치 래퍼)로 설치되는데, 코드가 `subprocess.run(["codex", ...])`를 shell 없이 호출해 `WinError 2`(파일 없음) 발생. → `shutil.which`로 실제 경로를 찾고, `.cmd`/`.bat`이면 `cmd /c`로 감싸서 실행하도록 수정.
  2. `_resolve_rollout()`과 `gen_dir` 계산이 `~/.codex/...`를 하드코딩해서, Orca가 설정하는 `CODEX_HOME` 환경변수(`%APPDATA%\orca\codex-runtime-home\home`)를 무시함 → session id는 맞는데 rollout jsonl을 엉뚱한 경로(빈 기본 `~/.codex`)에서 찾아 실패. `_codex_home()` 헬퍼 추가해서 `CODEX_HOME` 우선 사용하도록 수정.
  3. (2026-08-06 tmux 검증 중 발견) `generate()`의 `subprocess.run(cmd, input=prompt, capture_output=True, text=True, ...)`가 인코딩을 지정하지 않아 Windows 로케일(cp949)로 stdin을 쓰다가 프롬프트에 포함된 유니코드 em-dash(—)에서 `UnicodeEncodeError`로 죽음 → `encoding="utf-8"` 명시로 수정 (`codex_provider.py:192`).
  4. (2026-08-06, agy 경로에서도 동일 증상 재발견) `sprite_gen/gen/__init__.py`의 최종 결과 출력 `print(json.dumps(payload, ensure_ascii=False, indent=2))`도 같은 이유로 크래시(실제 생성은 성공했는데 리포트 출력 단계에서 죽어서 exit 1로 보임) → 출력 직전에 `sys.stdout.reconfigure(encoding="utf-8")` 추가로 수정 (`__init__.py:243` 부근).
- 세 버그 수정 후 codex 실행 자체(로그인, 세션 생성, 프롬프트 전달)는 정상 동작.
- **Orca 래핑 가설은 폐기함** (2026-08-06, tmux로 직접 검증): psmux(tmux) 세션을 새로 열어 Orca를 완전히 배제하고, Orca의 `auth.json`만 복사한 별도의 순정 `CODEX_HOME`에서 `codex exec --sandbox workspace-write --add-dir <gen_dir> ...`를 직접 실행 — 즉 sprite-gen이 실제로 쓰는 것과 동일한 플래그로 codex만 단독 실행. 그런데도 **image_gen 도구가 여전히 세션에 노출되지 않음**. 모델이 스스로 `ALL_TOOLS`를 검색해 확인 후 "현재 세션에는 image_gen 도구가 없어 이미지를 생성할 수 없다"고 답함 (이전에 Orca 하에서 관찰된 것과 동일한 증상). `codex doctor` / `codex login status`로 auth·websocket·sandbox 모두 정상(ChatGPT OAuth 로그인 확인)임을 확인했으므로, 로컬 설정이나 Orca의 세션 래핑 문제가 아니라 **계정/플랜 단위로 image_gen 엔타이틀먼트가 꺼져 있을 가능성**이 가장 유력함. `codex features list`의 `image_generation stable/true`는 클라이언트 빌드 플래그일 뿐이고 실제 계정 권한과는 무관해 보임.
- **다음 확인 필요**: ChatGPT 계정(현재 codex가 물고 있는 OAuth 계정)의 플랜에 이미지 생성(DALL·E/GPT Image) 권한이 있는지 chatgpt.com 설정에서 직접 확인. 안 되면 codex 경로는 막힌 것으로 보고 agy 쿼터 회복을 기다리는 쪽으로 되돌아가야 함.

## 5. 다음에 이어서 할 일 — 폭탄 + 일렉트로볼만 남음

agy 쿼터가 풀리면(또는 codex의 image_gen 계정 권한 문제가 해결되면) 아래만 하면 끝:

```bash
SPRITE_GEN_DIR="/c/Users/rapku/.claude/skills/sprite-gen"
PY="$SPRITE_GEN_DIR/.venv/Scripts/python.exe"
OUTDIR="/e/1111_WORK/000000_Project/RoyalPuzzle/assets/generated/sprites/pebble-specials"

# 1) 생성 (마젠타 키 그대로, 소재색과 충돌 없음)
"$PY" "$SPRITE_GEN_DIR/scripts/generate_sprite_image.py" --provider agy \
  --prompt-file "$OUTDIR/prompts/bomb.txt" --out "$OUTDIR/raw/bomb.png" \
  --ref "$OUTDIR/base-source.png" --ref "$OUTDIR/references/layout-guides/bomb.png" \
  --report "$OUTDIR/raw/bomb.report.json"
"$PY" "$SPRITE_GEN_DIR/scripts/generate_sprite_image.py" --provider agy \
  --prompt-file "$OUTDIR/prompts/electro_ball.txt" --out "$OUTDIR/raw/electro_ball.png" \
  --ref "$OUTDIR/base-source.png" --ref "$OUTDIR/references/layout-guides/electro_ball.png" \
  --report "$OUTDIR/raw/electro_ball.report.json"

# 2) 추출 (요청 파일 기본 크로마키가 이미 마젠타이므로 그대로)
"$PY" "$SPRITE_GEN_DIR/scripts/extract_sprite_row_frames.py" --run-dir "$OUTDIR" --states bomb,electro_ball

# 3) 게임에 반영 (백업 먼저)
BOARD="/e/1111_WORK/000000_Project/RoyalPuzzle/assets/sprites/board"
cp "$BOARD/item_bomb.png" "$BOARD/item_bomb.png.bak"
cp "$BOARD/item_electro_ball.png" "$BOARD/item_electro_ball.png.bak"
cp "$OUTDIR/frames/bomb/frame-0.png" "$BOARD/item_bomb.png"
cp "$OUTDIR/frames/electro_ball/frame-0.png" "$BOARD/item_electro_ball.png"
```

끝나면 Godot 에디터 실행 또는 웹 export로 실제 보드 화면을 렌더링해서 최종 확인.

## 6. 참고 — 색상 매핑 (board_model.gd 기준)

| type index | 색상 | RGB | 새 테마 모양 |
|---|---|---|---|
| 0 | 빨강 | 255,77,77 | 방패 (shield) |
| 1 | 파랑 | 77,153,255 | 다이아 (diamond gem) |
| 2 | 초록 | 77,230,102 | 잎/클로버 (leaf) |
| 3 | 노랑 | 255,230,51 | 왕관 (crown) |
| 4 | 보라 | 204,77,230 | 성 (castle) |
| 5 | 주황 | 255,140,51 | 열쇠 (key) |
