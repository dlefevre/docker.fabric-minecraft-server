# TODO

## server.properties — proper persistence and CONFIG_DIR migration

Currently `server.properties` is baked into the image and copied from
`$SERVER_DIR/server.properties.default` on every container start, with
`MC_*` environment variables applied on top. This means in-game or
manual changes to the file are lost on restart.

- Move `server.properties` management to `/data/config/server.properties`
  so it lives alongside the JSON config files on the persistent volume.
- On first start (file absent), seed from the baked-in defaults, then
  apply `MC_*` overrides.
- On subsequent starts (file present), leave the base file as-is and
  only apply `MC_*` overrides that are explicitly set (same idempotent
  pattern used for the JSON files).
- Update `$SERVER_DIR/server.properties` to be a symlink into
  `/data/config/`, mirroring how the JSON files are handled.
