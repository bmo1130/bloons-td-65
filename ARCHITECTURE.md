# 전투 구조 — v0.16

## v0.16 주력 범위·독립 운석·회전 연사

직선BLADE의 격자후보도 기존 전체이동점+반경AABB로 보수적으로 배제한다. flight_broadphase_enabled ON/OFF는
정밀상대원검사/시간순큐/ID·자식제외/발수·피해·관통을바꾸지않는다. 새12교차및전체부하280쌍으로동등성을검증한다.

AttackPattern.AREA는 새 데이터 값이다. UpgradeDefinition.primary_attack_pattern(-1=보존)이 선택하고
Resolver는 별도 aura_profile을 복사해 최종 주력 피해/관통/범위/주기/속성/MOAB/카모 값으로 합성한다.
기존36개 스칼라 필드는 고정했다. AREA는 TowerSystem._update_primary_area에서 tower.cooldown만 쓰며
Lord의 보조 aura_cooldown을 소비하지 않는다. 동일한 공통격자/can_target/반개구간 장전→queue_area→explode를 사용한다.
주력 pulse는1volley/1area이며 실제 ProjectileState를 만들지 않는다.8개 장식 불꽃은8회 피해가 아니다.
기존 main의 효과→능력→웨이브→타워→풍선이동→투사체→누수→완료 순서는 그대로다.

운석은 secondary_attack/CHAIN/독립 end_explosion/단일 shell-bound DoT를 재사용한다.
CHAIN에서 목표가 소진돼 종료할 때 end_explosion이 있는 새 프로필만 end_burst를 내며 end_emitted로 중복을 막는다.
기존 Ricochet/Lord는 end_explosion이 없어 ID/큐/판정이 같다. 최초 목표는 First, 이후 기존거리/ID 순이다.
개별공격의 대상/속도/관통/명중·자식제외/피해 스냅샷을 유지하고 직접700/1000,폭발50,화상50을 별도 확인한다.
FIRE는 enum끝에 추가했다. DamageOverTimeDefinition.attribute_override 기본-1은 원타입을 유지하며 새inferno만FIRE다.
새 optional color marker는 그리기 전용이다. 기존 burn/Shred의 타입/우선순위/틱/귀속은 바꾸지 않는다.

AbilityDefinition.RADIAL_BURST가 attack_profile/attack_interval/rotation_turns_per_second를 정의한다.
AbilityState는 active_elapsed/burst_cooldown/burst_phase/bursts_emitted를 별도로 가진다. AbilitySystem.update에서
[시작,끝) 중 실제 활성 구간만 누산하고 위상+생성시각을 fire_volley의 optional phase_degrees로 전달한다.
매 연사에 Resource를 재복제하지 않고 기존launch가 각 실제투사체를 복사한다. 여러 발이 기한이면 전부 발사하며 예산을 두지 않는다.
능력은 transformed_stats를 쓰지 않으므로 주력은 계속 독립 발사한다. 종료/제거 시 새 생성만 멈추며 기발사탄은 유한 수명으로 남는다.
040→050은 이미 사용한 시간을 새 duration에서 차감한다. 남은쿨다운/주기비율/회전위상을 보존한다.일시정지는 main 입구에서 시간을 막는다.

Ability Resource와 attack_profile,secondary의 end_explosion은 명시적으로 복사한 뒤 재귀적 데이터값만 합성한다.
기존54개 강화 리소스를 변경하지 않는다. 통계는 확정된 피해와 원래타워ID에 귀속한다.
ability fire_volley는 실제발사 통계에 포함하지만 tower.attack_counter는 주력만 센다. secondary_projectiles는 독립/능력 투사체다.
area/dot ordering ID와 실제 ProjectileState 생성 수를 구별한다. 진단값과 통계는 전투 판단에 사용하지 않는다.

## v0.15 방사형 공격

TowerDefinition.attack_pattern은 AIMED(기존 기본값)/RADIAL이며 타워ID 조건으로 발사를 분기하지 않는다.
RADIAL은 TowerSystem에서 공통 can_target/격자/사거리로 활성 여부만 찾는다. 방향과 target_mode를 바꾸지 않고
반개구간 잔여 장전시간으로 fire_volley(타워중심,null)를 호출한다. 기존 다트/폭탄/부메랑 장전 코드는 유지한다.
fire_volley는 heading_offset+360*i/count를 사용한다. 기존 launch가 각 ProjectileState/AttackSpec/ID/관통/명중 이력을
독립 생성하고 spawn_fraction을 전달한다. 발사 후 구매·타워 제거에도 복사한 공격/원소유자 통계를 유지한다.

새 projectile_range_multiplier 기본0은 기존 수명 데이터를 보존한다. 압정만1을 설정하고 Resolver 마지막에
최종사거리×배율/최종탄속으로 수명을 산출한다. 기존36개 강화 합성 필드/교차 replacement 규칙은 바꾸지 않는다.
SHATTER enum을 끝에 추가해 기존 비트값을 보존한다. lead 특성과 기존 immunity_mask 판정을 공유하며 카모 탐지는 별도다.
경로 이동→시간순 상대 원 충돌→동일ID/신생자식 제외→CombatSystem 피해/분열/보상/통계 순서는 유지한다.

TACK/BLADE 외형은 _draw에만 있다. 블레이드 회전은 age로 그리며 직선 물리/반경과 분리한다.
압정/칼날은 시각 trail 배열을 만들지 않는다. 기존 RANG/GLAIVE/KYLIE의 최대12위치 trail은 보존한다.
풀링/개체별Node/Timer/근사AoE/충돌 생략을 추가하지 않았다. 기존 profile_updates의 생성/삭제/정밀충돌/격자/그리기
타이머를 새 벤치마크에서 재사용하고, 실제 constructor 횟수와 프로세스 전체 메모리를 구별한다.

## v0.14 독립 공격과 외피 지속 피해

기존 main 스텝 순서는 바꾸지 않았다. TowerSystem의 주력 장전 앞에서 각 타워의secondary_cooldown과
aura_cooldown을 누산한다. .05초 범위 이벤트와 .03초 발사는 [시작,끝) 잔여시간을 소비하며 spawn_fraction을 가진다.
주력·특수탄은 서로 다른 ProjectileState/ID/관통/명중 기록을 사용한다. 특수탄은 주력 volley를 늘리지 않는다.

TowerDefinition/UpgradeDefinition의 aura_profile,secondary_attack,damage_over_time은 정적 Resource 참조다.
선택된 프로필과 외부 end_explosion은 Resolver에서 명시적으로 복사하고 interactions.profiles로 교차 효과를 적용한다.
공유 외부 Resource를 deep duplicate만 믿고 수정하지 않는다. FIELDS36은 기존 주력 스칼라 카탈로그이며 새 프로필은 별도 검증한다.
SELF_BUFF는 AbilitySystem의 새 effect 값이다. self_additions/multipliers/overrides로 transformed_stats를 계산한다.
기존 FAN_TRANSFORM lease와 MOAB_MISSILE,LEAK_STORM 경로는 그대로다. 재사용/지속/최초대기는 게임시간이다.

ProjectileSystem의 기존 시간순 큐에 area/dot 이벤트를 추가했다. 같은 시각에는 공용 증가 ID 순서로 해결한다.
기존 공격에는 새 이벤트가 없으므로 기존 ID/큐 순서가 같다. 모든범위공격은CombatSystem.explode의격자/정렬/관통/maxID/자식제외를쓴다.
회전3개는 TowerSystem._draw의 위상 기반 외형이며 범위 피해는 한 주기에한번이다. 연속폭발이펙트는 생성하지 않는다.
Domination의 end_emitted는 종료조건들이 겹쳐도 한 번만 end_explosion을 처리한다. 독립 폭발은 살아있는 같은 외피를
의도적으로 다시 때릴 수 있지만 현재 배치에 태어난 자식 ID는 제외한다.

CombatSystem.damage_effects는 {ID:{family:스냅샷}}인 희소 상태다. shell_generation과 Definition을 함께 확인해
같은 ID의 외피 교체도 구분한다. 효과는 1초 절대 게임시간 틱을 기존 큐로 예약하며, 긴 스텝 중 부착된 효과의
후속 틱도 남은 큐에 삽입한다. 동일family는 최초소유자/피해/틱위상 유지+만료갱신,Shred와burn은분리다.
제거된 시전자의 통계 기록은 남아 해당 타워로 귀속한다. 모든 확정 피해/분열/보상은 기존 apply_hit/_damage_layers를 통과한다.

pending_press는 기존 pending_push(max)와 별개인 합산값이다. FORCED_MOVEMENT 자격과 정적press_multiplier를 거친
확정 타격만 누적한다. 다음 BalloonSystem.update에서 둘 다 한 번 적용하고 거리0으로 제한한다. 현 스텝의 이동 이력은 불변이다.
BAD는 피해를 받을 수 있지만 STUN/FORCED_MOVEMENT 비트가 제어를 막는다. DOT는 제어비트를 우회하는 피해이며 속성면역은 재검사한다.

통계의 기존 snapshot 스키마는 보존했다. 새 secondary_projectiles/area_events/dot_ticks는 별도 분석 카운터다.
범위/DoT 관통 예산도 계상하되 volley/실제투사체 수로 혼동하지 않는다. 통계 OFF는 전투 상태를 바꾸지 않는다.
부분 타이머는 중첩된다. CombatTrace 상세 진단과 일반 성능 수치를 섞지 않는다.

## 연쇄 탐색의 배치 내부 재사용

ProjectileSystem은 기존 격자와 시간순 큐를 그대로 사용한다. 매 타격의 후보 조회와 전체 자격/거리 반복이
급등 프레임의 주원인이었다. 다음 세 변화만 적용했다. 피해/비행/큐의 구조는 바꾸지 않았다.

1. 한 `update()` 안에서 (접촉 위치,정규화된 시각,연쇄 범위,maxID)가 모두 같으면 기존 후보 배열을 재사용한다.
   단일 캐시 항목이며 키가 달라지면 교체하고 배치 끝에서 후보/거리 그룹/키를 모두 비운다.
2. 첫 조회는 단일 순회다. 같은 키가 두 번째 나타날 때만 각 후보의 정확한 거리 제곱을 계산하고,
   `PackedFloat64Array.sort()`로 서로 다른 거리 키를 정렬한다. 각 거리의 원본 후보 참조는 그룹으로 보관한다.
   가까운 그룹부터 현재 유효한 최소ID를 선택한다. GDScript 비교 콜백이나 투사체별 노드를 만들지 않는다.
3. 처음 보는 질의는 거리/ID가 현재 최선보다 나을 수 있는 후보만 살아 있는지·카모·면역 등을 검사한다.
   유효성이 확인된 후보만 최선 거리를 갱신하므로 가까운 면역 풍선이 먼 유효 대상을 차단하지 않는다.

위 캐시는 위치/거리/격자 후보라는 기하만 보관한다. 생존·현재 외피/카모/속성·명중 기록·출구 시각은 항상
현재 값을 검사한다. 과거 탈락 대상도 그룹에 남겨 동일 시각의 외피 변화/카모 제거 후 다시 선택할 수 있다.
같은 거리의 ID 동률,범위 끝점 포함,생성 maxID,정밀 상대 원 충돌과 이벤트 시간→발사ID→풍선ID는 그대로다.

안전 근거는 기존 이동 이력이 배치 동안 불변이고,단일 계층 반경은 증가하지 않으며,새 자식ID는 배치 maxID를
넘는다는 점이다. 따라서 기존 후보는 유효 대상의 보수적 상위 집합이다. HP/면역/삭제는 목록 재사용을 깨지 않는다.
미래에 즉시 이동/ID재사용이 추가되면 캐시 무효화도 먼저 추가해야 한다. 배치 밖의 직접 질의는 캐시하지 않는다.

`chain_cache_mode`0/1/2/3은 각각 기존 순회/후보 재사용/네이티브 거리 정렬/거리 우선 검사를 비교하는 진단 제어다.
기본3이며 `CombatTrace`는 별도의 null 기본 진단 객체다. 후보/탈락/동적 이벤트/생성 대리 지표와
상세 부분 시간을 기록할 수 있지만 판정·경제·순서는 이 값을 읽지 않는다. 상세 계측의 추가 비용을 별도 표기한다.
실제 전투 지문,동시60접촉의 전체 큐 순서,동일 시각 생존·카모·면역 변경과 캐시 만료를 새 검사로 확인한다.

## 부메랑의 세 비행 규칙

- TowerDefinition.Flight는 STRAIGHT기존값0/CURVE/CHAIN/RETURN이다.비행거리·곡선폭·재타격간격·
  연쇄범위·외형을 스칼라6필드로 확장하고 발사 시 ProjectileState로 복사한다. 특정 타워ID로 비행을 분기하지 않는다.
- ProjectileSystem._prepare_flight가64구간 곡선 또는2구간 왕복의 점 배열을 만든다.
  _flight_trajectory는 실제 통과한 모든 선분을 기존 전역 시간좌표의 start/travel/from/until로 변환한다.
  긴 스텝의 꺾임/전진·귀환 전환도 같은 정밀 상대 원 충돌/시간→투사체ID→풍선ID 큐를 쓴다.
- CHAIN은 지정 ID를 실제로 추적한다. 충돌 확정 후 소비하지 않은 스텝 시간을 돌려놓고 해당 시각부터
  다음 유효 ID로 이동을 계획한다. revision은 오래된 접촉/만료 항목을 제거하며,새 항목은 남은 큐에 이진 삽입한다.
  다음 대상은 기존 공간 격자에서 거리/ID순 한 번 순회로 고른다. 중간 삭제/면역/카모/최대 생성ID도 검사한다.
- RETURN의 hit_times는 발사 후 게임시간이다. 같은 ID의 다음0.3초 자격을 검사하고 겹침이 유지되는 경우도
  다음 합법적인 접촉을 남은 실제 선분에 예약한다. 타격마다 새 제외집합으로 공통 피해기를 부르되,
  생성된 자식ID는 child_ids에 영구 보관한다. 기본hit_ids/저거너트epoch와 서로 다른 정책이다.
- 새 비행 모드의 TowerSystem 장전은 기존 팬클럽의 잔여시간 누산을 재사용한다. 끝 경계는 다음 스텝에
  속하는 반열린 구간이고,발사 시각은 spawn_fraction으로 전달한다. 기존 타워의 분기·주기는 변경하지 않았다.
- 측정 후 추가한 보수적 후보 배제는 기존 격자 rebuild의 이동점 전체+원 반경 AABB를 BalloonState에 저장하고
  곡선/Kylie 선분의 반경 포함 AABB와 교차하지 않는 후보만 제거한다. 정밀 충돌을 근사하지 않는다.
  OFF대조·빠른 풍선의 모퉁이·큰 반경·긴 스텝·왕복/재타격으로 누락이 없는지 검증한다.
- age로 회전하는 외형과 최대12개 end-of-step 위치 trail은 그리기 전용이다. 판정/경제/탐지는 읽지 않는다.
  기본 부메랑V/글레이브3날/두꺼운카일리와 NORMAL의붉은색으로 구분한다. 외부 이미지·노드·타이머는 없다.

기존 다트/폭탄의 직선·도탄·추적 미사일·폭발 분기는 그대로다. 이하 v0.12 설계를 함께 보존한다.

## 폭탄 고티어의 기존 시스템 확장

- TowerDefinition/AttackSpec에 일반·MOAB 기절시간과 경로 넉백거리,파편 추가피해,재귀 주기만 추가했다.
  CombatSystem.can_apply_status는 마스크를 먼저 검사하고 명시적 MOAB 지원 인자가 있을 때만 기존
  일반 넉백 bool을 확장한다. 타입 이름 분기가 없다. 현재 스텝의 충돌 궤적은 불변이며 제어는 다음 이동부터다.
  예측 조준은 기절로 멈추는 시간과 예약된 경로 넉백을 반영하되 개체 상태를 소비하지 않는다.
- BalloonState의 stun_remaining/pending_push는 개체 상태다. 이동에서 초 단위 기절을 소비하고 경로거리를
  차감한다. 상태가0인 대다수 풍선은 감소/최소값 연산을 실행하지 않는다. 이 변경은 계측된 이동 오버헤드만 줄인다.
- AbilityDefinition.Effect에 MOAB_MISSILE/LEAK_STORM을 추가했다. 팬클럽 lease/우선순위/변신 합성은
  기존 코드 그대로다. Missile은 현재 타겟 comparator,같은 launch/이동/정밀충돌/apply_hit를 재사용한다.
  targeted_only 투사체는 보관한 ID만 추적하고 다른 풍선·신규 목표에는 피해를 주지 않는다.
- AbilityState는 동일 타워ID에 하나다. 미사일 업그레이드는 정의만 대체하고 남은 대기를 새 최대치로 제한한다.
  passive도 같은 시뮬레이션 시계로 갱신하지만 activate를 거부하고 UI에서 버튼을 만들지 않는다.
- BalloonSystem.resolve_leaks는 각 살아 있는 ID 제거 직전에 leak_pending을 동기 발행하고 생존 여부를
  다시 검사한다. AbilitySystem은 쿨다운을 예약한 뒤 화면 ID 스냅샷을 공통 피해기로 처리한다.
  출구 분열 자식은 기존 pending queue에 붙고 생존한 자식만 누출한다. 삭제된 부모/자식은 다시 차감하지 않는다.
  기존 효과→능력→웨이브→타워→이동→투사체→누수→완료 순서는 바꾸지 않았다.
- Recursive는 기존 on_explosion descriptor의 bounded secondary ring이다. 발사 시 두 프로필을 복사하고
  TowerState의 성공 volley 카운터로 해당 발사의 recursive flag를 확정한다. 이미 확정한 split_bursts 안에서
  기본8개와 선택적 추가8개만 생성한다. 각각0.14/0.28초 만료가 기존 시간순 큐에서 독립 AoE를 발생시킨다.
  새 노드/타이머/별도 피해 엔진/무한 Resource 그래프는 없다. 발사·피해 통계는 기존 source_id에 귀속한다.
- 공통 업그레이드 패널은 같은 능력 영역에 액티브 버튼 또는 패시브 라벨을 표시한다. HUD 안내 문구는 그
  영역을 사용할 때 숨겨 글자 겹침을 막는다. A는 선택 타워 능력이며 기존D/B/Space/Esc/F6/F7과 충돌하지 않는다.

이하 절은 v0.11.1까지의 설계 기록이다. 새 상한/상태 효과는 위 확장을 따른다.

## 렌더 캐시와 관측 경계

- BalloonSystem은 일반 appearance=0/radius≤20 Definition을 최대64개 보관하는512×512 논리 atlas를
  SVG 도형으로 구성하고2배 크기1024×1024 ImageTexture로 한 번 래스터화한다. 실제 알파 텍스처의
  기본 저장량은 약4MiB다. 같은 공유 텍스처의 영역을 `_draw()`에서 순서대로 제출하므로 풍선 간 겹침 순서를 유지하고
  Compatibility의 텍스처 배칭을 사용할 수 있다. 외부 이미지/플러그인/별도 렌더러/풍선별 노드는 추가하지 않는다.
- 팔레트/크기는 불변 Definition에서 읽는다. 새로운 Definition이 처음 화면에 나타날 때만 atlas를 갱신한다.
  초과 크기/장식/비행선/64개 초과는 기존 도형으로 그리며, 카모·강화·재생의 live 표식은 캐시 뒤에 그대로 덧그린다.
  헤드리스에서는 `_draw()`가 실행되지 않아 텍스처를 만들지 않는다. `use_draw_cache=false`는 검증용 기존 경로다.
- 원래 비용이 컸던 draw_circle 등5개 기본 도형을 풍선당 텍스처 사각형 하나로 대체한다. 이동/격자/충돌/HP/분열/
  공격 스냅샷/명중 기록은 캐시를 읽지 않는다. 캐시가 없거나 래스터화에 실패하면 원래 도형을 사용한다.
- CombatSystem의 선택적 계측은 AoE 후보 구성/정렬/피해와 이펙트 도형 제출을 구분한다. ProjectileSystem의 기존
  생성/정밀 충돌/해결 타이머도 함께 읽는다. 생성 ID 수·후보 Dictionary 수·접촉 시도는 할당의 대리 지표이며
  실제 힙 할당 추적이라고 부르지 않는다. 프로세스 전체 정적 메모리/객체 수의 프레임 후 표본도 별도로 남긴다.
- 판정 순서/제외 ID/정렬/풀링을 바꾸지 않았다. 프로파일링 평균상 주 병목은 렌더이고, 투사체 생성은0.01~0.02ms다.
  임시 접촉 자료구조나 객체 생명주기에 대한 위험한 최적화를 추정만으로 추가하지 않는다.
- bomb_stability_benchmark는 기존 bomb/tier5 부하 지그를 재사용한다. 동일 시각 입력/동일 스냅샷의 전투 지문과
  개별 프레임 표본을 새 v0111 파일에 보존한다. 배속별 부하 측정의 총 시뮬레이션 시간은 다르므로 그 둘의 최종 지문을
  직접 같다고 주장하지 않고,40개 교차/5개 캠페인의 같은 시뮬레이션 시간으로1×/2×를 따로 검사한다.

## 폭탄 1~3티어 확장

- 기존 UpgradeDefinition/TowerStatResolver/UpgradePolicy/UpgradeSystem을 그대로 사용한다.
  새9개 Resource는 data/upgrades/bomb에 두며, TowerDefinition.max_upgrade_tier로 UI의 상한을
  카탈로그에서 읽는다. 업그레이드 경로 이름도 Definition 데이터라 다트/폭탄 UI를 분기 복제하지 않는다.
- ProjectileSplitDefinition에 on_explosion/inherit_damage만 추가했다. 기본false이므로 울트라의
  관통 임계치/수명 종료 방출은 그대로다. 폭탄은 접촉 폭발 시 `_emit_splits`를 한 번 호출하며
  기존 split_bursts를 생성 전에 확정한다. 주 폭탄 수명 종료는 on_explosion을 발동시키지 않는다.
- ProjectileState는 기존 부모/자식 스냅샷에 상단 피해/탐지/탄속을 복사한다. 자식은 원래 source_id와
  split_child=true로 같은 launch API를 사용한다. 통계 ON/OFF는 생성·피해·타겟팅에 관여하지 않는다.
- 클러스터의 TowerDefinition.timed_explosion은 시간순 큐의 만료 이벤트로 CombatSystem.explode를 호출한다.
  퓨즈 전에는 정밀 접촉 후보를 만들지 않으며 별도 타이머·노드·피해 엔진은 없다. 동일 스텝에 생성된
  자식도 spawn_fraction 이후 궤적만 기존 큐에 삽입한다. 전역 max_eligible_id의 새 풍선 제외를 보존한다.
- 독립 파편/폭발은 별도 hit_ids, 동일 AoE는 기존 제외 Dictionary를 쓴다. 이는 의도적인 독립 재타격과
  한 폭발 내 중복을 구분한다. MOAB 보너스는 부모 make_attack에만 있고 자식 프로필에는0이다.
- CombatSystem.can_target은 기본 공격 또는 on_explosion 자식의 피해 속성과 공통 탐지를 검사한다.
  Frag의 검정 조준을 허용하지만 타입 면역은 바꾸지 않는다. 기존 다른 타워는 같은 can_attack 결과다.
- 기존 효과→능력→웨이브→타워→풍선→투사체→누수→완료의 스텝/경제/First 동률은 보존한다.
  bomb_benchmark는 기존 tier5 계측 도구를 상속하여 CPU·실제 렌더·캠페인을 분리하며 기존 원시 파일을 덮지 않는다.

## DDT·BAD의 공통 확장

- 신규 두 Definition도 같은 풍선/격자/투사체/피해 시스템을 사용한다. DDT의 default_camo/immunity_mask/
  lead/moab_class/children_regrow와 BAD의 이종 split_children/status_immunity_mask만 데이터로 추가한다.
- spawn은 live camo 인자와 자식 타입의 default_camo를 OR한다. 일반 BAD의 ZOMG 자식은 기본false,
  DDT 자식은 true다. 카모 제거된 DDT의 live 값은false이고 세라믹 기본도false여서 다시 카모가 생기지 않는다.
  카모 제거를 Definition에 적용하지 않는다. 동일 타입의 다른 개체는 원래 카모로 생성된다.
- BalloonState.regrow는 메타데이터다. 분열은 parent.regrow OR parent.definition.children_regrow를
  넘기고 단일 계층 전환은 같은 ID의 표식을 보존한다. 회복 타이머/최대 재생 계층/복원 동작은 아직 없다.
- Definition.StatusEffect는 일반 효과의 안정된 비트 인덱스다. can_apply_status는 면역 마스크를 검사하고
  기존 넉백 허용 bool도 존중한다. apply_hit는 실제HP가 줄어든 살아 있는 대상에 대해서만 별도로 넉백을 시도한다.
  피해/면역 판정의 can_attack과 효과 자격을 혼동하지 않는다. 새 효과는 이 정책을 사용해야 하며
  특수 예외는 장래 개별 효과의 명시적 기능으로 구현한다. 타입 이름별 if문은 없다.
- BalloonLeakPolicy.damage가 누수의 단일 진입점이다. 현재는 balloon.total_rbe를 그대로 사용하며
  보상/Pops/actualHP와 분리한다. 원작 재현 패치 때 이 정책과 누수 검사를 교체할 수 있다.
- State.speed와 shell_max_hp는 생성된 수치, Definition은 기본 수치다. 이동/예측 조준은 같은 State.speed를
  사용한다. 계층 전환 시 새 타입의 기본 속도로 초기화한다. 라운드 배율/하위 트리 스케일링은 미구현이며
  장래 도입 시 spawn에서 계층별 생성값과 RBE까지 일관되게 확장해야 한다.
- Strong은 기존 comparator에서 새 rank4000/5000만 사용한다. 동률 정책·First/Last/Close는 바꾸지 않았다.
- 검사실은 기존 카탈로그에 타입/프리셋을 추가하고 같은 속성·수량·초기화 UI를 쓴다. DDT 고유 카모를 표시하며
  해제는 spawn 설정을 무시하는 토글 대신 명시적 디버그 decamo 동작으로 분리했다.
- ddt_bad_benchmark는 기존 _live/_complete 계측을 매개변수화해 재사용한다. 기존 기본 인자는 v0.10 지그와 같고
  신규 BAD는13단계/부모 비카모로 시작한다. 생성 수·전체HP·보상·CPU/렌더 지문을 검사한다.
  풍선 제거 타이머는 사전·배열 제거이며, 스냅샷/씬 정리 뒤의 최종 참조 해제까지 측정한다고 보장하지 않는다.

## 비행선과 타겟 정책

- 기존 BalloonDefinition/State/ID 사전/공간 격자/연속 원 충돌을 재사용한다. 비행선별 노드/타이머나
  별도 피해 판정기는 없다. moab_class/strength_rank/blocks_child_damage와 기존 inherit_fortified/
  knockback_allowed가 분류·분열·저항 데이터다. MOAB→Ceramic4/BFB→MOAB4/ZOMG→BFB4다.
- `CombatSystem`의 최초 피해 예산에 moab_bonus를 더한다. 기존 ceramic/fortified/lead와 마찬가지로
  최초 분류만 보고 합산한다. TowerDefinition→make_attack의 발사 스냅샷, Resolver의 정수 필드에 포함한다.
  기존 타워 Resource는 수정하지 않았으며 새 보너스는 기본0이다.
- `blocks_child_damage`는 instance spill_damage보다 우선한다. 실제 HP 제거/보상 후 분열은 그대로 수행하고
  자식 재귀 전달만 중단한다. 다음 자식은 spawn 시 자기 Definition의 spill_damage도 적용하므로
  비행선 단계는 중단하되 세라믹부터 v0.9 일반 그래프 전달 정책을 사용할 수 있다.
- 강화는 부모 Definition.inherit_fortified가 허용할 때만 자식의 허용된 fortified_hp로 초기화한다.
  비행선은 true/세라믹은 false여서 자료 그래프만으로 상속 종료를 표현한다. HP/ID/현재 카모는 상태에 남는다.
- `TowerState.TargetMode`는 인스턴스별 First/Last/Close/Strong이다. `_first_in_range()`라는 기존 호출명은
  호환성을 위해 유지하되 후보를 한 번만 순회하며 `_prefer_target()`으로 선택한다. 정렬/새 전체 탐색은 없다.
  Strong은 명시 rank, 일반 풍선 기본RBE, 같은 분류의 강화/현재HP/First/ID를 비교한다.
  자세한 원작 확인 수준은 BTD6_REFERENCE 참조. 기본 First 결과는 유지한다.
- 비행선의 원형 hitbox만 타워 사거리 경계에 더한다. 격자에는 이미 이동 AABB+반지름이 등록되므로
  중심이 검색 상자 밖인 대형 대상도 조회된다. 일반 풍선의 사거리 획득 규칙은 바꾸지 않는다.
- 현재 넉백은 Definition.knockback_allowed=false로 거부한다. 새 MOAB 전용 상태 효과는 기존 일반 넉백
  수치를 무조건 재사용하지 않고 효과의 지원 분류를 정의하는 후속 작업이 필요하다. 미사용 빙결/기절 코드는 없다.
- 확정 결과 accumulator에 moab_hp를 하나 추가한다. BattleStatistics.moab_damage는 effective_damage의
  부분집합이고 gold_earned는 확정 reward다. Pops/관통 집계는 그대로다. 이름이나 통계 값으로 전투를 분기하지 않는다.
- BalloonSystem.profile_changes는 선택적으로 생성/제거 시간·수·실제 peak 활성 수를 기록한다.
  삭제 시간은 사전/배열 제거 비용이며 살아 있는 참조의 최종 해제/GPU 리소스 비용을 포함한다고 주장하지 않는다.
  전체 메모리 처리 비용은 전투 CPU 시간에 포함된다. 계측을 끈 일반 런에는 시계 호출을 추가하지 않는다.
- `moab_benchmark.gd`는 기존 계측 러너를 재사용한다. 실제 타워 공격과12단계 완전 분열 지그를 구분하며,
  새 자식은 같은 단계에서 제외한다. CPU/렌더 전투 지문과 전체HP/보상을 검사한 뒤 버전별 JSON/CSV를 쓴다.

## 외피 HP와 독립 속성

- BalloonDefinition은 shell_hp/허용 fortified_hp/분열 자식/보상/속도/타입 면역을 보관한다.
  BalloonState는 camo/fortified/shell_max_hp/shell_hp/spill_damage를 보관한다. 강화 variants Resource나
  속성별 새 클래스를 만들지 않는다. 과거 Definition.fortified는 기존 테스트 분류 훅만 남겼다.
- `set_layer()`는 같은 ID의 새 외피 HP를 설정한다. 단일 계층 전환에서도 강화 상속을 데이터로 판정한다.
  `total_rbe()`는 최대 외피HP+자식 트리HP, `remaining_rbe()`는 현재 외피 손상을 차감한다.
  `leak_damage()`는 현재 타입의 전체RBE를 반환하며 손상된 외피도 같은 타입의 전체값을 누수한다.
- `CombatSystem.can_attack()`은 can_detect(개체 카모/공격 탐지)와 can_damage(타입 면역)의 교집합이다.
  타겟팅과 HP 루프 모두 사용하고, 폭탄의 최초 접촉도 can_detect로 걸러 보이지 않는 풍선에서 폭발하지 않는다.
  AttackSpec은 발사 시 detects_camo를 복사한다. 울트라의 자식 프로필도 부모의 탐지 스냅샷을 계승한다.
- `apply_hit()`는 최초 분류의 보너스를 한 번 합산하고 compact Array[int] 하나로
  일반 외피/분기 외피/실제HP/보상/면역 접촉/피해 대상ID 수를 누적한다. `_damage_layers()`는 HP를 먼저 차감하고0에서만 peel한다.
  데이터/인스턴스의 spill_damage가 켜지면 생성 직후 ID 구간의 각 자식에 같은 잔여 피해를 재귀 전달한다.
  전달은 별도 접촉/관통/통계 이벤트를 생성하지 않는다. depth는 콘텐츠 그래프 깊이이며 순환 데이터는 금지한다.
- 루프는 자식마다 면역을 재검사하고 보너스는 재합산하지 않는다. 모든 후손 ID를 원래 공격의 제외 집합에
  넣는다. 같은 배치의 최대ID 제한도 유지한다. 명시적 잔여 피해 전달과 시간순 큐의 독립 재타격을 구분한다.
- 기본7종은 기존 캠페인/fixture의 분기 중단을 유지한다. 신규4종은 데이터에서 spill_damage=true,
  검사실은 기존 종류도 spawn의 spill 인자로 활성화한다. 이후 후손이 같은 정책을 계승한다.
  기존 전투를 다른 판정기로 복제하지 않고 이 정책 비트만 구분한다. 원작 불일치와 통합 경계는 설계 문서 참조.
- `peel_layer()`는 live 카모를 계승하며 허용된 강화만 데이터 inherit_fortified에 따라 계승한다.
  일반 납/세라믹은 강화 비상속이다. 정확히 출구에서 태어난 자식만 pending leaks에 추가한다.
  출구 전 생성은 부모의 미래 exit_time을 물려받아 조기 차감하지 않는다. 나머지 birth-tick 정지 규칙은 유지한다.
- BattleStatistics는 새 actual_hp 인자를 받아 HP-only 접촉도 유효 피해/대상/관통에 포함한다.
  Pops/골드는 실제 외피가 제거된 때만 증가한다. overflow 후손의 피해·보상은 같은 source_id에 한 번 합산한다.
  피해 대상 수는 HP가 실제 줄어든 부모와 후손의 ID 수이고, 관통 소비는 직접 접촉한 부모 하나다.
  단일 ID의 여러 계층 전환은 대상을 중복 집계하지 않는다. 면역 후손의 차단 접촉도 별도로 누적한다.
- profile_changes는 풍선 spawn 수와 중첩 생성 시간을 계측한다. 일반 런은 꺼져 있다.
  외피 파괴/후손 대량 생성은 별도 properties_benchmark에서 확인하며 이전 원시 파일을 덮지 않는다.

## 5티어의 공유 확장

- `Tier5Registry`는 TowerSystem이 소유하는 맵별 RefCounted다. 종류 ID→주력 경로→소유 ID 집합을
  보관한다. 기본 용량1, `limits[kind][path]`로 예외 용량을 제공할 수 있다. 지식 콘텐츠는 없다.
  UpgradeSystem이 정책/자금 검사→새 stats 계산→슬롯 예약→지출→개체 상태 확정 순으로 처리한다.
  같은 ID의 재진입 구매를 차단하고 지출 실패는 예약을 반환한다. 제거/새 맵에서 슬롯을 정리한다.
- `ProjectileSplitDefinition`은 임계 비율/묶음 수/방향/자식 TowerDefinition을 데이터로 정의한다.
  발사 시 부모와 자식 프로필을 복제하고 원래 source_id를 계승한다. 외부 원본 수정에 의존하지 않는다.
  접촉 확정 후 임계치 상태를 먼저 증가시키고 `launch(split_child=true)`로 자식을 생성한다.
  자식의 spawn_fraction을 접촉 전역 시간으로 설정해 해당 스텝의 나머지 궤적만 계산한다.
  새 접촉을 남은 시간순 큐에 이진 삽입하고 배치 시작의 max_balloon_id로 새 풍선 자식을 제외한다.
  종료도 시간순 이벤트로 처리한다. 수명 종료/관통 일괄 소진이 겹쳐도 이미 확정한 묶음을 다시 만들지 않는다.
- 기존 도탄 epoch 기록을 부모/소형 모두 사용한다. 선택적인 사각형 범퍼는 반지름만큼 확장한
  ray/slab 접촉의 법선으로 반사한다. 출구 방향 표면/내부 생성은 재접촉 무한 루프를 만들지 않는다.
  이는 투사체 반사 지오메트리이며 새 맵·길찾기·시야 차단·건설 장애물 시스템은 아니다.
- AttackSpec은 PLASMA 비트를 별도로 지원한다. CombatSystem은 기존 면역 마스크와 최초 접촉의
  lead/ceramic/fortified 보너스로 처리한다. v0.9에서는 실제 세라믹/강화 외피 HP에도 적용한다.
- AbilitySystem의 수혜 상태는 `{leases, definition, remaining}`이다. lease는 시전자ID+능력ID별로
  효과 Resource/남은 시간/발동 serial/본인 예외만 보관한다. 전체 타워 검색은 발동 시에만 한다.
  우선순위와 serial로 승자를 고르고 만료 시 남은 효과를 다시 선택한다. 영구 stats에서 항상 재계산하며
  같은 효과의 최신 발동은 해당 lease만 갱신한다. 상세 중첩 정책은 GAME_DESIGN에 기록한다.
- TowerCombatStats는 분열탄 수/치명타 유효 피해를 추가한다. 분열은 발사 횟수를 늘리지 않고,
  생성 관통 예산을 더한다. 치명타의 명목80과 실제 HP 피해를 혼동하지 않는다.
- UI 미리보기는 타워/영구 stats/유효 stats 참조로 캐시하며 구매·변신·복귀 때 무효화한다.
  자금/슬롯/종료 사유는 매번 다시 판정한다. 공유 Resource 불변 규칙이 캐시의 전제다.
  고정 전투 스텝 안의 HUD 골드/목숨 표시는 마지막 값으로 묶고 스텝 종료/패배 경로에서 즉시 flush한다.
  각 확정 타격의 경제 값과 기존 신호는 그대로 유지한다. 구매/스텝 외 변경은 바로 표시한다.
  UI의 지연은 전투에 관여하지 않는다.
- `profile_updates/profile_simulation/profile_spatial/profile_draw`는 분석 시에만 켜는 계측이다.
  생성은 타워 및 분열 처리에, 후보·정밀 검사는 투사체에, UI는 피해 확정 신호 경로에 포함된다.
  resolution에는 분열 자식 생성/후보 처리가 중첩된다. 부분 타이머를 서로 더해 총 비용으로 해석하지 않는다.
  실제 렌더러의 post_draw 간격과 GDScript draw 명령 비용을 구분한다.

## 4티어 확장과 영구/임시 상태

기존 공간 격자/풍선 ID/계층/경제를 유지한다. 원작 채택 근거와 불일치는 BTD6_REFERENCE.md 참조.

- `UpgradeDefinition.replacement_values`: 해당 필드의 기본값과 같은 경로의 앞선 효과를 교체하고,
  다른 경로의 가산/배율/최종값은 계속 합성한다. 저거너트 기본 간격1초에도 중단 배율이 적용된다.
  그 뒤 데이터의 조건부 interactions 배율→최종값을 적용한다(402 넉백,205 관통21).
  구매 순서/카탈로그 배열 순서와 독립적이다. 5티어 전용 최종값은 기존1~4티어 정의를 변경하지 않는다.
- `TowerState.stats`는 영구 강화값, `transformed_stats`는 수혜 중에만 존재하는 별도 복제본이다.
  `combat_definition()`이 타겟팅·발사·선택 사거리·UI에 같은 유효 수치를 제공한다.
  변신 중 구매 미리보기도 `AbilitySystem.preview()` → `transformed_definition()`을 사용한다.
- `AbilityDefinition`은 ID/효과 종류/초기 대기/지속/재사용/대상 수/변신 프로필 데이터다.
  `AbilityState`는 시전자 ID별 타이머, `AbilitySystem`은 시전자 상태와 수혜 ID별 기간만 관리한다.
  매 프레임 전체 타워를 찾지 않고 활성 상태만 갱신한다. 적격 대상 탐색/정렬은 발동 시에만 한다.
  ID 조회는 수혜 종료/삭제/구매 시의 작은 목록이다. 새 효과는 effect 종류와 적용/종료 처리를 추가한다.
  이번 버전에는 변신만 구현하며 임의 콜백/이벤트 객체 프레임워크는 만들지 않았다.
- 효과는 기간 갱신, 수치는 영구값에서 재계산한다. 시전자 참조를 수혜 상태에 보관하지 않는다.
  타워 삭제는 `TowerSystem.remove_tower()`가 타이머/선택을 정리한다. 통계 레코드는 ID로 보존한다.
- 명사수 `critical_counter`는 통계와 독립된 전투 상태다. 다음 카운터로 critical을 예측해 각 공격을
  스냅샷하고 실제 생성된 발사가 있을 때만 카운터를 확정한다. 나중 카운터가 비행 공격을 바꾸지 않는다.
- 일반 공격의 기존 장전 양자화는 회귀 결과 보존을 위해 유지한다. 변신 공격만 잔여 장전 시간을
  누적해 같은 스텝의 다중 발사를 허용한다. 각 발의 spawn_fraction 이후 이동 구간만 검사한다.
- 공통 CombatSystem은 NORMAL 비트와 데이터 분류(ceramic/fortified/heavy/knockback_allowed)를 사용한다.
  최초 접촉 분류의 보너스를 한 번 합산하고 기존 계층 루프로 제거/면역/분열/보상을 확정한다.
  넉백 상태는 현재 궤적을 바꾸지 않고 다음 이동 단계부터 경로 거리를 감소시킨다.

`ProjectileSystem._trajectory()`는 직진 또는 경계에서 반사하는 구간을 만든다.
구간의 전역 시간 from/until과 풍선 이동 선분의 교집합에서 기존 상대 원형 충돌을 계산한다.
접촉은 시간/투사체ID/풍선ID 순으로 처리한다. 같은 ID는 epoch당 한 번, 총 관통/수명은 회복되지 않는다.
`hit_epochs`는 마지막 타격 epoch, `hit_ids`는 누적 기록, `child_ids`는 영구 자식 제외다.
도탄 상한8(안전 보정≤16)과 다음 경계에서의 제거로 정지 접촉/큰 delta의 무한 반사를 막는다.
사각 범퍼 반사는 v0.8에서 추가했다. v0.9의 외피 HP/분열 트리도 같은 접촉 큐를 사용한다.

스텝은 기존 효과 수명→능력 타이머/만료→웨이브→타워→풍선→투사체→누수→완료 순서를 따른다.
기존 비변신/비도탄 경로의 결과는 유지한다. 벤치마크는 버전별로 따로 저장한다.

## 기존 기반

아래 기반에서 최대 구매 티어는5, 카탈로그는15개이며 영구 강화 위에 앞서 설명한 임시 단계가 추가된다.

## 데이터와 상태

- `BalloonDefinition`: 색상, 반지름, 속도, 해당 겹의 보상, 다음 계층.
  `pink → yellow → green → blue → red → null`은 단일 계층 연결이다.
  검정/납은 `split_children`에 각각 분홍/검정 Resource를 두 번 담는다. 두 표현은 배타적이며 순환하지 않는다.
  `layer_count()`는 외피 수, `total_rbe()`/`leak_damage`는 외피HP+하위 트리HP를 계산한다.
  개체의 강화/부분 손상은 BalloonState에서 별도로 반영한다.
  단일 계층의 충돌 반지름은 아래 계층으로 갈수록 커지지 않는 데이터 규칙을 검증한다.
  `split_children`는 `Array[Resource]`로 저장하고 자식 타입을 테스트한다. 로컬 Godot 4.7.2에서
  자기 클래스를 원소 타입으로 지정한 기본 배열이 종료 시 스크립트를 유지하는 현상을 피하기 위한 선택이다.
- `TowerDefinition`: 비용, 크기, 사거리, 공격 간격, 피해, 관통력, 투사체 속도/반지름/수명.
  공격 속성, 폭발 반경, 색상, 단축키와 강화 목록도 저장한다. v0.4는 그리는 투사체 길이,
  발수, 발사 각도 오프셋, 전체 확산각을 추가한다. 원형 충돌 크기와 시각적 길이는 독립적이다.
- `AttackSpec`: 피해/관통력/속성/폭발 반경의 공격별 값 객체. 발사 때 수치를 복사하므로 이미 날아가는
  공격은 원본 타워 데이터가 바뀌어도 영향을 받지 않는다. source_id는 통계 귀속용이며 판정 조건으로 사용하지 않는다.
- `BalloonState`: 고유 ID, 현재 Definition, 경로 거리/위치, 배열 인덱스, 이번 스텝의 선분별 이동과 시간.
- `TowerState`: 공유 `definition`과 개별 `tiers: PackedInt32Array([0,0,0])`, 계산된 `stats`,
  강화 지출 합계, 쿨다운/방향/위치. 전투/타겟 검색은 stats, 배치 비용/발자국은 definition을 사용한다.
- `ProjectileState`: 발사 시 복사한 공격 수치, 고정 방향, 남은 관통력, 수명, 맞힌 풍선 ID 집합.
  `target_id`는 조준 출처이며 비행/충돌의 필수 참조가 아니다.

## 수동 통계 수집과 캠페인

`MainGame`이 맵별 `BattleStatistics` 하나를 소유한다. `TowerSystem`은 증가하는 ID와
`TowerCombatStats`를 타워 생성 시 등록한다. 레코드는 타워 노드/풍선/투사체를 참조하지 않아 수명 순환이 없다.
강화는 같은 레코드에 비용과 빌드 문자열만 추가한다. 재시작은 새 맵/레코드/ID/획득 골드를 만든다.

`ProjectileSystem.launch()`는 source_id를 공격 스냅샷에 저장하고 생성/관통 예산을 기록한다.
`fire()`/`fire_volley()`는 실제 생성이 있으면 발사 묶음을 한 번 기록한다. 저수준 launch만 직접 호출하면
투사체만 기록하고 발사 묶음은 기록하지 않는다. 게임의 타워는 fire_volley를 사용한다.
`CombatSystem.apply_hit()`는 외피 수/실제HP/면역/피해 대상 수의 확정 결과를
`record_hit()`에 전달한다. AoE도 같은 진입점을 통과한다. 통계 결과를 읽어 피해/관통/보상을 결정하는 분기는 없다.
추가 타겟 검색이나 명중별 이벤트 객체 할당은 없다. 레코드 조회는 ID 사전이다.
소스 0은 비귀속 디버그 공격으로 전체 타워 Pops에서 제외한다. 게임의 모든 정상 타워 공격에는 등록 ID가 있다.
지원/상태이상/영웅을 추가할 때 같은 source_id로 확정 결과를 전달할 수 있지만 해당 기능은 아직 구현하지 않았다.

발사 예산과 명중 누적을 비교하는 통계이므로 ON/OFF는 런 시작에 선택한다. 비활성 상태에서도 등록/투자 정보는
유지하되 전투 카운터만 끈다. 운영 UI에는 중간 토글을 제공하지 않는다. OFF에서도 동일 전투 결과를 검증한다.
`GameEconomy.total_earned`는 실제 earn만 기록하며 시작 자금과 구매 지출은 포함하지 않는다.
결과 순위만 종료 시 정렬하고, 선택 통계 UI는 선택한 한 레코드를 0.2초마다 읽는다. 구매 직후에는 즉시 갱신한다.

일반 메인 씬에는 새 campaign/20개 WaveDefinition을 연결했다. 기존 6개 원본 Resource는 수정하지 않았고,
상속 씬 `tests/fixtures/v05_main.tscn`의 regression_six_waves 플래그가 고정 목록을 선택한다.
기존 검사는 씬 경로만 이 fixture로 바꿨으며 기대값/검사 수/구매 순서/웨이브 규칙은 바꾸지 않았다.
일반 재시작은 20웨이브, fixture 재시작은 6웨이브다. 기존 v02_config는 3웨이브/초기 자원까지 추가로 고정한다.

`tests/scenarios/balance_scenarios.gd`는 실제 가격의 쇼핑/배치와 500 G 상한 단일 타워 실험을 공유한다.
일반 실행과 독립된 `tests/analyze_balance.gd`가 JSON/CSV를 생성한다. 표준/집중 CPU 벤치의 ON/OFF와
실제 렌더러 프레임 측정은 별도 진입점이며 기존 v0.5 결과를 덮지 않는다.

Resource는 실행 중 변경하지 않는다. 피격 시 풍선 상태가 참조하는 계층만 교체한다.
`CombatSystem.apply_hit()`는 속성 면역을 각 계층마다 검사하고 실제 감소HP를 반환한다.
기존1HP 콘텐츠에서는 제거한 겹 수와 같으며 신규 두꺼운 외피에서는 다르다.
`BalloonSystem.damage()`는 과거 테스트를 위한 SHARP 기본값의 호환 진입점이며 같은 판정기를 호출한다.
계층 제거/분열의 상태 변경은 `BalloonSystem.peel_layer()`가 담당하고 보상 합계는 CombatSystem이 한 번 알린다.
풍선 삭제/계층 전환을 마친 뒤 신호를 내보내므로 경제 UI 갱신이 중간 상태를 관찰하지 않는다.

## 고정 스텝

`MainGame._process()`는 벽시계 시간을 배속한 뒤 1/60초 스텝을 반복한다.
창 이동 등에 따른 프레임 지연은 프레임당 최대 0.25초만 따라잡는다.

1. 효과 시간 갱신, 웨이브 소환.
2. 스텝 시작 위치에서 타워 조준/발사. 기본은 First이며 인스턴스의 선택 정책을 공통 탐색에 적용한다.
3. 풍선 이동. 경로 모퉁이를 각각의 선분으로 기록하며 출구 도달 시점도 정규화된 시간으로 저장한다.
4. 투사체 이동과 충돌/타격. 풍선과 투사체의 이동은 동일한 시간 구간에 대응한다.
   폭탄은 접촉점에서 공통 범위 피해를 호출하고 제거된다.
5. 출구까지 살아남은 현재 풍선 타입의 전체RBE를 목숨에서 차감. 파괴된 부모는 차감하지 않는다.
6. 패배하지 않았다면 웨이브 완료와 승리 검사.

계층/반지름은 타격 즉시 바뀐다. 현재 스텝의 이동은 이미 계산한 궤적을 유지하며
새 계층의 속도는 다음 이동 스텝에 적용한다. 누수는 이동 단계에서 곧바로 삭제하지 않아
기존 다트가 출구 도달 전에 맞힌 타격을 반영할 수 있다.
분열한 자식은 접촉 시점의 거리/위치로 태어나며 남은 현재 스텝은 이동하지 않는다.
부모의 대기 누수는 ID가 사라져 무효화된다. 정확히 출구에서 생성한 자식은 현재 스텝에서 누수하고,
그 전의 자식은 다음 이동 스텝부터 독립적으로 누수할 수 있다.

단독 이동 검증용 `BalloonSystem.update(delta)`는 기본적으로 즉시 누수를 처리한다.
게임 조율자는 `update(delta, true)`와 `resolve_leaks()`를 같은 스텝에서 짝으로 호출한다.

## 충돌과 삭제

- 64 px 공간 격자는 풍선의 이번 이동 경계 상자를 반지름만큼 확장해 등록한다.
  이동/소환 시 캐시를 무효화하고 첫 조회에 재구축한다. 타워와 모든 다트가 캐시를 공유한다.
- 다트의 이동 경계 상자와 겹치는 격자만 조회하고, 셀 여러 개에 있는 ID를 중복 제거한다.
- 정밀 검사는 풍선 선분별 상대 속도로 원 진입 시점을 구한다. 끝 위치만 검사하지 않아
  고속 이동과 경로 모퉁이의 누락/가짜 대각선 충돌을 피한다.
- 수명으로 이동 구간을 자르고 출구 도달 후의 타격을 제외한다. 관통력 소진 시 위치는 마지막 접촉점이다.
- 전체 접촉 후보를 시간 → 다트 ID → 풍선 ID로 정렬한다. 반지름이 앞선 타격으로 줄었으면
  접촉 시점을 다시 계산해 남은 후보 목록의 올바른 위치에 넣는다.
- 피해 직전에 ID가 살아 있는지 확인한다. 이미 삭제됐으면 관통력을 소비하지 않고 다음 후보로 진행한다.
- 타격 전에 다트의 `hit_ids`에 ID를 기록한다. 계층이 바뀌거나 계속 겹쳐도 같은 다트가 재타격하지 않는다.
  공통 판정기 역시 전달된 제외 ID 집합을 검사한다. 면역 접촉도 기록하지만 관통력은 소비하지 않는다.
- 투사체 처리 시작의 최대 풍선 ID로 폭발 후보를 제한한다. 같은 묶음 중 새로 분열한 자식은 어느 폭발에도
  다시 맞지 않는다. 직접 생성한 자식 ID도 원본 투사체의 제외 집합에 넣는다.
- 풍선 배열은 마지막 원소 교환으로 삭제한다. 순서에 의존하는 판정은 모두 진행도/시간/ID를 사용한다.
  격자에 잠시 남은 참조도 ID 조회에서 걸러진다. 투사체는 타격 처리 후 역순으로 제거한다.

격자 구축은 풍선 수에 비례하며 각 다트는 주변 후보만 정밀 검사한다. 모든 풍선이 한곳에 몰리면
그 지역의 후보 수만큼 비용이 든다. 풀링이나 추가 인덱스는 실제 대규모 프로파일링 후 검토한다.

## 확장 경계

`fire(position, target, definition)`는 단일 조준 발사 호환 API다. 타워는 `fire_volley()`로 예측 조준을
한 번 계산한 뒤 데이터의 발수/각도/확산에 따라 `launch()`를 반복 호출한다. 발수 1은 기존 결과와 같다.
각 발사는 독립 ID/AttackSpec/관통력/명중 집합과 크기·속도·길이의 스냅샷이다.
큰 다트도 동일한 공간 격자 + 원형 상대 이동 충돌을 사용한다. 경계 상자를 투사체 반경만큼 확장하므로
중심 궤적 밖의 풍선을 놓치지 않는다. 무한 관통은 이후 관통 소비 정책에 추가할 수 있다.
범위 공격은 `CombatSystem.explode(center, attack, time, max_id, excluded)`를 공유한다.
기존 공간 격자로 넓은 후보를 조회한 뒤 접촉 시각의 중심 좌표로 반경 검사를 한다.
후보 ID/거리를 피해 전에 고정하고 거리/ID 순서로 처리한다. 면역·삭제 대상은 예산을 소비하지 않는다.
직접 맞은 대상에 별도 피해를 주지 않는다. 속성과 폭발 반경이 분리되어 SHARP 범위 공격도 같은 API로 검증된다.

면역은 `BalloonDefinition.immunity_mask`와 `AttackSpec.Attribute`의 비트로 판정한다. 새 속성은 enum과 데이터
표시 목록을 확장하면 되며 타워별 이름 조건문은 없다. 타워의 복수 공격은 각각 별도 AttackSpec을 만들 수 있는
형태다. v0.7 추가 피해/넉백은 위의 공통 명중 단계에서 처리한다.
범용 효과 프레임워크와 지원 면역 무시는 도입하지 않는다.

## 강화 데이터, 계산, 거래

- `UpgradeDefinition`: 고유 ID, 경로 0~2, 티어 1~5, 가격, 이름/설명, 선행 ID 목록,
  수치 가산/배율/최종값 사전과 시각적 색상. `data/towers/dart.tres`의 15개 하위 Resource가 실제 구현이다.
  타워 스크립트에는 개별 강화 ID/다트 이름별 분기가 없다. 폭탄도 빈 목록을 가진 같은 TowerDefinition이다.
- `TowerStatResolver.acquired()`: 카탈로그의 배열 순서와 무관하게 경로 상→중→하, 각 티어 오름차순으로
  구매한 효과를 수집한다. `upgrade_at()`은 경로와 티어로 정의를 찾는다.
- `resolve()`: 공유 기본 Definition을 복제하고 지원하는 수치 필드마다 `(기본 + 가산 합) × 배율 곱`을 계산한다.
  이후 위 순서에서 마지막으로 지정된 override가 우선한다. 색상은 가장 높은 티어가 우선하고 동률은 같은 순서를 따른다.
  정수 필드는 반올림하며 피해/관통 ≥1, 영구 간격 ≥0.05, 발수 1~32 등 안전 범위로 보정한다.
  계산은 생성/구매 시에만 수행한다. 이전 stats를 입력으로 재사용하지 않아 반복 계산의 누적 오차가 없다.
- 수치 외의 재사용 공격 방식은 `projectile_count`, `spread_degrees`, `heading_offset_degrees`,
  `attack_attribute`, `explosion_radius` 같은 최종값으로 표현한다. 새 수치 효과에는 데이터만 추가하면 된다.
  완전히 새로운 메커니즘에는 재사용 가능한 코드가 필요하며 임의 스크립트 실행 프레임워크는 만들지 않는다.
- `UpgradePolicy.state_reason()`: 3원소/범위, 투자 경로 ≤2, 티어 3 이상 경로 ≤1을 검사한다.
  `main_path()`는 현재 tiers에서 도출하며 별도 주력 선택 상태/구매 순서를 저장하지 않는다.
  `reason()`은 원본 상태와 후보 상태 모두 검사하고 정확한 이전 티어/선행 ID/소속/비용을 추가로 검사한다.
  2-2-0에서 주력은 -1이며 두 경로 모두 3티어 후보가 된다. 실제 구매의 최대는 AVAILABLE_TIER=5이다.
- `UpgradeSystem.purchase()`: 실제 맵 타워 소속/종료/정책/골드를 검사한 뒤 비용을 한 번 지불하고 티어와 stats를
  갱신한다. `error_for()`가 정책/자금을, `error_for_path()`가 다음 정의 유무/구현 상한을 함께 표시한다.
  UI와 거래가 이 공통 결과를 사용한다. 표시한 Resource 자체를 요청하므로 오래된 버튼/중복 요청은 다음 티어를 잘못 구매하지 않는다.
  실패하면 골드/티어/쿨다운을 바꾸지 않는다. 성공 시 장전 잔여 비율을 새 간격으로 환산하고 upgraded 신호를 낸다.

향후 효과 합성 순서는 **기본 → 구매 강화(가산·배율·최종값) → 별도 런타임 버프/디버프 → 최종 보정**으로
확장한다. 런타임 버프는 아직 없다. 현재 안전 보정을 마지막 단계로 옮겨 버프 전용 단계를 삽입하면 되며
원본과 구매 tiers를 바꾸지 않는다. 교차 경로의 override 충돌은 현재 경로/티어 순서가 결정하지만,
실제 데이터 추가 시 충돌 속성의 의도와 우선순위를 따로 검증해야 한다.

v0.5의 다트 효과에는 수치 override 충돌이 없다. 상단은 관통 가산/큰 반경·길이,
중단은 간격 배율/발수·확산, 하단은 사거리·속도 가산/피해·길이이므로 합법적 두 경로의 모든 효과가 합성된다.
상단3/하단3의 길이 충돌은 두 주력 금지 규칙상 발생하지 않는다. 조합별 공격 분기나 합성 순서별 상태는 없다.
UI 미리보기 `TowerStatResolver.preview()`는 tiers를 복사해 한 좌표를 바꾸고 동일 resolve를 호출한다.
실제 구매도 이 함수의 결과를 적용한다. 기본값/구매 상태/이미 비행 중인 AttackSpec은 미리보기로 변하지 않는다.

주력 최대5/보조 하나 최대2는 공통 UpgradePolicy의 FINAL_TIER/AVAILABLE_TIER=5로 검사한다.
v0.8은 상한5와 종류 ID+경로 기준 맵 레지스트리를 함께 제공한다. 구매 시 다시 검사하고 예약한다.
향후 5티어 용량 변경은 공통 Registry에 적용하고 기존 개체를 자동 삭제하지 않는다.
골드 차감 전에 유일성을 예약하고 삭제/재시작에서 정리한다. 실제 판매 기능은 없으며 실험실 제거는 환급하지 않는다.

## UI와 측정

상점은 `MainGame.TOWER_CATALOG`에서 버튼을 생성하는 스크롤 목록이다. 타워 선택/단축키/미리보기/비용 검사는
선택한 Definition을 사용한다. 새 타워를 위해 HUD에 개별 이름 조건문이나 새 고정 패널을 추가할 필요가 없다.

설치용 `MainGame.selected_tower`와 맵 인스턴스 `selected_instance`를 분리한다. 설치 모드 클릭은 배치만,
비설치 클릭은 인스턴스 선택만 수행한다. D/B는 인스턴스를 해제하고 설치로 전환한다.
`TowerUpgradePanel`은 기존 오른쪽 상점 영역을 대체하고 맵과 웨이브/속도/재시작 버튼을 가리지 않는다.
3개 경로 카드와 능력치는 선택한 타워의 Resource에서 생성한다. 경제 신호로 자금 부족 상태를 갱신하고,
구매 완료 신호로 새 티어/능력치를 갱신한다. 현재→다음 티어, 최종 수치의 전후 변화와 잠금 이유를 표시한다.
전후 변화는 설명문에 적힌 단일 경로 수치를 파싱하지 않고 두 계산 결과를 비교해 얻는다.

공간 격자와 시뮬레이션 단계의 타이머는 기본적으로 꺼져 있다. 별도 `tests/benchmark.gd`가 활성화하며
일반 플레이의 FPS 제한/게임 규칙은 바꾸지 않는다. 원시 샘플, CPU/엔진 정보, 측정 경계는 `BENCHMARKS.md` 참조.

## 회귀 검증

v0.1의 59개 로직과 10개 화면/입력 검사를 유지했다. 예외적으로 초기 표적 유실 시 다트 제거를 기대하던
검사 하나는 v0.2의 계속 비행 규칙으로 바꿨다. v0.1 웨이브/골드 175 시나리오는 별도 fixture로 유지한다.
새 전투 검증은 피해 행렬, 관통/중복/초과 피해, 상대 이동/모퉁이/동시 삭제/반지름 변화/출구,
주변 후보 검색, 같은 시뮬레이션 시점에 입력하는 1×/2× 비교를 포함한다.
v0.3에서도 기존 253개 범위를 유지했다. 초기 자금/목숨/3개 웨이브는 `v02_config.gd`로 격리하며
신규 캠페인/면역/분열/폭발은 별도 테스트로 검사한다. 검증 도구는 엔진 로그 외 콘솔의 종료 시 오류도 확인한다.

v0.4는 기존 366개 검사의 기대값을 바꾸지 않았다. 강화 로직 266개와 실제 렌더러/입력 75개를 추가해
총 707개다. 세 경로의 6웨이브 캠페인은 실제 `_process()` 누산기에서 1×/2× 동일 입력 시각으로 실행하고
결과/발사 수/골드 보존을 비교한다. 종료 시 RefCounted/Resource 누수도 로그에서 확인한다.

v0.5는 707개 검사 범위를 유지했다. 단일 경로 후 다른 경로가 잠긴다는 기대값 18개(로직 9/화면 9)만
명시적인 정책 변경에 따라 두 번째 경로 허용으로 교체했다. 나머지 수치/전투/경제 기대값은 바꾸지 않았다.
신규 교차 검사 2,065개는 64개 상태 분류, 34개 유효 상태에서 기존 9개 정의 각각의 거래/실패 불변,
주요 6조합의 모든 구매 순서 60개, 전후 계산·공격·면역·실제 수입 캠페인을 검증한다.
신규 실제 화면/입력 276개를 포함해 전체 3,048개다. 각 조합의 1×/2× 실제 누산기 결과가 일치한다.

신규 독립 특수 장전은 강화 전후 간격 비율로 잔여 진행도를 유지한다. 활성 SELF_BUFF 강화 시에는
실제 유효 간격으로 한 번만 장전을 환산해040→050에서 영구 간격 비율을 중복 적용하지 않는다.
