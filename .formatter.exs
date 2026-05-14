# Used by "mix format"
locals_without_parens = [
  def_transition: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  migrate: true,
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
