defmodule SolverTest do
  use ExUnit.Case
  alias Gekko.Rates.Solver
  doctest Solver

  describe "calculate interest rate" do
    test "given payment, term and amount it returns the correct rate" do
      assert Solver.interest_rate(Decimal.new("300.00"), 60, Decimal.new("10000")) ==
               Decimal.new("0.261005")

      assert Solver.interest_rate(Decimal.new("450.00"), 72, Decimal.new("25000")) ==
               Decimal.new("0.089485")
    end
  end
end
