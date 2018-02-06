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
    # Get the configuration data in form of:
    # %{input: list(<input CSV paths>),
    #   output: <output dir>,
    #   categories: %{"<product>" => %{category: <category>,
    #                                  imported?: <boolean>}}
    #   tax: %{basic_rate: <rate>,
    #          exempt: list(<exempt category>),
    #          import_duty: <import_taxrate>}}
    _conf = parse_args(args)
    make_receipts()
    output()
  end

  defp parse_args(args) do
    alias_opts = [c: :categories, h: :help, i: :input, o: :output, t: :tax]
    opts = [categories: :string, help: :boolean, input: :keep,
            output: :string, tax: :string]
    {parsed_opts, _remained_args, _invalid_opts} =
      OptionParser.parse(args, aliases: alias_opts, strict: opts)
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

  defp make_receipts do
  end

  defp output do
  end

end
