# 풍타디 6.5 — v0.14 완료 보고

부메랑 4~5티어 6개를 실제 코드·Resource·UI·F7에 통합했다. 부메랑은 총 15개 강화를 제공한다.
Godot 4.7.2에서 상시 검사 **7,284개**, 별도 안정성 **656개**가 모두 통과했고, 최종 오류·경고는 **0개**다.

## 보존 범위

시작 HEAD는 `86527ed64bca3bb103245d52dae8a8eb2c2581ca`다. 기존 v0.13/v0.13.1의 미커밋·미추적 작업을 보존했다.
시작 상태는 `test-results/v014-start/`에 저장했다. 기존 벤치마크 236개는 SHA256이 모두 같다.
다트15·폭탄15·부메랑 기존9개 강화 데이터, 20웨이브, 초기400G·목숨50, 스텝 순서와 렌더 캐시를 유지했다.
커밋·push·reset·외부 플러그인·다른 렌더러는 사용하지 않았다.

## 가격과 최종 수치

가격은 해당 티어의 추가 비용이다. 단일 경로의 영구 주력은 피해 / 관통 / 간격 순서다.
Medium 참조 가격과 프로젝트 적용 가격은 아래 값으로 같다. 출처와 패치 충돌은 `BTD6_REFERENCE.md`에 기록했다.

| 강화 | 추가G | 실제 적용 |
| --- | --- | --- |
| 400 M.O.A.R. Glaives | 2,000 | 피해1 / 관통60 / 0.4초, 세라믹+1, 탄속960, 연쇄843.75px |
| 500 Glaive Lord | 32,500 | 주력6 / 60 / 0.4초, 세라믹+10, 재타격0.6초. 회전4(+세라믹4) / 200 / 0.05초, 자체 카모. Shred100/초×10초 |
| 040 Turbo Charge | 4,200 | 영구1 / 4 / 0.15초, MOAB+1. 활성10초: 피해+1 / 0.03초 / 탄속1440. 재사용45초, 최초15초 |
| 050 Perma Charge | 35,000 | 영구4 / 4 / 0.03초, MOAB+2, 탄속1440. 활성15초: 피해+10, 속도 재증폭 없음. 재사용40초, 최초10초 |
| 004 MOAB Press | 2,700 | 일반 Kylie 유지. 독립 특수10초 / 200관통 / 총 MOAB5 / 재타격0.1초 / Press9.375px |
| 005 MOAB Domination | 50,000 | 일반12 / 54 / 0.6초. 특수5초 / 300관통 / 총 MOAB25 / 재타격0.1초 / 기절0.25초 / Press46.875px. 종료 폭발100 / 40 / 반경234.375px, 화상50/초×4초 |

- 502: 주력7피해·세라믹+12, 회전5피해·세라믹+4·NORMAL. 하단1의 회전 반경은187.03125px다.
  회전 외형3개가 피해3회를 만들지 않는다. 주력에는 카모 탐지가 없다.
- 052: 영구8피해·MOAB+2, 활성18피해·MOAB+2다. 250은 활성14피해·MOAB+2다.
  공식 v55의 기본 능력 보너스 +10을 채택해 이전 +8 설명을 그대로 사용하지 않았다.
- 104/204 특수 관통은300/420, 105/205는400/520이다. 상단2의 Press는1.5배다.
  014/024의 특수 간격은8/6초, 015/025는4/3초다. 205 주력 관통81, 폭발 관통50·반경351.5625px다.
- Press 저항은 MOAB/BFB/ZOMG/DDT 외피에서1/0.5/0.25/0.25다. BAD는 피해를 받지만 기절·Press는 받지 않는다.
  004는 BAD를 조준하지 않는다. 특수 공격도 카모 탐지를 별도로 얻지 않으므로 DDT의 카모를 존중한다.
- 탄속·궤도·수명·Lord의 유한 연쇄2000px·005 Press46.875px·015/025 간격은 문서화한 프로젝트 적응값이다.
  미확인 수치를 원작 확정값이라고 주장하지 않는다. 5티어 가격을 현재20웨이브에서 구매하기 쉽게 낮추지 않았다.

## 구현 구조

정적 공격은 Resource, 장전·능력·시각 위상은 TowerState/AbilityState, 지속 피해는 CombatSystem의 희소 ID/family 상태다.
`aura_profile`, `secondary_attack`, `end_explosion`, `damage_over_time`을 추가했다. 외부 폭발 Resource는 명시적으로 복사한 뒤
교차 효과를 합성해 205가 공유 데이터를 바꾸지 않게 했다. 기존 주력36필드와 이전 카탈로그 검사 범위는 유지한다.

회전·DoT 이벤트를 기존 시간순 투사체 큐에 넣고, 기존 격자·정밀 충돌·apply_hit/explode·분열·보상 처리를 재사용한다.
.03초 발사와 .05초 범위 공격은 [시작, 끝) 시간을 누산하며 프레임당 발사 상한을 두지 않았다.
발사 스냅샷·관통·hit_times·자식 제외 이력은 독립적이다. 풍선이나 투사체마다 Node/Timer를 추가하지 않았다.

Shred는 주력 발사당 처음 살아남은 유효 MOAB 외피에 적용한다. 화상과는 별도 family다.
동일 family는 최초 타워·피해·틱 위상을 유지하고 만료 시각만 max로 갱신한다. 여러 Lord의 귀속도 결정론적이다.
외피 Definition+generation 교체·분열·삭제 시 정리하며 자식에게 상속하지 않는다. 각 틱은 현재 카모·속성·출구를 다시 검사한다.
소유 타워가 제거돼도 이미 부착한 피해는 원래 통계 기록에 귀속한다. Pops·보상은 제거한 계층/외피만 집계한다.

Press는 pending_press에 합산하고, 기존 Crush의 pending_push는 max 규칙을 유지한다.
다음 이동 단계에서 둘을 한 번 소비하고 경로거리0으로 제한한다. 현재 배치의 이동 이력은 바꾸지 않는다.
Domination은 편도 종료·수명·관통 소진 중 처음에만 end_emitted로 폭발한다. 기존 생존 외피의 독립 재타격은 의도된 피해이며,
같은 배치에서 태어난 분열 자식은 maxID로 제외한다.

SELF_BUFF는 자신의 transformed_stats만 계산한다. 능력 버튼/A·대기·활성·충전·제거·재시작에 연결했다.
040→050은 남은 지속/대기를 보존하고 새 최대 쿨다운으로 제한한다. 실제 유효 간격으로 장전을 한 번만 환산한다.
004→005도 독립 장전 진행도를 보존한다. 050 Resource의 최초 대기는10초지만 즉시040→050 구매 시 기존15초가 이어진다.
능력 상태는 기존 고정 스텝 경계에서 갱신한다. 기존 영구 간격 최소.05는 보존하고 새050 데이터만.03을 허용한다.

주력 발사·실제 투사체·특수 투사체·범위 이벤트·DoT 틱을 구별했다. 기존 통계 snapshot은 보존하며 새 카운터는 별도로 기록한다.
범위/틱 관통 예산도 계상한다. 통계 요약의 툴팁에서 구별할 수 있고, 통계OFF는 전투 결과를 바꾸지 않는다.

## 교차12개 실제 전투

타워1기(250,350), 혼합120풍선(일반/세라믹/MOAB/BFB/납/DDT, 강화 혼합), 거리420+3i, 12게임초다.
능력이 있으면 충전해 발동했다. 충분한 검사실 자금이며 비용은 기본315G를 포함한다.
각 조합의 1x/2x·통계ON/OFF, 상단4조합의 캐시mode0/3, 실제 버튼 구매·렌더 전투 지문이 일치했다.
새 지문에는 외피 효과·능력·장전·비행중 명중 이력도 포함한다.

| 빌드 | 총G | 실제HP피해 | 주력발사 | 특수탄 | 범위이벤트 | DoT틱 | 잔여개체 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 420 | 3820 | 2697 | 54 | 0 | 0 | 0 | 56 |
| 402 | 3795 | 2917 | 30 | 0 | 0 | 0 | 36 |
| 520 | 36320 | 39412 | 47 | 0 | 240 | 45 | 260 |
| 502 | 36295 | 64855 | 30 | 0 | 240 | 20 | 42 |
| 240 | 6670 | 12350 | 345 | 0 | 0 | 0 | 96 |
| 042 | 6590 | 5459 | 345 | 0 | 0 | 0 | 56 |
| 250 | 41670 | 54883 | 399 | 0 | 0 | 0 | 695 |
| 052 | 41590 | 40618 | 394 | 0 | 0 | 0 | 79 |
| 204 | 5195 | 1054 | 10 | 2 | 0 | 0 | 56 |
| 024 | 5140 | 1060 | 18 | 2 | 0 | 0 | 54 |
| 205 | 55195 | 17677 | 20 | 3 | 3 | 73 | 34 |
| 025 | 55140 | 19840 | 36 | 4 | 4 | 30 | 42 |

누출·잔여 개체도 지문에 포함했다. 이 결과로 정상 자금 빌드의 우열을 단정하지 않는다.
기존 정상 자금5정책은 중단 정책의 wave15패배를 포함해 그대로다. 일반20웨이브는 승리/3423G/목숨50/Pops10338/주력4554발이다.

## 검사와 집계

- 상시 **7,284개 = 로직6,300 + 실제 화면984**, 실패0.
- 기존6,553개 + 신규731개(로직501 + 화면230)다. 기존 검사를 중복 합산하지 않았다.
- 별도 안정성 **656개 = 90게임초 CPU312 + 10게임초 CPU172 + 렌더86 + 렌더계측86**, 실패0.
- 기존150쌍(128CPU/렌더 +16v012 +현재코드6개 후보배제ON/OFF), 추가372개 대조, 48micro·6동시간 전투가 일치했다.
- 추가372는64before/after +256v013 +32before CPU/렌더 +16역사적 단계 +4혼합이다.
  16단계 대조는 보존한 원본을 다시 비교한 것이며 이전 단계 코드를 새로 실행했다고 세지 않는다.
- 교대 반복14대조·CPU/렌더8·캠페인 배속4, 신규 CPU/렌더44쌍·로컬before/after16쌍·Blitz/v012 8대조도 일치했다.
- 성능 프레임과 지문 비교는 상시 검사나 별도656개에 합산하지 않는다.

기존0~3티어 ID·가격·전제·34상태·6교차 기대값을 보존했다. 새 티어 제공에 따라 “3티어가 최종” 검사6개·화면3개,
프리셋 총수61→77만 명시적으로 대체했다. 기존9개 카탈로그는 tier<=3으로 고정하고 새15개와5티어 정책을 별도 검사했다.
F7은 기존0~60을 유지하고61~76에 새16개를 추가했다. 실제 선택·구매·소환·능력/A·충전·제거·재시작을 검사했다.
스크린샷은 `test-results/boomerang-v014-preset-*.png`, `boomerang-v014-crosspath-*.png`에 보존했다.
기존 combat/upgrade-path0~2/crosspath6개와 새 회전·능력·혼합 화면도 직접 확인했다.

최종 `v014-final-check.log`, `v014-complete-verify.log`는 종료0·완료 마커·ERROR0·SCRIPT ERROR0·WARNING0을 확인했다.
`verify.ps1 -Visual -Benchmark`, `-BoomerangTier5Benchmark -ChainBenchmark -ChainStability`를 실제 실행했다.
기계 판독 증거는 `benchmarks/boomerang-v014-validation.json`이다(집계·로그/소스SHA·보존 원본236개SHA·시각QA 목록).

## 성능

Ryzen7 7800X3D / RTX5070 / Godot4.7.2 Compatibility / VSyncOFF다. 타워10기·풍선1000개,
30warmup +120표본×2회=240표본을 합친 평균/nearest-rank P95(ms)다. 필수10종+502 MOAB/Shred 추가 부하를 분리했다.
CPU44행·렌더44행=측정10560프레임이며, CPU는 유지/계측/HUD를 포함하고 렌더는 frame_post_draw 벽시간이다.
중첩 부분 타이머를 합산하거나 헤드리스 시간을 화면FPS라고 보고하지 않는다.

| 부하 | 배속 | CPU 평균/P95 ms | 렌더 평균/P95 ms |
| --- | --- | --- | --- |
| bomb_blitz_mix10 | 1 | 7.419/16.690 | 13.670/25.598 |
| bomb_blitz_mix10 | 2 | 13.846/24.692 | 21.029/34.378 |
| boomerang_000 | 1 | 3.675/5.926 | 7.411/10.604 |
| boomerang_000 | 2 | 8.349/12.592 | 12.249/17.216 |
| boomerang_004 | 1 | 4.263/7.977 | 104.292/126.523 |
| boomerang_004 | 2 | 9.486/21.569 | 108.528/121.072 |
| boomerang_005 | 1 | 6.495/28.505 | 127.208/149.702 |
| boomerang_005 | 2 | 12.107/30.965 | 133.045/152.355 |
| boomerang_040 | 1 | 45.148/96.440 | 52.468/103.896 |
| boomerang_040 | 2 | 68.359/100.342 | 76.128/107.464 |
| boomerang_050 | 1 | 44.764/65.402 | 51.266/70.869 |
| boomerang_050 | 2 | 82.981/98.444 | 89.338/104.927 |
| boomerang_320 | 1 | 4.375/13.295 | 8.404/17.480 |
| boomerang_320 | 2 | 8.594/21.973 | 12.599/26.483 |
| boomerang_420 | 1 | 10.825/47.731 | 15.010/52.623 |
| boomerang_420 | 2 | 24.695/95.711 | 28.997/101.347 |
| boomerang_502 | 1 | 19.147/47.028 | 23.547/50.341 |
| boomerang_502 | 2 | 37.940/91.096 | 42.705/95.953 |
| boomerang_502_moab | 1 | 25.797/76.561 | 153.868/209.578 |
| boomerang_502_moab | 2 | 57.518/188.881 | 193.595/334.089 |
| three_towers_mix | 1 | 7.680/15.508 | 11.504/19.268 |
| three_towers_mix | 2 | 17.079/37.544 | 20.956/42.069 |

현재 로컬320/1000/2x의 before→after는 CPU8.972/22.632→8.594/21.973ms,
렌더12.517/26.267→12.599/26.483ms다. 렌더 평균+0.66%·P95+0.82%의 작은 상승을 기록했다.
큰 회귀는 관측하지 않았으며, 두 번의 실행만으로 통계적 동등성이나 개선을 입증했다고 주장하지 않는다.
전체 기존 행렬의 별도 재측정은 CPU8.485/22.045, 렌더12.640/26.454ms다. 서로 다른 실행의 표본을 섞지 않았다.
기존 v0.13.1의8.618/22.508·12.394/26.414ms는 과거 기록으로 보존한다.

2x CPU 부분 관측: 420의 연쇄 탐색13.719ms, 502의 AoE 후보6.249/정렬4.905/피해7.863ms다.
040의 타워 단계20.579/정밀충돌16.878/큐 정렬11.884ms, 050은31.431/18.870/10.364ms다.
실제 투사체 생성은0.327/0.346ms로 주병목이 아니므로 풀링을 도입하지 않았다.
502 MOAB의 상태 유지/틱 피해는0.021/0.001ms, 005는0.035/0.019ms였다.
관측 효과 수는 평균3.27/9.42·최대10/40이므로 1000개 동시DoT 확장성 검증을 대신하지 않는다.
1us 계측·반올림 이하 값을 비용0으로 해석하지 않는다.

렌더의 풍선draw 관측은004=42.922ms, 005=49.361ms, 502 MOAB=53.678ms다. 기존 비행선 도형fallback 비용이 크다.
렌더 벽시간에는 드라이버/GPU/OS도 포함하므로 부분합과 같지 않다. 기본 풍선atlas 정책은 유지했다.
신규 극단 부하, 특히 활성 고속10기와1000MOAB 렌더는 매끄러운 실시간 성능을 달성하지 못했다.
예를 들어502 MOAB 2x는 렌더 평균193.595/P95 334.089ms, 최대520.966ms다. 정상20웨이브 성능으로 일반화하지 않는다.
이번 작업에서 별도 최적화·충돌 근사·검사 생략·수치 조정은 추가하지 않았다. 후속 후보는 긴 연쇄의 빈 격자 탐색,
반복 목표 획득, 정밀 큐 구성, 비행선 렌더를 각각 측정해 선택하는 것이다.

004/005·추가502는 실제 MOAB1000 유지 지그다. 분열 자식은 다음 유지 단계에서 정리/보충하므로 완전 분열 벤치는 아니다.
세 타워 혼합은 Dart025/Bomb025/Boomerang502 각1기다. 5티어10기는 전용 Registry 용량 예외이며 일반 한기 제한은 그대로다.
원본과 최대·표준편차·2회 평균은 `boomerang-v014-after-*.json`, `summary.json/CSV`,
부분 비용은 `components.json/CSV`에 있다. 생성자는 실제 카운터, auxiliary_order_ids는 예약ID 대리지표이며 힙바이트와 구별한다.

## 원작 차이와 남은 범위

공식 패치와 상세 자료를 대조했으며 원작 실행 파일을 직접 계측한 것은 아니다. 임시 적응값은 위와 BTD6_REFERENCE에 명시했다.
기존 spill_damage·외피 차단을 원작 모든 계층 관통과 동일하다고 주장하지 않는다. 상태·능력은 기존60Hz 스텝 경계를 따른다.
Regrow는 기존 표식만 유지하며 실제 재생은 미구현이다. 5티어는 충분 자금 프리셋에서 검증했고 현재20웨이브 경제에서는 대부분 구매하기 어렵다.
새 풍선·영웅·파라곤·판매·저장은 추가하지 않았다. 성능 한계는 위에 남겼으며 새 수치를 임의로 낮추지 않았다.

## 변경 파일

다음은 git HEAD가 아닌 이번 시작본 대비 목록이다. 이전 미커밋 변경을 이번 작업으로 오인하지 않도록 구분했다.
새 데이터는 강화6개·공격4개·능력2개·효과2개이며, 새 스크립트는 DamageOverTimeDefinition과 테스트/측정 지그다.

| 영역 | 파일 | 상태 |
| --- | --- | --- |
| scripts | scripts/core/balloon_state.gd | 수정 |
| scripts | scripts/core/projectile_state.gd | 수정 |
| scripts | scripts/core/tower_combat_stats.gd | 수정 |
| scripts | scripts/core/tower_stat_resolver.gd | 수정 |
| scripts | scripts/core/tower_state.gd | 수정 |
| scripts | scripts/data/ability_definition.gd | 수정 |
| scripts | scripts/data/attack_spec.gd | 수정 |
| scripts | scripts/data/balloon_definition.gd | 수정 |
| scripts | scripts/data/damage_over_time_definition.gd | 추가 |
| scripts | scripts/data/damage_over_time_definition.gd.uid | 추가 |
| scripts | scripts/data/tower_definition.gd | 수정 |
| scripts | scripts/data/upgrade_definition.gd | 수정 |
| scripts | scripts/developer/tier5_sandbox.gd | 수정 |
| scripts | scripts/systems/ability_system.gd | 수정 |
| scripts | scripts/systems/balloon_system.gd | 수정 |
| scripts | scripts/systems/combat_system.gd | 수정 |
| scripts | scripts/systems/projectile_system.gd | 수정 |
| scripts | scripts/systems/tower_system.gd | 수정 |
| scripts | scripts/systems/upgrade_system.gd | 수정 |
| scripts | scripts/ui/game_hud.gd | 수정 |
| scripts | scripts/ui/tower_stats_panel.gd | 수정 |
| scripts | scripts/ui/tower_upgrade_panel.gd | 수정 |
| data | data/abilities/boomerang_4.tres | 추가 |
| data | data/abilities/boomerang_5.tres | 추가 |
| data | data/attacks/boomerang_special_4.tres | 추가 |
| data | data/attacks/boomerang_special_5.tres | 추가 |
| data | data/attacks/domination_blast.tres | 추가 |
| data | data/attacks/glaive_orbit.tres | 추가 |
| data | data/balloons/bfb.tres | 수정 |
| data | data/balloons/ddt.tres | 수정 |
| data | data/balloons/zomg.tres | 수정 |
| data | data/effects/burn.tres | 추가 |
| data | data/effects/shred.tres | 추가 |
| data | data/towers/boomerang.tres | 수정 |
| data | data/upgrades/boomerang/bottom_4.tres | 추가 |
| data | data/upgrades/boomerang/bottom_5.tres | 추가 |
| data | data/upgrades/boomerang/middle_4.tres | 추가 |
| data | data/upgrades/boomerang/middle_5.tres | 추가 |
| data | data/upgrades/boomerang/top_4.tres | 추가 |
| data | data/upgrades/boomerang/top_5.tres | 추가 |
| tests | tests/analyze_boomerang.gd | 수정 |
| tests | tests/benchmark.gd | 수정 |
| tests | tests/boomerang_benchmark.gd | 수정 |
| tests | tests/boomerang_tests.gd | 수정 |
| tests | tests/boomerang_tier5_benchmark.gd | 추가 |
| tests | tests/boomerang_tier5_benchmark.gd.uid | 추가 |
| tests | tests/boomerang_tier5_tests.gd | 추가 |
| tests | tests/boomerang_tier5_tests.gd.uid | 추가 |
| tests | tests/boomerang_tier5_visual.gd | 추가 |
| tests | tests/boomerang_tier5_visual.gd.uid | 추가 |
| tests | tests/boomerang_v014_before.gd | 추가 |
| tests | tests/boomerang_v014_before.gd.uid | 추가 |
| tests | tests/boomerang_visual.gd | 수정 |
| tests | tests/chain_benchmark.gd | 수정 |
| tests | tests/chain_campaign.gd | 수정 |
| tests | tests/chain_repeat.gd | 수정 |
| tests | tests/chain_stability.gd | 수정 |
| tests | tests/run_boomerang_tier5.gd | 추가 |
| tests | tests/run_boomerang_tier5.gd.uid | 추가 |
| tests | tests/run_tests.gd | 수정 |
| tools | tools/analyze_chain_profiles.ps1 | 수정 |
| tools | tools/compare_boomerang.ps1 | 수정 |
| tools | tools/compare_boomerang_tier5.ps1 | 추가 |
| tools | tools/compare_chain.ps1 | 수정 |
| tools | tools/verify.ps1 | 수정 |

문서8개: GAME_DESIGN.md, ARCHITECTURE.md, TASKS.md, BTD6_REFERENCE.md, BENCHMARKS.md, README.md, AGENTS.md, 신규 V014_REPORT.md.

기존 원본236개·기존 강화/20웨이브 데이터 보존을 확인했다. 커밋과push는 하지 않았다.
