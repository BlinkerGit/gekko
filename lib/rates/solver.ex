defmodule Gekko.Rates.Solver do
  import Kernel, except: [raise: 2, raise: 3]

  @moduledoc """
  Provides functions for calculating APR and Interest Rate.

  ## Specifications

  Uses standard methods for calculating APR and Interest Rate. To solve we utilize the [Newton Raphson method](https://en.wikipedia.org/wiki/Newton%27s_method)
  """

  @doc """
  Calculates APR from annual_rate, term, principal and fee

  ## Examples

      iex(2)> Gekko.Rates.Solver.apr(Decimal.cast(0.23), 24, Decimal.cast(2342), Decimal.cast(20))
      #Decimal<0.238987>
  """
  @spec apr(Decimal.t(), integer, Decimal.t(), Decimal.t()) :: Decimal.t()
  def apr(annual_rate, term, principal = %Decimal{sign: 1}, fee = %Decimal{sign: 1})
      when is_integer(term) do
    total = Decimal.add(principal, fee)

    annual_rate
    |> monthly_payment(term, total)
    |> ratio(principal)
    |> solve(term, annual_rate)
  end

  @doc """
  Calculates interest rate using payment, term, principal, and a guess. The guess is a place to start.

  ## Examples

      iex(3)> Gekko.Rates.Solver.interest_rate(Decimal.cast(450.00), 72, Decimal.cast("24000"))
      #Decimal<0.104430>
  """
  @spec interest_rate(Decimal.t(), integer, Decimal.t(), Decimal.t()) :: Decimal.t()
  def interest_rate(
        %Decimal{sign: 1} = payment,
        term,
        %Decimal{sign: 1} = principal,
        guess \\ Decimal.cast(10.0)
      )
      when is_integer(term) do
    payment
    |> ratio(principal)
    |> solve(term, guess)
  end

  @spec solve(Decimal.t(), integer, Decimal.t()) :: Decimal.t()
  defp solve(%Decimal{} = ratio, term, %Decimal{} = guess) when is_integer(term) do
    start =
      guess
      |> Decimal.div(12)
      |> Decimal.add(1)

    newton_raphson(start, ratio, term)
    |> Decimal.sub(1)
    |> Decimal.mult(12)
    |> Decimal.round(6)
  end

  @spec ratio(Decimal.t(), Decimal.t()) :: Decimal.t()
  defp ratio(payment = %Decimal{sign: 1}, principal = %Decimal{sign: 1}) do
    Decimal.div(payment, principal)
  end

  @spec newton_raphson(Decimal.t(), Decimal.t(), integer) :: Decimal.t()
  defp newton_raphson(%Decimal{} = start, %Decimal{} = ratio, term) when is_integer(term) do
    precision = Decimal.new(100_000)
    k_next = start
    k = Decimal.from_float(0.0)
    newton_raphson(k, k_next, precision, ratio, term)
  end

  @spec newton_raphson(
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          integer
        ) :: Decimal.t()
  defp newton_raphson(
         %Decimal{} = k,
         %Decimal{} = k_next,
         %Decimal{} = mag,
         %Decimal{} = ratio,
         term
       )
       when is_integer(term) do
    k_eval =
      Decimal.sub(k, 1)
      |> Decimal.mult(mag)
      |> Decimal.round(0)

    k_next_eval =
      Decimal.sub(k_next, 1)
      |> Decimal.mult(mag)
      |> Decimal.round(0)

    case Decimal.cmp(k_eval, k_next_eval) do
      :eq ->
        k_next

      _ ->
        k = k_next
        f = f(k, ratio, term)
        df = df(k, ratio, term) |> Decimal.abs()
        math = Decimal.div(f, df)
        k_future = Decimal.sub(k_next, math)
        newton_raphson(k_next, k_future, mag, ratio, term)
    end
  end

  # This is the equation being solved by the Newton-Raphson method.
  @spec f(Decimal.t(), Decimal.t(), integer) :: Decimal.t()
  defp f(%Decimal{} = k, %Decimal{} = ratio, term) do
    first = exp(k, Decimal.new(term + 1))
    second = exp(k, Decimal.new(term))
    third = Decimal.mult(second, Decimal.add(ratio, 1))

    Decimal.sub(first, third)
    |> Decimal.add(ratio)
  end

  # This is df/dk, necessary for the Newton-Raphson method.
  @spec df(Decimal.t(), Decimal.t(), integer) :: Decimal.t()
  defp df(%Decimal{} = k, %Decimal{} = ratio, term) do
    d_term = Decimal.new(term)
    first = Decimal.mult(exp(k, d_term), term + 1)
    second = Decimal.mult(Decimal.add(ratio, 1), term)
    third = Decimal.mult(second, exp(k, Decimal.sub(d_term, 1)))
    Decimal.sub(first, third)
  end

  @spec exp(Decimal.t(), Decimal.t()) :: Decimal.t()
  defp exp(%Decimal{} = decimal, %Decimal{} = exponent) do
    decimal = Decimal.to_float(decimal)
    exponent = Decimal.to_float(exponent)
    Decimal.from_float(:math.pow(decimal, exponent))
  end

  @spec pow(Decimal.t(), integer) :: Decimal.t()
  defp pow(%Decimal{} = decimal, exponent) do
    denominator =
      Enum.reduce(1..exponent, 1, fn _, result ->
        Decimal.mult(decimal, result)
      end)

    Decimal.div(1, denominator)
  end

  # ====================== PAYMENT =============================

  defp monthly_payment(%Decimal{sign: 1} = annual_rate, term, %Decimal{sign: 1} = amount) do
    denominator =
      annual_rate
      |> annual_to_month()
      |> payment_denom(term)

    annual_rate
    |> annual_to_month()
    |> Decimal.mult(amount)
    |> Decimal.div(denominator)
    |> Decimal.round(6)
  end

  defp payment_denom(rate = %Decimal{}, term) do
    rate
    |> Decimal.add(1)
    |> pow(term)
    |> Decimal.mult(-1)
    |> Decimal.add(1)
  end

  # ====================== ANNUAL_TO_MONTH =============================
  defp annual_to_month(%Decimal{} = annual_rate) do
    annual_rate
    |> Decimal.div(12)
  end
end
