## How the mirror is chosen

| Distro | `mirror` set | `mirror` empty (default) |
|---|---|---|
| Debian | Uses it | `netselect-apt` picks the lowest-latency mirror for the image's architecture (optionally limited to `country`). netselect is removed afterwards. |
| Ubuntu (amd64/i386) | Uses it | apt's built-in `mirror://mirrors.ubuntu.com/mirrors.txt` method: a geo-IP ranked list with automatic fallback. No extra packages. |
| Ubuntu (other arches) | Uses it | Left unchanged; `mirrors.ubuntu.com` doesn't list ports mirrors. |
| Anything else | Left unchanged | Left unchanged |

Only the primary archive (`deb.debian.org/debian`, `archive.ubuntu.com/ubuntu` or `ports.ubuntu.com/ubuntu-ports`) is rewritten, in both deb822 (`*.sources`) and legacy (`*.list`) files. Security archives (and any `*-security` suite, e.g. on `ports.ubuntu.com`) are never changed.

Package integrity is still enforced by apt's signed `InRelease` files regardless of which mirror is used.

### Install order

Features are installed in an order the dev container CLI decides. To make every later feature benefit from the mirror, install this one first:

```json
"overrideFeatureInstallOrder": [
    "ghcr.io/hastarin/devcontainers-feature-netselect/netselect"
]
```

### Using a cache or internal mirror

`mirror` accepts any URL apt understands, so it works with [apt-cacher-ng](https://www.unix-ag.uni-kl.de/~bloch/acng/) in URL-rewrite mode:

```json
"ghcr.io/hastarin/devcontainers-feature-netselect/netselect:2": {
    "mirror": "http://apt-cacher:3142/deb.debian.org/debian"
}
```

The mirror is fixed at image build time. If the image will be built or run on a different network, prefer an explicit `mirror` (or none at all) over auto-selection.

### Upgrading from 1.x

- Change `netselect:1` to `netselect:2`. `country` still works as before.
- Ubuntu no longer downloads and runs `netselect`; it uses apt's `mirror://` method instead.
- `/tmp/mirror.txt` is no longer written.
