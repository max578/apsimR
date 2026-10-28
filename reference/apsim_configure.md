# Configure the APSIM runtime explicitly

Pins the paths apsimR uses, overriding auto-discovery. Call this once
per session when APSIM is installed in a non-standard location or when
more than one version is present and a specific one is wanted. With all
arguments `NULL` it clears any pinned paths and reverts to discovery.

## Usage

``` r
apsim_configure(models = NULL, server = NULL, dotnet_root = NULL)
```

## Arguments

- models:

  Character path to the `Models` executable, or `NULL` to discover.

- server:

  Character path to the `apsim-server` executable, or `NULL`.

- dotnet_root:

  Character path to the .NET runtime root (sets `DOTNET_ROOT` for child
  processes), or `NULL` to discover `~/.dotnet-x64`.

## Value

Invisibly, the resolved runtime list (see
[`apsim_available()`](https://max578.github.io/apsimR/reference/apsim_available.md)).

## Examples

``` r
# Revert to auto-discovery.
apsim_configure()
```
