# Path to an installed APSIM example simulation

Returns the path to one of the `.apsimx` examples shipped with the
installed APSIM, so examples and tests can run against a real simulation
without the package bundling APSIM's own (separately-licensed) files.
Returns `NA_character_` when the simulator or the named example is not
present.

## Usage

``` r
apsim_example(name = "Wheat")
```

## Arguments

- name:

  Character example name without extension (default `"Wheat"`).

## Value

A single character path, or `NA_character_`.

## Examples

``` r
if (FALSE) { # apsimR::apsim_available()
apsim_example("Wheat")
}
```
