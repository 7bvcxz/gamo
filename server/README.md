# gamo-server

Decisions about the games, and the comments that produced them.

Kotlin · Spring Boot 3.5.3 · Java 21 · Postgres 16, all in Docker. The same
toolchain as `heydive-server` on this machine — two servers that disagree about
their stack are two sets of surprises.

## 띄우기

```bash
docker compose -f server/docker-compose.yml up -d --build
curl -s http://127.0.0.1:8790/api/ping
```

포트는 **8790**이다. 이 머신은 이미 8080·8000(heydive), 8088/8090(gamo nginx),
5432(다른 Postgres)를 쓰고 있어서 비어 있는 쌍을 골랐다. Postgres는 공개하지 않는다 —
compose 네트워크 안에서만 닿는다.

compose 프로젝트 이름은 `gamo`로 못박혀 있다. 기본값은 디렉터리 이름인 `server`인데, 이
머신에는 같은 이름을 쓰는 다른 프로젝트가 있어서 둘이 이름공간을 공유했다. 한쪽에서
`docker compose down` 한 번이면 남의 컨테이너가 지워진다.

## API

`/api/gamo/v1/decisions`

| | |
|---|---|
| `GET /` | 목록. `?status=` `?priority=` `?category=` `?q=` 로 거른다 |
| `GET /{id}` | 하나 |
| `POST /` | 만들기. `title`이 필수 |
| `PATCH /{id}` | 고치기. 보낸 필드만 바뀐다 |
| `DELETE /{id}` | 지우기. 댓글도 함께 |
| `POST /{id}/comments` | 댓글. `author`는 `HUMAN` 또는 `CLAUDE` |
| `DELETE /{id}/comments/{commentId}` | 댓글 삭제 |

댓글이 붙거나 지워지면 **decision 전체**를 돌려준다. 방금 쓴 화면이 다시 물어보지 않아도
되게 하려는 것이다.

```bash
API=http://127.0.0.1:8790/api/gamo/v1/decisions

curl -s "$API?status=OPEN&priority=P0" | jq '.items[].title'

ID=$(curl -s -X POST "$API" -H 'Content-Type: application/json' \
  -d '{"title":"하루 길이","priority":"P0","category":"core-loop"}' | jq -r .id)

curl -s -X POST "$API/$ID/comments" -H 'Content-Type: application/json' \
  -d '{"author":"CLAUDE","body":"측정해 보니 …"}' | jq '.comments[].author'
```

**작성자는 둘뿐이다.** `HUMAN`과 `CLAUDE` 외에는 400이다. 열린 문자열이었다면 "me",
"merti", "user", "Claude Code"로 흩어졌을 것이고, 화자를 구분할 수 없는 스레드는 나중에
아무도 다시 읽지 않는다.

## 테스트

```bash
cd server
docker run --rm -v "$PWD":/app -v gamo-m2:/root/.m2 -w /app \
  maven:3.9-eclipse-temurin-21 mvn -q clean test
```

`clean`이 붙어 있는 것에 이유가 있다. maven은 지워진 리소스를 `target/`에서 치우지
않으므로, 옛 `application.yml` 하나가 남아 메인 설정을 계속 덮은 적이 있다.

테스트는 H2 인메모리로 돌아서 아무것도 띄우지 않아도 된다. 설정은 `application-test.yml`
**프로파일**이다 — `src/test/resources/application.yml`은 메인 설정과 합쳐지지 않고
**덮어쓴다.**

## 사이트와의 관계

사이트(`web/`)는 서버 코드가 0인 정적 export다. 이 서버는 그 옆에 있고, 사이트가 이것
없이도 렌더된다.

```
편집:  localhost/127.0.0.1 에서 열면 → 8790 에 물어보고 CRUD
읽기:  그 외 주소에서 열면        → 커밋된 스냅샷을 읽고 읽기 전용
```

스냅샷은 `node web/scripts/decisions-snapshot.mjs`로 갱신하고 커밋한다. 서버가 꺼져 있으면
기존 스냅샷을 그대로 둔다 — 빈 파일을 쓰면 "결정이 없다"고 공개하게 되는데, 그것은
"아무도 안 물어봤다"와 다른 주장이다.

공개 주소에서도 편집하려면 `deploy/`의 Cloudflare 터널 뒤에 이 서버를 붙이고
`NEXT_PUBLIC_DECISIONS_API`를 그 주소로 주면 된다. CORS 목록에는 이미 들어 있다.

## 백업

데이터는 `gamo_gamo-pgdata` 볼륨에 있다.

```bash
docker exec gamo-postgres pg_dump -U gamo gamo > decisions-$(date +%F).sql
```
