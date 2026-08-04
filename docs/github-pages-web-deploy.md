# Godot 4 → GitHub Pages 자동 웹배포 가이드

push할 때마다 Godot 프로젝트를 Web(HTML5)으로 export하고 GitHub Pages에 자동 배포하는 설정. 다른 Godot 프로젝트에도 그대로 복사해서 쓸 수 있다.

## 1. 저장소 준비 (최초 1회, GitHub 웹 UI)

1. GitHub에 빈 저장소 생성 (또는 기존 저장소 사용).
2. **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 변경.
   - 이걸 안 하면 워크플로우의 `deploy` job이 실패한다.

## 2. `export_presets.cfg` (프로젝트 루트)

Godot 에디터에서 Export 프리셋을 만들면 자동 생성되지만, 아래 내용을 그대로 써도 된다.

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

핵심 옵션 2가지:

- **`variant/thread_support=false`** — GitHub Pages는 `SharedArrayBuffer`에 필요한 COOP/COEP 헤더를 기본으로 안 보내준다. 스레드를 쓰는 빌드는 GitHub Pages에서 그냥 안 돌아간다. 게임에 멀티스레딩이 필수가 아니면 반드시 꺼야 한다.
- **`vram_texture_compression/for_desktop`/`for_mobile`=false** — 아래 트러블슈팅 참고. 프로젝트 설정에서 ETC2/ASTC 임포트를 활성화하지 않은 상태로 이 옵션을 켜면 export가 아무 에러 메시지 없이 실패한다. 실제 아트 에셋을 넣고 텍스처 압축이 필요해지면, **프로젝트 설정(Project Settings → Rendering → Textures → VRAM Compression)에서 ETC2/ASTC Import를 먼저 켜고** 이 옵션도 켜면 된다.

## 3. `.github/workflows/deploy-web.yml`

```yaml
name: Deploy Web Build to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

env:
  GODOT_RELEASE: 4.7-stable  # godotengine/godot-builds 릴리스 태그. Godot 버전 바뀌면 여기만 수정.

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Godot and export templates
        run: |
          set -eux
          curl -fL -o godot.zip "https://github.com/godotengine/godot-builds/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
          unzip -q godot.zip
          chmod +x "Godot_v${GODOT_RELEASE}_linux.x86_64"
          GODOT_BIN="$PWD/Godot_v${GODOT_RELEASE}_linux.x86_64"

          curl -fL -o templates.tpz "https://github.com/godotengine/godot-builds/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz"
          RUNTIME_VERSION=$("$GODOT_BIN" --version | sed -E 's/\.official.*//')
          TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/$RUNTIME_VERSION"
          mkdir -p "$TEMPLATES_DIR"
          unzip -q -j templates.tpz -d "$TEMPLATES_DIR"

          echo "GODOT_BIN=$GODOT_BIN" >> "$GITHUB_ENV"

      - name: Export Web build
        run: |
          set -eux
          mkdir -p build/web
          "$GODOT_BIN" --headless --export-release "Web" "$PWD/build/web/index.html" --verbose

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    needs: export
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

**서드파티 export 액션(`firebelley/godot-export` 등)을 안 쓰는 이유**: 내부 로직이 요약되어 로그에 찍히기 때문에, export가 실패해도 원인 파악이 어렵다. 위 방식은 로컬에서 `godot --headless --export-release "Web" ...`로 실행한 것과 완전히 동일한 커맨드라서, 실패하면 원인 메시지가 그대로 CI 로그에 남는다.

다른 프로젝트에 옮길 때 바꿔야 하는 건 **`GODOT_RELEASE` 값 하나뿐**이다 (프로젝트 루트/저장소 이름과 무관하게 동작).

## 4. 트러블슈팅: "Cannot export project with preset due to configuration errors:" (내용 없음)

Godot이 export 실패 이유를 **한 글자도 안 찍고** 이 헤더만 출력하는 경우가 있다. 흔한 "템플릿 없음" 에러는 보통 구체적인 경로까지 같이 출력되므로, 메시지가 완전히 비어있다면 템플릿 문제가 아니다.

**실제 원인 (Godot 4.7 확인됨)**: `EditorExportPlatformWeb::has_valid_project_configuration()` (엔진 소스 `platform/web/export/export_plugin.cpp`)가 아래 조건에서 에러 텍스트를 채우지 않고 `false`만 반환하는 버그가 있음:

```cpp
if (p_preset->get("vram_texture_compression/for_mobile")) {
    if (!ResourceImporterTextureSettings::should_import_etc2_astc()) {
        valid = false;  // r_error는 그대로 빈 문자열
    }
}
```

즉 export 프리셋에서 `vram_texture_compression/for_mobile=true`로 켜놨는데 프로젝트 설정에서 ETC2/ASTC 임포트를 켜지 않았으면, 이 체크가 조용히 export를 막아버린다.

**진단 순서**:
1. `export_presets.cfg`에서 `vram_texture_compression/for_desktop`, `for_mobile` 둘 다 `false`인지 확인. `true`인데 프로젝트 설정에 ETC2/ASTC 임포트가 없으면 이게 원인.
2. 템플릿 문제일 수도 있으니, CI에 아래 디버그 스텝을 임시로 추가해서 실제 설치된 템플릿 파일을 직접 확인:
   ```yaml
   - run: find "$HOME/.local/share/godot/export_templates" -maxdepth 2
   ```
   Web 플랫폼 기준 필요한 파일: `web_nothreads_debug.zip`, `web_nothreads_release.zip` (thread_support=false일 때).
