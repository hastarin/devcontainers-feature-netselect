
# netselect (netselect)

Uses netselect-apt to configure a mirror. Use `overrideFeatureInstallOrder` to ensure it's run first. https://containers.dev/implementors/features/#overrideFeatureInstallOrder

## Example Usage

```json
"features": {
    "ghcr.io/hastarin/devcontainers-feature-netselect/netselect:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| country | Debian ONLY - Select or enter a country code to only consider mirrors from that country. | string | default |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/hastarin/devcontainers-feature-netselect/blob/main/src/netselect/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
