# bloons-td-65

풍타디 6.5: Godot 4 / GDScript 기반의 순수 2D 타워디펜스 프로토타입.
v0.2는 빨강·파랑·초록·노랑 풍선, 자유 타워 배치, 관통 다트, 경제와 3개 웨이브를 구현합니다.
다트는 공격력 1 / 관통력 2이며, 피해량과 관통력은 독립적으로 데이터에서 조절합니다.

## 실행

1. Godot 4.7.2에서 `project.godot`을 가져옵니다. 외부 플러그인/다운로드는 필요 없습니다.
2. 프로젝트 실행 `F5`로 메인 씬(`scenes/main.tscn`)을 실행합니다.
3. `D` 또는 타워 버튼 → 맵 클릭으로 설치 → `Space`로 웨이브를 시작합니다.

시작 자원은 200 G / 목숨 20, 다트 타워는 65 G입니다. 우클릭/Esc로 배치를 취소하고,
속도 버튼으로 ×1/×2/×3을 전환할 수 있습니다. 웨이브마다 다시 Space를 눌러 진행합니다.
경로/타워/맵 밖에는 설치할 수 없습니다. 초록/빨강 미리보기로 설치 가능 여부를 표시합니다.

## 검증

PowerShell에서 Godot 실행 파일을 지정합니다. PATH에 등록했다면 `-Godot`을 생략할 수 있습니다.

```powershell
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe'
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual
```

첫 명령은 편집기 임포트, 235개 로직 검증, 메인 씬 헤드리스 실행을 수행합니다.
v0.1 회귀 59개와 관통/계층/경제/연속 충돌/배속 비교 176개를 포함합니다.
`-Visual`은 화면을 잠시 띄워 4색 전투/입력/재시작 18개 항목을 검사하고
`test-results/combat.png`를 생성합니다. 로그도 `test-results/`에서 확인할 수 있습니다.
러너는 Godot 사용자 설정을 해당 폴더에 격리하고 오류 로그와 테스트 완료 여부도 검사합니다.

직접 실행하는 기본 명령은 다음과 같습니다. 새 체크아웃에서는 임포트를 먼저 수행해야 합니다.

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --path .
```

## 주요 파일

- `scenes/main.tscn`, `scripts/main.gd`: 실행 씬과 시스템 연결.
- `scripts/systems/`: 풍선, 타워, 투사체, 웨이브, 경제.
- `scripts/core/`, `scripts/data/`, `data/`: 개체 상태와 공유 능력치/웨이브 Resource.
- `scripts/world/route.gd`, `scripts/ui/game_hud.gd`: 경로/배치 검사와 UI.
- `tests/`, `tools/verify.ps1`: 로직/화면/입력 검증.
- `GAME_DESIGN.md`: 확정된 규칙과 구조. `TASKS.md`: 현황/제한/다음 후보.
- `ARCHITECTURE.md`: 고정 스텝, 연속 충돌, 공간 격자, 확장 경계.
- `AGENTS.md`: 후속 개발의 코딩 및 검증 규칙.

업그레이드, 영웅, 저장, 추가 맵은 이번 단계의 범위에 포함하지 않습니다.
