defimpl Scrivener.Paginater, for: Ecto.Query do
  import Ecto.Query

  alias Scrivener.{Config, Page}

  @moduledoc false

  @spec paginate(Ecto.Query.t(), Scrivener.Config.t()) :: Scrivener.Page.t()
  def paginate(query, %Config{
        page_size: page_size,
        page_number: page_number,
        module: repo,
        caller: caller,
        options: options
      }) do
    total_entries =
      Keyword.get_lazy(options, :total_entries, fn ->
        total_entries(query, repo, caller, options)
      end)

    total_pages = total_pages(total_entries, page_size)
    allow_overflow_page_number = Keyword.get(options, :allow_overflow_page_number, false)

    page_number =
      if allow_overflow_page_number, do: page_number, else: min(total_pages, page_number)

    %Page{
      page_size: page_size,
      page_number: page_number,
      entries: entries(query, repo, page_number, total_pages, page_size, caller, options),
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp entries(_, _, page_number, total_pages, _, _, _) when page_number > total_pages, do: []

  defp entries(query, repo, page_number, _, page_size, caller, options) do
    offset = Keyword.get_lazy(options, :offset, fn -> page_size * (page_number - 1) end)
    prefix = options[:prefix]

    query
    |> offset(^offset)
    |> limit(^page_size)
    |> all(repo, caller, prefix)
  end

  defp total_entries(%{combinations: [_|_]} = query, repo, caller, options) do
    prefix = options[:prefix]

    simpler_query =
      query
      |> exclude(:preload)
      |> exclude(:order_by)

    {sql_query, params} = Ecto.Adapters.SQL.to_sql(:all, repo, simpler_query)
    count_query = "select count(*) from (#{sql_query}) as count_me"
    %Postgrex.Result{
      columns: ["count"],
      command: :select,
      num_rows: 1,
      rows: [[total_entries]]
    }
    = Ecto.Adapters.SQL.query!(
      repo, "select count(*) from (#{sql_query}) as count_me", params
    )

    total_entries || 0
  end

  defp total_entries(query, repo, caller, options) do
    prefix = options[:prefix]

    total_entries =
      query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> aggregate()
      |> one(repo, caller, prefix)

    total_entries || 0
  end

  defp aggregate(%{distinct: %{expr: expr}} = query) when expr == true or is_list(expr) do
    query
    |> count()
  end

  defp aggregate(%{order_bys: %{expr: expr}} = query) do
    query
    |> exclude(:preload)
    |> select(count("*"))
  end

  defp aggregate(
         %{
           group_bys: [
             %Ecto.Query.QueryExpr{
               expr: [
                 {{:., [], [{:&, [], [source_index]}, field]}, [], []} | _
               ]
             }
             | _
           ]
         } = query
       ) do
    query
    |> exclude(:select)
    |> select([{x, source_index}], struct(x, ^[field]))
    |> count()
  end

  defp aggregate(query) do
    query
    |> exclude(:select)
    |> select(count("*"))
  end

  defp count(query) do
    query
    |> subquery
    |> select(count("*"))
  end

  defp total_pages(0, _), do: 1

  defp total_pages(total_entries, page_size) do
    (total_entries / page_size) |> Float.ceil() |> round
  end

  defp all(query, repo, caller, nil) do
    repo.all(query, caller: caller)
  end

  defp all(query, repo, caller, prefix) do
    repo.all(query, caller: caller, prefix: prefix)
  end

  defp one(query, repo, caller, nil) do
    repo.one(query, caller: caller)
  end

  defp one(query, repo, caller, prefix) do
    repo.one(query, caller: caller, prefix: prefix)
  end
end
