# Scrivener.Ecto

[![Build
Status](https://github.com/drewolson/scrivener_ecto/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/drewolson/scrivener_ecto/actions/workflows/test.yml)

## Low Maintenance Warning

This library is in low maintenance mode, which means the author is currently only responding to pull requests and breaking issues.

## Usage

Scrivener.Ecto allows you to paginate your Ecto queries with Scrivener. It gives you useful information such as the total number of pages, the current page, and the current page's entries. It works nicely with Phoenix as well.

First, you'll want to `use` Scrivener in your application's Ecto Repo. This will add a `paginate` function to your Repo. This `paginate` function expects to be called with, at a minimum, an Ecto query. It will then paginate the query and execute it, returning a `Scrivener.Page`. Defaults for `page_size` can be configured when you `use` Scrivener. If no `page_size` is provided, Scrivener will use `10` by default.

You may also want to call `paginate` with a params map along with your query. If provided with a params map, Scrivener will use the values in the keys `"page"` and `"page_size"` before using any configured defaults.

Note: Scrivener.Ecto only supports Ecto backends that allow subqueries (e.g. PostgreSQL).

## Example

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
  use Scrivener, page_size: 10
end
```

```elixir
defmodule MyApp.Person do
  use Ecto.Schema

  schema "people" do
    field :name, :string
    field :age, :integer

    has_many :friends, MyApp.Person
  end
end
```

```elixir
def index(conn, params) do
  page =
    MyApp.Person
    |> where([p], p.age > 30)
    |> order_by(desc: :age)
    |> preload(:friends)
    |> MyApp.Repo.paginate(params)

  render conn, :index,
    people: page.entries,
    page_number: page.page_number,
    page_size: page.page_size,
    total_pages: page.total_pages,
    total_entries: page.total_entries
end
```

```elixir
page =
  MyApp.Person
  |> where([p], p.age > 30)
  |> order_by(desc: :age)
  |> preload(:friends)
  |> MyApp.Repo.paginate(page: 2, page_size: 5)
```

## Supported Options

There are several options that can be supplied in a dedicated `options` keyword list arg. Here is an example of using `options`...

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
  use Scrivener, options: [allow_overflow_page_number: true]
end
```

Here is an explanation of the supported options...

* `:allow_overflow_page_number` - If set to true then when you supply a page greater than the total pages, it will return an empty list for entries. If set to false then it will (silently) treat any supplied `page` arg as if it was equal to the total pages. Default is false.

## Other Configuration

The behaviour of Ecto Scrivener can also be optionally configured by passing things directly to the `use Scrivener` statement rather than via the `options` keyword list arg. For example...

```elixir
defmodule MyApp.Module do
  use Scrivener, page_size: 5, max_page_size: 100
end
```

Here is an explanation of the directly configurable keys...

* `:max_page_size` - This (silently) enforces a hard ceiling for the page size, even if you allow users of your application to specify page_size via query parameters. If not provided, there will be no limit to page size.

## Installation

Add `scrivener_ecto` to your `mix.exs` `deps`.

```elixir
defp deps do
  [
    {:scrivener_ecto, "~> 2.0"}
  ]
end
```

## Contributing

First, you'll need to build the test database.

```elixir
MIX_ENV=test mix db.reset
```

This task assumes you have postgres installed and that the `postgres` user can create / drop databases. If you'd prefer to use a different user, you can specify it with the environment variable `SCRIVENER_ECTO_DB_USER`.

With the database built, you can now run the tests.

```elixir
mix test
```
