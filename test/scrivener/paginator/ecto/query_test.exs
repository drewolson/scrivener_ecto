defmodule Scrivener.Paginator.Ecto.QueryTest do
  use Scrivener.Ecto.TestCase
  import ExUnit.CaptureLog
  alias Scrivener.Ecto.{Comment, KeyValue, Post, User}

  defp create_posts do
    unpublished_post =
      %Post{
        title: "Title unpublished",
        body: "Body unpublished",
        published: false
      }
      |> Scrivener.Ecto.Repo.insert!()

    Enum.map(1..2, fn i ->
      %Comment{
        body: "Body #{i}",
        post_id: unpublished_post.id
      }
      |> Scrivener.Ecto.Repo.insert!()
    end)

    Enum.map(1..6, fn i ->
      %Post{
        title: "Title #{i}",
        body: "Body #{i}",
        published: true
      }
      |> Scrivener.Ecto.Repo.insert!()
    end)
  end

  defp create_key_values do
    Enum.map(1..10, fn i ->
      %KeyValue{
        key: "key_#{i}",
        value: rem(i, 2) |> to_string
      }
      |> Scrivener.Ecto.Repo.insert!()
    end)
  end

  defp create_users(number, prefix) do
    Enum.map(1..number, fn i ->
      %User{email: "user_#{i}@#{prefix}.com"}
      |> Scrivener.Ecto.Repo.insert!(prefix: prefix)
    end)
  end

  describe "paginate" do
    test "paginates an unconstrained query" do
      create_posts()

      page = Post |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "page information is correct with no results" do
      page = Post |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 0
      assert page.total_pages == 1
    end

    test "uses defaults from the repo" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.entries == Enum.take(posts, 5)
      assert page.total_entries == 6
      assert page.total_pages == 2
    end

    test "it handles preloads" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> preload(:comments)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_pages == 2
    end

    test "it handles offsets" do
      create_posts()

      page =
        Post
        |> Post.unpublished()
        |> Scrivener.Ecto.Repo.paginate(options: [offset: 1])

      assert page.entries |> length == 0
      assert page.page_number == 1
      assert page.total_pages == 1

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(options: [offset: 2])

      assert page.entries |> length == 4
      assert page.page_number == 1
      assert page.total_pages == 2
    end

    test "it handles complex selects" do
      create_posts()

      page =
        Post
        |> join(:left, [p], c in assoc(p, :comments))
        |> group_by([p], p.id)
        |> select([p], sum(p.id))
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "it handles complex order_by" do
      create_posts()

      page =
        Post
        |> select([p], fragment("? as aliased_title", p.title))
        |> order_by([p], fragment("aliased_title"))
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "can be provided the current page and page size as a params map" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(%{"page" => "2", "page_size" => "3"})

      assert page.page_size == 3
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 3)
      assert page.total_pages == 2
    end

    test "can be provided the current page and page size as options" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page: 2, page_size: 3)

      assert page.page_size == 3
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 3)
      assert page.total_pages == 2
    end

    test "can be provided the caller as options" do
      create_posts()
      parent = self()

      task =
        Task.async(fn ->
          Post
          |> Scrivener.Ecto.Repo.paginate(caller: parent)
        end)

      page = Task.await(task)

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "can be provided the caller as a map" do
      create_posts()

      parent = self()

      task =
        Task.async(fn ->
          Post
          |> Scrivener.Ecto.Repo.paginate(%{"caller" => parent})
        end)

      page = Task.await(task)

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "will respect the max_page_size configuration" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(%{"page" => "1", "page_size" => "20"})

      assert page.page_size == 10
    end

    test "will respect total_entries passed to paginate" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(options: [total_entries: 130])

      assert page.total_entries == 130
    end

    test "will use total_pages if page_numer is too large" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page: 3)

      assert page.page_number == 2
      assert page.entries == posts |> Enum.reverse() |> Enum.take(1)
    end

    test "allows overflow page numbers if option is specified" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(
          page: 3,
          options: [allow_overflow_page_number: true]
        )

      assert page.page_number == 3
      assert page.entries == []
    end

    test "can be used on a table with any primary key" do
      create_key_values()

      page =
        KeyValue
        |> KeyValue.zero()
        |> Scrivener.Ecto.Repo.paginate(page_size: 2)

      assert page.total_entries == 5
      assert page.total_pages == 3
    end

    test "can be used with a group by clause" do
      create_posts()

      page =
        Post
        |> join(:left, [p], c in assoc(p, :comments))
        |> group_by([p], p.id)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "can be used with a group by clause on field other than id" do
      create_posts()

      page =
        Post
        |> group_by([p], p.body)
        |> select([p], p.body)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "can be used with a group by clause on field on joined table" do
      create_posts()

      page =
        Post
        |> join(:inner, [p], c in assoc(p, :comments))
        |> group_by([p, c], c.body)
        |> select([p, c], {c.body, count("*")})
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 2
    end

    test "can be used with compound group by clause" do
      create_posts()

      page =
        Post
        |> join(:inner, [p], c in assoc(p, :comments))
        |> group_by([p, c], [c.body, p.title])
        |> select([p, c], {c.body, p.title, count("*")})
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 2
    end

    test "can be provided a Scrivener.Config directly" do
      posts = create_posts()

      config = %Scrivener.Config{
        module: Scrivener.Ecto.Repo,
        page_number: 2,
        page_size: 4,
        options: []
      }

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(config)

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 4)
      assert page.total_pages == 2
    end

    test "can be provided a keyword directly" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(module: Scrivener.Ecto.Repo, page: 2, page_size: 4)

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 4)
      assert page.total_pages == 2
    end

    test "can be provided a map directly" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(%{"module" => Scrivener.Ecto.Repo, "page" => 2, "page_size" => 4})

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 4)
      assert page.total_pages == 2
    end

    test "pagination plays nice with distinct on in the query" do
      create_posts()

      page =
        Post
        |> distinct([p], asc: p.title, asc: p.inserted_at)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "pagination plays nice with absolute distinct in the query" do
      create_posts()

      page =
        Post
        |> distinct(true)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "pagination plays nice with a singular distinct in the query" do
      create_posts()

      page =
        Post
        |> distinct(:id)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "pagination plays nice with absolute distinct on a join query" do
      create_posts()

      page =
        Post
        |> distinct(true)
        |> join(:inner, [p], c in assoc(p, :comments))
        |> Scrivener.Ecto.Repo.paginate()

      assert length(page.entries) == 1
      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 1
      assert page.total_pages == 1
    end

    test "can specify prefix" do
      create_users(6, "tenant_1")
      create_users(2, "tenant_2")

      page_tenant_1 = Scrivener.Ecto.Repo.paginate(User, options: [prefix: "tenant_1"])

      assert page_tenant_1.page_size == 5
      assert page_tenant_1.page_number == 1
      assert page_tenant_1.total_entries == 6
      assert page_tenant_1.total_pages == 2

      page_tenant_2 = Scrivener.Ecto.Repo.paginate(User, options: [prefix: "tenant_2"])

      assert page_tenant_2.page_size == 5
      assert page_tenant_2.page_number == 1
      assert page_tenant_2.total_entries == 2
      assert page_tenant_2.total_pages == 1
    end

    test "accepts repo options" do
      log = capture_log(fn -> Scrivener.Ecto.Repo.paginate(Post, options: [log: true]) end)

      assert log =~
               "SELECT p0.\"id\", p0.\"title\", p0.\"body\", p0.\"published\", p0.\"inserted_at\", p0.\"updated_at\" FROM \"posts\" AS p0 LIMIT $1 OFFSET $2"

      log = capture_log(fn -> Scrivener.Ecto.Repo.paginate(Post, options: [log: false]) end)
      assert log == ""
    end
  end
end
