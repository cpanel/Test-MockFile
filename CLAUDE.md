# Test::MockFile

Perl module for mocking file system operations in unit tests. Intercepts `stat`, `lstat`, `-X` operators, `open`, `sysopen`, `opendir`, and related calls so tests run without touching disk.

## Architecture

- **Core**: `lib/Test/MockFile.pm` (~2530 lines) — main module, CORE::GLOBAL overrides, strict mode
- **FileHandle**: `lib/Test/MockFile/FileHandle.pm` — tied file handle for mocked files
- **DirHandle**: `lib/Test/MockFile/DirHandle.pm` — directory handle for mocked dirs
- **Plugin system**: `lib/Test/MockFile/Plugin.pm`, `Plugins.pm`, `Plugin/FileTemp.pm`
- **Key dependency**: `Overload::FileCheck` (XS) — enables `-X` operator interception

## How It Works

1. `Overload::FileCheck` hooks `-X` operators and `stat`/`lstat` via XS
2. `CORE::GLOBAL::*` overrides intercept `open`, `sysopen`, `opendir`, `readdir`, etc.
3. Mocked files stored in `%files_being_mocked` hash (path → blessed object, weakref)
4. Strict mode (default ON) dies on unmocked file access — configurable via rules

## Build & Test

```bash
perl Makefile.PL && make && make test
```

Dependencies installed via `cpanfile` (for CI: `cpm install -g`).

## Conventions

- **Perl style**: `.perltidyrc` in repo root — run `perltidy` before committing
- **POD**: `.podtidy-opts` — documentation inline in `.pm` files
- **Minimum Perl**: 5.14 (code uses `goto` on CORE functions, available 5.16+; workaround for 5.14)
- **Branch naming**: feature branches off `master`

## CI

- GitHub Actions: `.github/workflows/linux.yml`
- Matrix: Perl 5.14–5.40 on `perldocker/perl-tester`
- Env: `PERL_USE_UNSAFE_INC=0`, `AUTHOR_TESTING=1`

## Key Internals

- `_upgrade_barewords()` — converts bareword filehandles to typeglobs
- `_find_file_or_fh()` — resolves paths/handles, follows symlinks (max depth 10)
- `_abs_path_to_file()` — normalizes paths (strips `//`, `./`, trailing `/`)
- `_strict_mode_violation()` — enforces strict mode with stack inspection
- `_goto_is_available()` — detects Perl versions where `goto \&CORE::func` works
- Strict rules: `@STRICT_RULES` array, evaluated in order (first match wins)

## Open Issues (25)

Notable: #158 (glob corruption), #112 (flock), #77 (seek/truncate/tell), #44 (autodie compat), #27 (two handles same file). Full list: https://github.com/cpanel/Test-MockFile/issues
