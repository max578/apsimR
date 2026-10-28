# A typed home for a headline verdict

A non-ensemble inference – a validation verdict, a decision – has no
meaningful values for the ensemble payload slots and should not ride in
`params` as a one-row pseudo-parameter table. The contract's optional
`summary` slot carries the headline label, whether the emitter
abstained, and the key metrics. It is integrity-hashed with the rest of
the payload, so a tampered verdict is detected. The class and field
names match the reference contract's `manifest_summary()` exactly, so a
consumer reads an apsimR verdict with no special casing.

## Usage

``` r
manifest_summary(
  headline,
  abstained = FALSE,
  metrics = list(),
  abstain_reason = NA_character_
)
```

## Arguments

- headline:

  Character scalar: the verdict itself, for example `"good"`.

- abstained:

  Logical scalar: did the emitter decline to stand behind the result?

- metrics:

  Named list of supporting numbers.

- abstain_reason:

  Character scalar reason when `abstained` is `TRUE`.

## Value

A `manifest_summary` list.

## Examples

``` r
manifest_summary("good", metrics = list(nse = 0.82))
#> $headline
#> [1] "good"
#> 
#> $abstained
#> [1] FALSE
#> 
#> $abstain_reason
#> [1] NA
#> 
#> $metrics
#> $metrics$nse
#> [1] 0.82
#> 
#> 
#> attr(,"class")
#> [1] "manifest_summary"
```
