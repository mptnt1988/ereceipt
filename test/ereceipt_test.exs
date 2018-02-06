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
  # doctest Ereceipt

  test "exempt, not imported" do
    input =
      [["Quantity", "Product", "Price"],
       [1, "book", 12.49]]
    categories =
      [["Product", "Category", "Imported"],
       ["book", "book", ""]]
    tax =
      "[tax]\n" <>
      "exempt = book, food, medical\n" <>
      "basic_rate = 10%\n" <>
      "import_duty = 5%\n"
    expected_output =
      %{"Amount" => "12.49",
        "Category" => "book",
        "Price" => "12.49",
        "Product" => "book",
        "Quantity" => "1",
        "Sales Tax" => "0.00",
        "Total Amount" => "12.49"}
    case_config = %{input: input,
                    categories: categories,
                    tax: tax,
                    expected: expected_output}
    run_case(case_config)
  end

  test "not exempt, not imported" do
    input =
      [["Quantity", "Product", "Price"],
       [2, "music cd", 14.99]]
    categories =
      [["Product", "Category", "Imported"],
       ["music cd", "entertainment", ""]]
    tax =
      "[tax]\n" <>
      "exempt = book, food, medical\n" <>
      "basic_rate = 10%\n" <>
      "import_duty = 5%\n"
    expected_output =
      %{"Amount" => "29.98",
        "Category" => "entertainment",
        "Price" => "14.99",
        "Product" => "music cd",
        "Quantity" => "2",
        "Sales Tax" => "3.00",
        "Total Amount" => "32.98"}
    case_config = %{input: input,
                    categories: categories,
                    tax: tax,
                    expected: expected_output}
    run_case(case_config)
  end

  test "not exempt, imported" do
    input =
      [["Quantity", "Product", "Price"],
       [3, "imported perfume", 27.99]]
    categories =
      [["Product", "Category", "Imported"],
       ["imported perfume", "fragrance", "TRUE"]]
    tax =
      "[tax]\n" <>
      "exempt = book, food, medical\n" <>
      "basic_rate = 10%\n" <>
      "import_duty = 5%\n"
    expected_output =
      %{"Amount" => "83.97",
        "Category" => "fragrance",
        "Price" => "27.99",
        "Product" => "imported perfume",
        "Quantity" => "3",
        "Sales Tax" => "12.60",
        "Total Amount" => "96.57"}
    case_config = %{input: input,
                    categories: categories,
                    tax: tax,
                    expected: expected_output}
    run_case(case_config)
  end

  test "exempt, imported" do
    input =
      [["Quantity", "Product", "Price"],
       [4, "imported chocolate", 10]]
    categories =
      [["Product", "Category", "Imported"],
       ["imported chocolate", "food", "TRUE"]]
    tax =
      "[tax]\n" <>
      "exempt = book, food, medical\n" <>
      "basic_rate = 10%\n" <>
      "import_duty = 5%\n"
    expected_output =
      %{"Amount" => "40.00",
        "Category" => "food",
        "Price" => "10.00",
        "Product" => "imported chocolate",
        "Quantity" => "4",
        "Sales Tax" => "2.00",
        "Total Amount" => "42.00"}
    case_config = %{input: input,
                    categories: categories,
                    tax: tax,
                    expected: expected_output}
    run_case(case_config)
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
