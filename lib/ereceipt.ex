defmodule Ereceipt do
  @moduledoc """
  Documentation for Ereceipt.
  """

  @doc """
  Ereceipt

  ## Examples

  iex> Ereceipt.main []
  :ok

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
    # Get the configuration data in form of:
    # %{input: list(<input CSV paths>),
    #   output: <output dir>,
    #   categories: %{"<product>" => %{category: <category>,
    #                                  imported?: <boolean>}}
    #   tax: %{basic_rate: <rate>,
    #          exempt: list(<exempt category>),
    #          import_duty: <import_taxrate>}}
    conf = parse_args(args)

    # Make receipts in form of
    # list(
    #   %{output_name: <on>,
    #     entries: list(
    #       %{quantity: <quantity of entry>,
    #         product: <product name>,
    #         category: <category of product>,
    #         price: <unit price of product>,
    #         sales_tax: <calculated tax on this entry>}
    #     )}
    # )
    receipts = make_receipts(conf.input, conf.categories, conf.tax)

    # Output all to stdout and CSV if specified
    output(receipts, conf.output)
  end

  defp parse_args(args) do
    alias_opts = [c: :categories, h: :help, i: :input, o: :output, t: :tax]
    opts = [categories: :string, help: :boolean, input: :keep,
            output: :string, tax: :string]
    {parsed_opts, _remained_args, _invalid_opts} =
      OptionParser.parse(args, aliases: alias_opts, strict: opts)

    # Print help if -h | --help specified, other options ignored
    if Keyword.get(parsed_opts, :help) do
      print_help()
      System.halt()
    end

    get_conf(parsed_opts)
  end

  defp print_help do
    command = __ENV__.file |> Path.basename |> Path.rootname
    IO.puts("Usage: #{command} [options...]")
    IO.puts("Options:")
    IO.puts("\t-c, --categories CATEGORIES_CSV\t\tList categories of products.")
    IO.puts("\t\t\t\t\t\tDefault to \"categories.csv\" in current directory if not speicifed.")
    IO.puts("\t-h, --help\t\t\t\tPrint this help. Other options are ignored.")
    IO.puts("\t-i, --input INPUT_CSV\t\t\tInput CSV. Multiple of this options accepted.")
    IO.puts("\t\t\t\t\t\tDefault to \"input.csv\" in current directory if not specified.")
    IO.puts("\t-o, --output OUTPUT_DIR\t\t\tOutput directory for output CSV(s) if specified.")
    IO.puts("\t\t\t\t\t\t-o \"\" specifies current directory.")
    IO.puts("\t-t, --tax TAX_CONF\t\t\tConfig file for tax rates.")
    IO.puts("\t\t\t\t\t\tDefault to \"tax.conf\" in current directory if not specified.")
    IO.puts("Examples:")
    IO.puts("\t$ #{command}")
    IO.puts("\t$ #{command} -i input.csv -i input2.csv -i input3.csv -o \"\"")

  end

  defp get_conf(opts) do
    %{
      input: get_input_files(opts),
      output: get_output_dir(opts),
      categories: get_categories_conf(opts),
      tax: get_tax_conf(opts)
    }
  end

  defp get_input_files(opts) do
    case Keyword.get_values(opts, :input) do
      [] ->
        if File.exists?(default_input_file()) do
          [default_input_file()]
        else
          raise "No input files."
        end
      list -> list
    end
  end

  defp get_output_dir(opts) do
    case Keyword.get(opts, :output) do
      nil -> nil
      "" -> default_output_dir()
      dir ->
        case File.mkdir_p(dir) do
          :ok -> dir
          {:error, reason} ->
            warning_text = "Problem creating #{dir}: #{reason}"
            IO.puts(warning_text)
            nil
        end
    end
  end

  defp get_categories_conf(opts) do
    file_path = Keyword.get(opts, :categories, default_categories_conf_file())
    reduce_func = fn
      {:ok, e}, acc ->
        Map.put(acc, e["Product"], %{category: e["Category"],
                                     imported?: booleanize(e["Imported"])})
    end
    if File.exists?(file_path) do
      file_path
      |> File.stream!
      |> CSV.decode(headers: true)
      |> Enum.reduce(%{}, reduce_func)
    else
      raise "No categories config found."
    end
  end

  defp booleanize("TRUE"), do: true
  defp booleanize(_), do: false

  defp get_tax_conf(opts) do
    file_path = Keyword.get(opts, :tax, default_tax_conf_file())
    {:ok, parse_result} = ConfigParser.parse_file(file_path)
    raw_tax_conf = parse_result["tax"]
    exempt = change_exempt_categories_to_list(raw_tax_conf["exempt"])
    basic_rate = change_percent_str_to_float(raw_tax_conf["basic_rate"])
    import_duty = change_percent_str_to_float(raw_tax_conf["import_duty"])
    %{
      exempt: exempt,
      basic_rate: basic_rate,
      import_duty: import_duty
    }
  end

  defp change_exempt_categories_to_list(str) do
    str
    |> String.split(",")
    |> Enum.map(fn(word) -> String.trim(word) end)
  end

  defp change_percent_str_to_float(str) do
    convert_fun = fn
      {f, "%"} -> f/100
      _ -> raise "Wrong percent."
    end
    str |> Float.parse() |> convert_fun.()
  end

  defp make_receipts(input_files, categories_conf, tax_conf) do
    input_files
    |> Enum.map(fn(csv) -> make_receipt(csv, categories_conf, tax_conf) end)
  end

  defp make_receipt(input_file, categories_conf, tax_conf) do
    output_name = "output_" <> Path.basename(input_file)
    entries = get_entries(input_file, categories_conf, tax_conf)
    %{
      output_name: output_name,
      entries: entries
    }
  end

  defp get_entries(csv, categories_conf, tax_conf) do
    make_entry_func = fn ({:ok, e}) ->
      quantity = String.to_integer(e["Quantity"])
      product = e["Product"]
      category = categories_conf[product].category
      {price, _} = Float.parse(e["Price"])
      input_entry = %{quantity: quantity,
                      product: product,
                      category: category,
                      price: price}
      sales_tax = calculate_sales_tax(input_entry, categories_conf, tax_conf)
      Map.put(input_entry, :sales_tax, sales_tax)
    end

    csv
    |> File.stream!
    |> CSV.decode(headers: true)
    |> Enum.map(make_entry_func)
  end

  defp calculate_sales_tax(input_entry, categories_conf, tax_conf) do
    product = input_entry.product
    product_info = categories_conf[product]

    exempt_list = tax_conf.exempt
    tax_exempt? = product_info.category in exempt_list
    basic_taxrate = tax_exempt? && 0 || tax_conf.basic_rate

    imported? = product_info.imported?
    import_taxrate = imported? && tax_conf.import_duty || 0

    taxrate = basic_taxrate + import_taxrate
    raw_tax = input_entry.quantity * input_entry.price * taxrate
    Float.ceil(raw_tax * 20) / 20
  end

  defp output([receipt | others], output_dir) do
    output_stdout(receipt)
    output_file(receipt, output_dir)
    output(others, output_dir)
  end
  defp output([], _), do: :ok

  defp output_stdout(receipt) do
    IO.puts("\n## #{Path.rootname(receipt.output_name)}")
    IO.puts("Quantity, Product, Total Amount")

    reduce_func = fn(entry, {acc_tax, acc_total}) ->
      %{quantity: quantity,
        product: product,
        price: price,
        sales_tax: sales_tax} = entry
      total_amount = quantity * price + sales_tax
      total_amount_str = float_format(total_amount)
      IO.puts(Enum.join([quantity, product, total_amount_str], ", "))
      {acc_tax + sales_tax, acc_total + total_amount}
    end

    {sales_taxes, total} =
      receipt.entries
      |> Enum.reduce({0, 0}, reduce_func)

    IO.puts("\nSales Taxes: #{float_format(sales_taxes)}")
    IO.puts("Total: #{float_format(total)}")
  end

  defp float_format(f), do: :erlang.float_to_binary(f, [decimals: 2])

  defp output_file(_receipt, nil), do: :ok
  defp output_file(receipt, dir) do
    file_path = Path.join(dir, receipt.output_name)
    file = File.open!(file_path, [:write, :utf8])
    table_data = [["Quantity", "Product", "Category", "Price",
                   "Amount", "Sales Tax", "Total Amount"]]

    reduce_func = fn(entry, acc) ->
      %{quantity: quantity,
        product: product,
        category: category,
        price: price,
        sales_tax: sales_tax} = entry
      amount = quantity * price
      total_amount = amount + sales_tax
      entry_list = [
        quantity, product, category, float_format(price), float_format(amount),
        float_format(sales_tax), float_format(total_amount)
      ]
      [entry_list | acc]
    end

    receipt.entries
    |> Enum.reduce(table_data, reduce_func)
    |> Enum.reverse
    |> CSV.encode
    |> Enum.each(&IO.write(file, &1))

    File.close(file)
    IO.puts("Data output to #{file_path}")
  end

end
