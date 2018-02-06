defmodule Ereceipt do
  @moduledoc """
  Documentation for Ereceipt.
  """

  @doc """
  Ereceipt

  ## Examples

      iex> Ereceipt.main []
      :nil

  """
  def main(args) do
    parse_args(args)
    make_receipts()
    output()
  end

  defp parse_args(_args) do
  end

  defp make_receipts do
  end

  defp output do
  end
end
