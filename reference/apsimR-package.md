# apsimR: APSIM Next Generation as a Contract-Emitting Analysis Member

A typed, server-capable R interface to APSIM Next Generation, the
process-based agricultural systems simulator. Drives the simulator for
prediction over scenario designs, mechanism-parameter estimation,
parameter calibration against observations (a bounded optimiser, or an
iterative ensemble smoother when 'PESTO' is present), global sensitivity
analysis (Morris and Sobol), Gaussian-process emulation with
leave-one-out diagnostics, validation against observations
(goodness-of-fit metrics and a typed verdict), and the generation of
known-causal-structure datasets for testing causal-inference methods,
and returns results as a versioned, provenance-complete 'apsim_manifest'
object that is emitted natively into the shared orchestra manifest
contract, so simulator output composes directly with downstream
calibration, uncertainty-quantification and causal-inference tools; an
ensemble inversion additionally bridges to a 'PESTO' ensemble manifest.
Execution degrades gracefully: every entry point abstains with a typed
reason when the simulator or its runtime is absent.

## See also

Useful links:

- <https://github.com/max578/apsimR>

- <https://max578.github.io/apsimR/>

- Report bugs at <https://github.com/max578/apsimR/issues>

## Author

**Maintainer**: Max Moldovan <max.moldovan@adelaide.edu.au>
([ORCID](https://orcid.org/0000-0001-9680-8474)) \[copyright holder\]

Authors:

- Max Moldovan <max.moldovan@adelaide.edu.au>
  ([ORCID](https://orcid.org/0000-0001-9680-8474)) \[copyright holder\]
