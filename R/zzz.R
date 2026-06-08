.onLoad <- function(libname, pkgname) {
  # Register the S7 methods this package defines for base generics (print).
  S7::methods_register()
  invisible(NULL)
}

# `.data` is the rlang/ggplot2 tidy-evaluation pronoun used in the optional
# `apsim_validation_plot()` (ggplot2 is in Suggests, so it cannot be imported);
# declaring it global silences the "no visible binding" note without a hard
# dependency on rlang.
utils::globalVariables(".data")
