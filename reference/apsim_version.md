# Installed APSIM version string

Runs `Models --version` and returns the reported version (for example
`"2026.5.8046.0"`), cached for the session. Returns `NA_character_` when
the simulator is not available.

## Usage

``` r
apsim_version()
```

## Value

A single character string, or `NA_character_`.

## Examples

``` r
apsim_version()
#> [1] NA
```
