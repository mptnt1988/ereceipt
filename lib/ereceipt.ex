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

  defmacro default_tax_conf_file do
    quote do: Path.join(System.cwd(), "tax.conf")
  end
  defmacro default_categories_conf_file do
    quote do: Path.join(System.cwd(), "categories.csv")
  end
  defmacro default_input_file do
    quote do: Path.join(System.cwd(), "input.csv")
  end
  defmacro default_output_dir do
    quote do: System.cwd()
  end

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
