defmodule EreceiptTest do
  defmacro input_file, do: quote do: "test/input.csv"
  defmacro output_dir, do: quote do: "test"
  defmacro output_file, do: quote do: "test/output_input.csv"
  defmacro categories_conf_file, do: quote do: "test/categories.csv"
  defmacro tax_conf_file, do: quote do: "test/tax.conf"
  defmacro default_args, do: quote do: ["-i", input_file(),
                                        "-o", output_dir(),
                                        "-c", categories_conf_file(),
                                        "-t", tax_conf_file()]

  use ExUnit.Case
  doctest Ereceipt

  test "dummy test case" do
    assert Ereceipt.main([]) == nil
  end

  defp run_case(config) do
    # Init TC: prepare necessary files
    init_case(config)

    # Run script with default arguments
    args = default_args()
    Ereceipt.main(args)

    # Check output
    [{:ok, output}] =
      output_file()
      |> File.stream!
      |> CSV.decode(headers: true)
      |> Enum.take(1)
    assert output == config.expected

    # End TC: remove files
    end_case()
  end

  defp init_case(config) do
    # Create input CSV
    ifile = File.open!(input_file(), [:write])
    config.input
    |> CSV.encode
    |> Enum.each(&IO.write(ifile, &1))
    File.close(ifile)

    # Create product categories CSV
    cfile = File.open!(categories_conf_file(), [:write])
    config.categories
    |> CSV.encode
    |> Enum.each(&IO.write(cfile, &1))
    File.close(cfile)

    # Create tax configuration file
    File.write(tax_conf_file(), config.tax)
  end

  defp end_case do
    [input_file(), output_file(), categories_conf_file(), tax_conf_file()]
    |> Enum.each(&File.rm!(&1))
  end

end
