# Serving gamo from this machine

GitHub Pages still works and nothing here replaces it. This exists because Pages
decides two things we cannot: when a push becomes visible, and how long a file
stays cached. On 2026-08-06 a push took over four hours to appear while the file
it replaced kept answering 200, and the ten minute cache meant a corrected image
stayed wrong for ten minutes after that. Both numbers are ours now.

## What this is not

There is no application server, and adding one would be a mistake. `web/src`
contains no call to `fetch` and no reference to `/api` — the site is 77 static
files, 150MB of which are Godot engine and pack binaries. Next.js or Spring Boot
would put a runtime in front of content that has no dynamic parts, and would not
make a single deploy faster. The slow part was never the framework.

## Running it

```sh
docker compose -f deploy/docker-compose.yml up -d   # once
./deploy/publish.sh                                 # every deploy
```

`publish.sh` builds the web bundle, drops bundles nothing references, copies into
the serve root, pre-compresses, and then checks the running container actually
answers. It takes seconds and the result is live when it returns.

The serve root is `~/srv/gamo`, deliberately not the repository's `docs/`. A
bind-mounted working tree would put half-finished builds on the internet and
would scatter `.gz` files through the source tree.

## The one step that is not in this repository

The Cloudflare tunnel is token-based (`CLOUDFLARE_TUNNEL_TOKEN` in
`heydive-server/.env`), which means its public hostnames live in the Cloudflare
dashboard, not in any file here. To publish:

> Zero Trust → Networks → Tunnels → the heydive tunnel → Public Hostname → Add
>
> * Subdomain: `gamo` (or whatever you prefer)
> * Domain: `heydive.in`
> * Service: `HTTP` → `gamo-web:80`

`gamo-web` resolves because the container joins `heydive-server_default`, the
network the tunnel already runs on. Verified from inside that network:
`curl http://gamo-web/gamo/` returns 200.

Nothing needs to be opened on the router. The tunnel makes an outbound
connection to Cloudflare and traffic comes back down it, which is the reason
this works from a machine behind NAT at all.

## Paths

The site keeps its `/gamo/` base so that both hosts serve byte-identical files
and either can be switched off without a rebuild. After the hostname is added,
`https://gamo.heydive.in/gamo/motorio-oneshot/` and
`https://7bvcxz.github.io/gamo/motorio-oneshot/` are the same build.

If the GitHub host is eventually dropped, set `base: '/'` in `web/vite.config.js`,
change the `location /gamo/` block to `location /`, and re-export the games.

## Cache policy

Set here, in `nginx.conf`, rather than requested and ignored:

| files | header | why |
|---|---|---|
| `*-<hash>.wasm/pck/js/css/png/mp4` | `max-age=31536000, immutable` | changing the bytes changes the URL |
| `*.html`, `*.json` | `no-cache` | these are how a browser finds the hashed names |
| everything else | `max-age=300` | |

`.gz` files are built once per deploy and served by `gzip_static`, so the 37.7MB
engine goes out as 10.1MB with no per-request compression. Pages sends 10.2MB,
so a cold load costs the same.

## Things that bit me here

* Docker creates a missing bind-mount path as root. Create the serve root first,
  or a publish as your own user cannot write to it.
* A `types { }` block **replaces** the inherited MIME map instead of extending
  it. Declaring `wasm` cost every other type in the file and `index.html` went
  out as `application/octet-stream`, which browsers download rather than render.
  nginx 1.27's own `mime.types` already has `application/wasm`, so the block was
  not needed at all.
* nginx reads a bare `{` as the start of a block, so a regex containing `{8,}`
  must be quoted.
* Editing a file that is bind-mounted **as a single file** replaces its inode,
  and the container keeps the old one. `nginx -s reload` re-reads the stale file
  and reports success. Recreate the container instead — I nearly concluded a
  correct fix had failed.
