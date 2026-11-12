defmodule AshSurface.Ported.RpcRunActionUnionCalculationSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_union_calculation_test.exs`: the `item` union
  calculation (struct member `article`) is carried as a loaded `%Ash.Union{}` on hand-built
  `Content` structs; field selection through the union is performed by the result processor.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Article, Content, Rpc}

  @cid "55555555-5555-5555-5555-555555555501"

  defp content(attrs) do
    {article_attrs, attrs} = Keyword.pop(attrs, :article, [])

    article =
      struct(
        Article,
        Keyword.merge(
          [
            id: "66666666-6666-6666-6666-666666666601",
            hero_image_url: "https://example.com/hero.jpg",
            hero_image_alt: "Hero Image",
            summary: "Test summary",
            body: "Test body content"
          ],
          article_attrs
        )
      )

    struct(
      Content,
      Keyword.merge(
        [
          id: @cid,
          title: "Test Content",
          thumbnail_url: "https://example.com/thumb.jpg",
          thumbnail_alt: "Thumbnail",
          category: :nutrition,
          item: %Ash.Union{type: :article, value: article}
        ],
        attrs
      )
    )
  end

  defp nutrition do
    content(
      title: "Understanding Nutrition",
      thumbnail_url: "https://example.com/nutrition-thumb.jpg",
      thumbnail_alt: "Nutrition thumbnail",
      published_at: ~U[2024-01-15 10:00:00Z],
      article: [
        hero_image_url: "https://example.com/nutrition-hero.jpg",
        hero_image_alt: "Nutrition hero image",
        summary: "A comprehensive guide to nutrition",
        body: "Detailed article body about nutrition and healthy eating."
      ]
    )
  end

  defp get(fields),
    do:
      Rpc.run(
        %{"action" => "get_content", "input" => %{"id" => @cid}, "fields" => fields},
        nutrition()
      )

  defp item(article_fields),
    do: %{"item" => %{"args" => %{}, "fields" => [%{"article" => article_fields}]}}

  describe "union calculation with resource members - get_content" do
    test "fetches content fields only when item calculation is not requested" do
      result = get(["id", "title", "thumbnailUrl", "thumbnailAlt", "category"])
      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @cid
      assert data["title"] == "Understanding Nutrition"
      assert data["thumbnailUrl"] == "https://example.com/nutrition-thumb.jpg"
      assert data["thumbnailAlt"] == "Nutrition thumbnail"
      assert data["category"] == "nutrition"
      refute Map.has_key?(data, "item")
    end

    test "fetches article fields through item calculation" do
      result = get(["id", "title", item(["heroImageUrl", "heroImageAlt", "summary", "body"])])
      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @cid
      assert data["title"] == "Understanding Nutrition"
      assert is_map(data["item"])
      article = data["item"]["article"]
      assert article["heroImageUrl"] == "https://example.com/nutrition-hero.jpg"
      assert article["heroImageAlt"] == "Nutrition hero image"
      assert article["summary"] == "A comprehensive guide to nutrition"
      assert article["body"] == "Detailed article body about nutrition and healthy eating."
    end

    test "fetches subset of article fields through item calculation" do
      result = get(["id", item(["summary"])])
      assert result["success"] == true
      article = result["data"]["item"]["article"]
      assert article["summary"] == "A comprehensive guide to nutrition"
      refute Map.has_key?(article, "heroImageUrl")
      refute Map.has_key?(article, "heroImageAlt")
      refute Map.has_key?(article, "body")
    end

    test "fetches both content and article fields together" do
      result =
        get([
          "id",
          "title",
          "thumbnailUrl",
          "category",
          "publishedAt",
          item(["heroImageUrl", "summary"])
        ])

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @cid
      assert data["title"] == "Understanding Nutrition"
      assert data["thumbnailUrl"] == "https://example.com/nutrition-thumb.jpg"
      assert data["category"] == "nutrition"
      assert data["publishedAt"] == "2024-01-15T10:00:00Z"
      article = data["item"]["article"]
      assert article["heroImageUrl"] == "https://example.com/nutrition-hero.jpg"
      assert article["summary"] == "A comprehensive guide to nutrition"
      refute Map.has_key?(article, "heroImageAlt")
      refute Map.has_key?(article, "body")
    end
  end

  describe "union calculation with resource members - list_content" do
    defp contents do
      [
        content(
          id: "55555555-5555-5555-5555-555555555511",
          title: "Nutrition Basics",
          category: :nutrition,
          article: [summary: "Introduction to nutrition", body: "Basic nutrition concepts"]
        ),
        content(
          id: "55555555-5555-5555-5555-555555555512",
          title: "Fitness Guide",
          category: :fitness,
          article: [summary: "Guide to fitness", body: "Comprehensive fitness guide"]
        ),
        content(
          id: "55555555-5555-5555-5555-555555555513",
          title: "Mindset Matters",
          category: :mindset,
          article: [summary: "Mental health and mindset", body: "Building a healthy mindset"]
        )
      ]
    end

    test "lists content with article fields through item calculation" do
      result =
        Rpc.run(
          %{
            "action" => "list_content",
            "fields" => ["id", "title", "category", item(["summary"])]
          },
          contents()
        )

      assert result["success"] == true
      data = result["data"]
      assert length(data) == 3

      Enum.each(data, fn c ->
        assert Map.has_key?(c, "id")
        assert Map.has_key?(c, "title")
        assert Map.has_key?(c, "category")
        article = c["item"]["article"]
        assert Map.has_key?(article, "summary")
        refute Map.has_key?(article, "heroImageUrl")
        refute Map.has_key?(article, "body")
      end)

      assert data |> Enum.map(& &1["title"]) |> Enum.sort() ==
               ["Fitness Guide", "Mindset Matters", "Nutrition Basics"]

      assert data |> Enum.map(&get_in(&1, ["item", "article", "summary"])) |> Enum.sort() ==
               [
                 "Guide to fitness",
                 "Introduction to nutrition",
                 "Mental health and mindset"
               ]
    end

    test "lists content with multiple article fields" do
      result =
        Rpc.run(
          %{
            "action" => "list_content",
            "fields" => ["id", "title", item(["heroImageUrl", "summary", "body"])]
          },
          contents()
        )

      assert result["success"] == true
      first = Enum.find(result["data"], &(&1["title"] == "Nutrition Basics"))
      article = first["item"]["article"]
      assert article["heroImageUrl"] == "https://example.com/hero.jpg"
      assert article["summary"] == "Introduction to nutrition"
      assert article["body"] == "Basic nutrition concepts"
    end

    test "lists content without item calculation when not requested" do
      result =
        Rpc.run(
          %{"action" => "list_content", "fields" => ["id", "title", "category"]},
          contents()
        )

      assert result["success"] == true
      Enum.each(result["data"], fn c -> refute Map.has_key?(c, "item") end)
    end
  end
end
