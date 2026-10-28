# Package index

## Simulation files

Read an .apsimx file into a typed, round-trippable object, list its
simulations, write it back, and apply validated node-path edits.

- [`apsim_sim()`](https://max578.github.io/apsimR/reference/apsim_sim.md)
  :

  A simulation file (`.apsimx`) as a typed object

- [`apsim_simulations()`](https://max578.github.io/apsimR/reference/apsim_simulations.md)
  :

  List the simulation names in an `apsim_sim`

- [`apsim_write()`](https://max578.github.io/apsimR/reference/apsim_write.md)
  :

  Write an `apsim_sim` back to an `.apsimx` file

- [`apsim_edit()`](https://max578.github.io/apsimR/reference/apsim_edit.md)
  :

  Apply `[Node].Property = value` edits through APSIM's validator

## Run and predict

Drive the simulator over a scenario design and read its outputs as a
contract-emitting ensemble.

- [`apsim_predict()`](https://max578.github.io/apsimR/reference/apsim_predict.md)
  : Run APSIM forward over a simulation file
- [`apsim_design()`](https://max578.github.io/apsimR/reference/apsim_design.md)
  : Build an experimental design over an APSIM parameter space
- [`apsim_read()`](https://max578.github.io/apsimR/reference/apsim_read.md)
  : Read a report from an APSIM DataStore
- [`apsim_reports()`](https://max578.github.io/apsimR/reference/apsim_reports.md)
  : List the report tables in an APSIM DataStore

## Calibrate and estimate

Solve the inverse problem – a bounded point estimate or a posterior
parameter ensemble – and fit a mechanism to a simulated input grid.

- [`apsim_calibrate()`](https://max578.github.io/apsimR/reference/apsim_calibrate.md)
  : Calibrate APSIM parameters against observations
- [`apsim_estimate()`](https://max578.github.io/apsimR/reference/apsim_estimate.md)
  : Estimate a mechanism by running APSIM across an input

## Sensitivity and emulation

Screen and decompose parameter influence (Morris, Sobol) and fit a
Gaussian-process surrogate of an expensive output with leave-one-out
diagnostics.

- [`apsim_sensitivity()`](https://max578.github.io/apsimR/reference/apsim_sensitivity.md)
  : Global sensitivity analysis of an APSIM output
- [`apsim_emulate()`](https://max578.github.io/apsimR/reference/apsim_emulate.md)
  : Emulate an expensive APSIM output with a Gaussian-process surrogate
- [`apsim_forward_model()`](https://max578.github.io/apsimR/reference/apsim_forward_model.md)
  : Build an APSIM forward model

## Validate

Score simulated output against observations with goodness-of-fit metrics
and a typed verdict, and draw observed-versus-predicted.

- [`apsim_validate()`](https://max578.github.io/apsimR/reference/apsim_validate.md)
  : Validate simulated output against observations
- [`apsim_validation_plot()`](https://max578.github.io/apsimR/reference/apsim_validation_plot.md)
  : Plot observed against predicted for a validation manifest

## Causal ground truth (OSSE)

Turn the simulator into a known-causal-structure data factory: an
observing-system simulation experiment with both potential outcomes
known.

- [`apsim_ground_truth()`](https://max578.github.io/apsimR/reference/apsim_ground_truth.md)
  : Generate a known-causal-structure dataset from APSIM (an OSSE)

## Contract manifest

The versioned, provenance-complete result object and its bridge to the
‘PESTO’ ensemble-manifest contract.

- [`apsim_manifest()`](https://max578.github.io/apsimR/reference/apsim_manifest.md)
  : An APSIM result as a contract-emitting manifest

- [`as_pesto_manifest()`](https://max578.github.io/apsimR/reference/as_pesto_manifest.md)
  :

  Bridge an `apsim_manifest` to a PESTO ensemble manifest

- [`orchestra_manifest`](https://max578.github.io/apsimR/reference/orchestra_manifest.md)
  : The orchestra manifest contract (apsimR-side implementation)

- [`as_orchestra_manifest()`](https://max578.github.io/apsimR/reference/as_orchestra_manifest.md)
  : Emit an apsimR result as an orchestra manifest

- [`verify_manifest()`](https://max578.github.io/apsimR/reference/verify_manifest.md)
  : Verify an orchestra manifest's payload integrity

- [`manifest_summary()`](https://max578.github.io/apsimR/reference/manifest_summary.md)
  : A typed home for a headline verdict

## Runtime and abstention

Discover, configure and query the installed simulator; the typed refusal
returned when the runtime is absent.

- [`apsim_available()`](https://max578.github.io/apsimR/reference/apsim_available.md)
  : Is the APSIM simulator available?
- [`apsim_version()`](https://max578.github.io/apsimR/reference/apsim_version.md)
  : Installed APSIM version string
- [`apsim_configure()`](https://max578.github.io/apsimR/reference/apsim_configure.md)
  : Configure the APSIM runtime explicitly
- [`apsim_example()`](https://max578.github.io/apsimR/reference/apsim_example.md)
  : Path to an installed APSIM example simulation
- [`apsim_server()`](https://max578.github.io/apsimR/reference/apsim_server.md)
  : Start a persistent APSIM server holding a simulation in memory
- [`apsim_run()`](https://max578.github.io/apsimR/reference/apsim_run.md)
  : Run the server's in-memory simulation, optionally with modified
  parameters
- [`apsim_output()`](https://max578.github.io/apsimR/reference/apsim_output.md)
  : Read a report from the server after a run
- [`apsim_abstention()`](https://max578.github.io/apsimR/reference/apsim_abstention.md)
  : Construct a typed abstention
- [`is_apsim_abstention()`](https://max578.github.io/apsimR/reference/is_apsim_abstention.md)
  : Is an object an apsimR abstention?

## External-fact grounding

The Independent-Oracle registry of the APSIM facts the package asserts
and the date each was last diffed against a live install.

- [`apsim_external_facts()`](https://max578.github.io/apsimR/reference/apsim_external_facts.md)
  : apsimR's external-authority (APSIM) fact registry
- [`apsim_fact_status()`](https://max578.github.io/apsimR/reference/apsim_fact_status.md)
  : Grounding status summary for apsimR's external facts

## Package

- [`apsimR`](https://max578.github.io/apsimR/reference/apsimR-package.md)
  [`apsimR-package`](https://max578.github.io/apsimR/reference/apsimR-package.md)
  : apsimR: APSIM Next Generation as a Contract-Emitting Analysis Member
