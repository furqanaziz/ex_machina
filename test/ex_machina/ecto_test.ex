defmodule ExMachina.EctoTest do
  use ExUnit.Case, async: true

  defmodule TestRepo do
    def insert!(record) do
      send self, {:created, record}
      record
    end
  end

  defmodule MyApp.Book do
    defstruct title: nil, publisher: nil, __meta__: %{__struct__: Ecto.Schema.Metadata}, publisher_id: 1

    def __schema__(:associations) do
      [:publisher]
    end
  end

  defmodule MyApp.EctoFactories do
    use ExMachina.Ecto, repo: TestRepo

    def factory(:book) do
      %MyApp.Book{
        title: "Foo"
      }
    end

    def factory(:user) do
      %{
        id: 3,
        name: "John Doe",
        admin: false
      }
    end

    def factory(:article, attrs) do
      %{
        id: 1,
        title: "My Awesome Article",
        author_id: assoc(attrs, :author, factory: :user).id
      }
    end

    def factory(:comment, attrs) do
      %{
        body: "This is great!",
        article_id: assoc(attrs, :article).id
      }
    end
  end

  test "raises error if no repo is provided" do
    assert_raise KeyError, "key :repo not found in: []", fn ->
      defmodule MyApp.EctoWithNoRepo do
        use ExMachina.Ecto
      end
    end
  end

  test "fields_for/2 removes Ecto specific fields" do
    assert MyApp.EctoFactories.fields_for(:book) == %{
      title: "Foo",
      publisher_id: 1,
    }
  end

  test "fields_for/2 raises when passed a map" do
    assert_raise ArgumentError, fn ->
      MyApp.EctoFactories.fields_for(:user)
    end
  end

  test "save_record/1 passes the data to @repo.insert!" do
    user = MyApp.EctoFactories.save_record(:user, admin: true)

    assert user == %{id: 3, name: "John Doe", admin: true}
    assert_received {:created, %{name: "John Doe", admin: true}}
  end

  test "assoc/3 returns the passed in key if it exists" do
    existing_account = %{id: 1, plan_type: "free"}
    attrs = %{account: existing_account}

    assert MyApp.EctoFactories.assoc(MyApp.EctoFactories, attrs, :account) == existing_account
    refute_received {:custom_save, _}
  end

  test "assoc/3 creates and returns a factory if one was not in attrs" do
    attrs = %{}

    user = MyApp.EctoFactories.assoc(MyApp.EctoFactories, attrs, :user)

    created_user = %{id: 3, name: "John Doe", admin: true}
    assert user == created_user
    assert_received {:custom_save, ^created_user}
  end

  test "assoc/3 can specify a factory for the association" do
    attrs = %{}

    account = MyApp.EctoFactories.assoc(MyApp.EctoFactories, attrs, :account, factory: :user)

    newly_created_account = %{id: 3, admin: false, name: "John Doe"}
    assert account == newly_created_account
    assert_received {:custom_save, ^newly_created_account}
  end

  test "can use assoc/3 in a factory to override associations" do
    my_article = MyApp.EctoFactories.create(:article, title: "So Deep")

    comment = MyApp.EctoFactories.create(:comment, article: my_article)

    assert comment.article == my_article
  end
end
