# bloons-td-65

풍타디 6.5: Godot 4 / GDScript 기반의 순수 2D 타워디펜스 프로토타입.
v0.11은 DDT의 복합 면역과 BAD의 이종 분열·상태 효과 면역 정책을 추가합니다.
MOAB·BFB·ZOMG, 강화 상속과 기존 비행선 실험실도 유지합니다.
카모 탐지·외피 HP·하얀/얼룩말/무지개/세라믹과 기존 풍선 검사실도 유지합니다.
울트라 저거너트·플라즈마 팬클럽·석궁의 대가와 맵 전체5티어 제한도 유지합니다.
15개 Resource 강화를 최대 두 경로로 조합합니다. 주력5티어/보조 최대2이며 세 번째 경로는 잠깁니다.
기존20웨이브와 기본/1~3티어 수치는 유지합니다. 원작 재현 범위·출처·차이는 `BTD6_REFERENCE.md`에 기록합니다.

## 실행

1. Godot 4.7.2에서 `project.godot`을 가져옵니다. 외부 플러그인/다운로드는 필요 없습니다.
2. 프로젝트 실행 `F5`로 메인 씬(`scenes/main.tscn`)을 실행합니다.
3. `D`(다트) / `B`(폭탄) 또는 상점 버튼 → 맵 클릭으로 설치 → `Space`로 웨이브를 시작합니다.

시작 자원은 400 G / 목숨 50, 다트는 65 G / 폭탄은 150 G입니다. 우클릭/Esc로 배치를 취소하고,
속도 버튼으로 ×1/×2/×3을 전환할 수 있습니다. 웨이브마다 다시 Space를 눌러 진행합니다.
경로/타워/맵 밖에는 설치할 수 없습니다. 초록/빨강 미리보기로 설치 가능 여부를 표시합니다.
검정은 폭발 면역, 납은 SHARP 면역이므로 두 타워를 혼합하세요. 외피를 파괴하면 각각 분홍/검정 2개로 분열합니다.
다트는 공격력 1 / 관통력 2, 폭탄은 공격력 1 / 유효 대상 12 / 반경 68입니다.
Esc로 배치를 취소하고 설치한 타워를 클릭하면 강화 패널이 열립니다. 세 경로는 관통/연사/고화력이며
3티어에서 큰 다트/삼중 다트/피해2 다트로 달라집니다. 납에는 폭탄 또는 상단4 저거너트가 필요합니다.
2-2-0에서는 주력이 미정이고 어느 쪽이든 3티어로 선택할 수 있습니다. 2-3-0의 삼중 발사는 각 관통 5,
0-3-2는 사거리 200/속도 660, 2-0-3은 피해 2/관통 5입니다. 버튼 아래에서 전후 수치와 잠금 이유를 확인하세요.
빈 맵/패널 ×로 선택을 해제하고 D/B로 설치 모드에 돌아갑니다.
선택한 타워 아래에서 Pops/발사/투자/관통 활용률을 보고, ‘상세’로 전체 통계를 펼칩니다.
20웨이브 종료 시 전체 Pops와 상위 타워를 표시합니다. 기존 기본/1~3티어 수치는 v0.5 그대로입니다.
클리어한 예시 배치와 추가 설치 순서는 `TASKS.md`에 기록했습니다.

상단 `F6 · 4티어 실험` 버튼/F6으로 별도 개발자 모드에 들어갑니다. 기존3티어6조합에서 직접4티어를
구매하거나 저거너트/팬클럽/명사수/완성6조합 탭을 선택합니다. 충분한 개발자 전용 자금으로
타워 클릭→강화, 팬클럽 선택→‘준비 시간 +17초’→능력 버튼→Space로 실제 전투를 확인하세요.
팬클럽은15초간 자신 포함10기를 변신시키며50초 재사용/최초16.67초 대기입니다.
‘경계 도탄 시연’으로 가시 공 반사를 보고, 명사수의10번째 발사 CRIT과 상세 통계도 볼 수 있습니다.
F6으로 시작400G/목숨50의 일반20웨이브로 돌아갑니다. 개발자 모드는 일반 자금/웨이브를 바꾸지 않습니다.

`F7 · 5티어 실험`으로200,000G의 별도 실험실에 들어갑니다. 첫 탭의4티어를 선택해 실제 골드로
5티어를 구매하세요. 같은 종류·주력5티어는 교차 경로와 무관하게 한 개만 가능하며 제거하면 슬롯이 돌아옵니다.
울트라/Plasma20/석궁/혼합 탭은 완성 빌드를 제공합니다. 아래 버튼으로 밀집·고속·납·검정을 소환하고,
팬클럽의 ‘능력 충전’ 후 오른쪽 능력 버튼으로20기 변신을 확인하세요. 일시정지·초기화·선택 제거도 제공합니다.
울트라는105/210 관통 소비 또는 만료 시 최대12소형 공을 방출하고, 석궁은5발마다 CRIT80을 발사합니다.
상세 통계에서 분열탄 수와 치명타 유효 피해를 볼 수 있습니다. F6으로 일반 모드에 복귀합니다.

F7 실험실의 ‘풍선 검사실’을 누르면16종/수량/카모/강화를 선택해 소환할 수 있습니다.
기존10개 풍선 프리셋으로 기본 다트와002의 카모 탐지,402의 카모 납 공격,폭탄의 강화납 공격,
502의 강화세라믹 추가 피해를 비교하세요. 강화는 납/세라믹/비행선에 허용됩니다.
카모는 자식에게 상속되고 강화는 외피 파괴 후 사라집니다. HP가 남은 세라믹은 내부를 생성하지 않습니다.
기존20웨이브에는 신규 풍선이 들어가지 않습니다. 새 그래프의 초과 피해 전달과 기존 캠페인의
분기 중단 호환 정책을 구분하며 자세한 차이는 GAME_DESIGN/BTD6_REFERENCE에 기록합니다.

‘비행선 검사실’에서는 기본 다트·석궁·울트라와 MOAB,Plasma20과 BFB,강화3종/ZOMG 분열을 비교합니다.
소환 후 실제 공격을 보거나 ‘비행선 외피 파괴’를 눌러 현재 비행선만 한 단계 분열시키세요.
강화는 ZOMG→BFB→MOAB→세라믹까지만 상속됩니다. 일반 공격의 비행선 초과 피해는 자식에게 전달되지 않습니다.
타워 선택 패널 위 ‘조준’ 버튼은 First/Last/Close/Strong을 전환합니다. 통계 상세에 MOAB 외피 피해도 표시합니다.
비행선은 기존 일반20웨이브에 들어가지 않으며 기존 타워 수치를 변경하지 않았습니다.

‘DDT·BAD 검사’ 버튼으로14개 신규 프리셋을 엽니다. DDT는 탐지와 Normal/Plasma가 모두 필요합니다.
402·005·탐지 가능한 Plasma로 공격하고,‘카모 제거’ 후 자식의 카모가 되살아나지 않는 것도 확인하세요.
BAD는 기본20000/강화40000HP이며 외피 파괴 시 ZOMG2+DDT3을 생성합니다. 기본 BAD는 카모가 아닙니다.
재생 자식은 분홍 호/표식으로 표시하지만 **실제 재생 동작은 미구현**입니다. 후반 라운드 HP 배율도 적용하지 않습니다.
BAD 넉백 면역,다중5티어 공격,강화·3기 완전 분열을 같은 검사실에서 비교할 수 있습니다. F6은 일반 복귀입니다.

## 검증

PowerShell에서 Godot 실행 파일을 지정합니다. PATH에 등록했다면 `-Godot`을 생략할 수 있습니다.

```powershell
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe'
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual -Benchmark
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Balance -RenderBenchmark
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual -Benchmark -FanBenchmark
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Tier5Benchmark
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual -Benchmark -PropertiesBenchmark
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual -Benchmark -MoabBenchmark
.\tools\verify.ps1 -Godot 'C:\path\to\Godot_console.exe' -Visual -Benchmark -DdtBadBenchmark
```

첫 명령은 임포트, 3,377개 로직 검증, 메인 씬 헤드리스 실행을 수행합니다.
기존 3,048개 검사 범위는 별도 6웨이브 fixture에서 기대값 그대로 유지합니다.
`-Visual`은 실제 렌더러/입력 검사537개를 실행하며, 전체는3,914개입니다.
로그/화면은 `test-results/`에 저장합니다. 신규 화면은 `bloon-properties-v09.png`,
`camo-fortified-ceramic-v09.png`, `fortified-lead-v09.png`입니다.
비행선 화면은 `moab-v010.png`, `bfb-plasma-v010.png`, `fortified-zomg-v010.png`, `zomg-children-v010.png`입니다.
신규 화면은 `ddt-juggernaut-v011.png`, `ddt-regrow-children-v011.png`, `fortified-bad-v011.png`, `bad-mixed-children-v011.png`입니다.
러너는 Godot 사용자 설정을 해당 폴더에 격리하고 오류 로그와 테스트 완료 여부도 검사합니다.
`-Benchmark`는 분산/집중 × 통계 ON/OFF CPU 측정을 `benchmarks/results-v011-*`에 기록합니다.
`-Tier5Benchmark`는 일반20웨이브/Plasma5·20/울트라/기존팬클럽10기의 CPU·렌더·UI 대조를 `tier5-v011-*`에 기록합니다.
`-FanBenchmark`는10기 변신 전후/100·500·1,000풍선/1×·2×의 CPU 및 실제 렌더러 결과를 `fanclub-v011-*`에 기록합니다.
`-PropertiesBenchmark`는 세라믹10/100 동시 파괴·카모강화 혼합·울트라를 `properties-v011-*`에,
일반20웨이브 CPU/렌더 체크포인트를 `tier5-v011-*`에 기록합니다. 두 옵션은 같은 캠페인 파일을 사용합니다.
`-MoabBenchmark`는 실제 비행선 전투/완전 분열/일반 캠페인을 CPU와 실제 렌더러에서 검사하고
`moab-v011-*`에 기록합니다. `-DdtBadBenchmark`는 DDT 물량/Plasma20/BAD 완전 분열/일반 캠페인을
`ddt-bad-v011-*`에 기록합니다. 과거 버전의 원시 결과는 보존합니다.
`-Balance`는 실제 자금 5전략과 500G 상한 단일 타워 80케이스를 `balance-v06.json/csv`로 생성합니다.
`-RenderBenchmark`는 실제 렌더러 프레임 간격을 `render-v06.json`에 기록합니다. 과거 결과는 보존합니다.
성능 결과 해석과 재현 조건은 `BENCHMARKS.md`를 참고하세요.

직접 실행하는 기본 명령은 다음과 같습니다. 새 체크아웃에서는 임포트를 먼저 수행해야 합니다.

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --path .
# 신규 풍선 검사실로 직접 실행:
godot --path . res://scenes/tier5_sandbox.tscn -- --specimen-lab
# 비행선 검사실로 직접 실행:
godot --path . res://scenes/tier5_sandbox.tscn -- --moab-lab
# DDT·BAD 검사실로 직접 실행:
godot --path . res://scenes/tier5_sandbox.tscn -- --ddt-bad-lab
```

## 주요 파일

- `scenes/main.tscn`, `scripts/main.gd`: 실행 씬과 시스템 연결.
- `scripts/systems/`: 풍선, 타워, 투사체, 공통 전투/범위 피해, 웨이브, 경제, 강화 거래.
- `scripts/core/`, `scripts/data/`, `data/`: 개체 상태와 공유 능력치/웨이브 Resource.
- `scripts/world/route.gd`, `scripts/ui/game_hud.gd`: 경로/배치 검사와 UI.
- `tests/`, `tools/verify.ps1`: 로직/화면/입력 검증.
- `GAME_DESIGN.md`: 확정된 규칙과 구조. `TASKS.md`: 현황/제한/다음 후보.
- `ARCHITECTURE.md`: 고정 스텝, 연속 충돌, 공간 격자, 확장 경계.
- `BENCHMARKS.md`, `benchmarks/`: 하드웨어/부하 조건, 평균/p95와 원시 성능 결과.
- `BALANCE_REPORT.md`: 구매/예산/배치 조건, 20웨이브와 빌드별 비교 결과 및 한계.
- `AGENTS.md`: 후속 개발의 코딩 및 검증 규칙.

파라곤, 폭탄 강화, 영웅, 저장, 추가 맵은 이번 단계의 범위에 포함하지 않습니다.
