defmodule Rates do
  alias Gekko.Rates.Solver

  defdelegate apr(annual_rate, term, principal, fee), to: Solver
  defdelegate interest_rate(payment, term, principal, guess), to: Solver
end
