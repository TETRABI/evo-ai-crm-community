# frozen_string_literal: true

# CategorySerializer - Optimized serialization for Category resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   CategorySerializer.serialize(@category, include_articles: true)
#
module CategorySerializer
  extend self

  # Serialize single Category
  #
  # @param category [Category] Category to serialize
  # @param options [Hash] Serialization options
  # @option options [Boolean] :include_articles Include articles
  #
  # @return [Hash] Serialized category ready for Oj
  #
  def serialize(category, include_articles: false)
    result = {
      id: category.id,
      name: category.name,
      description: category.description,
      slug: category.slug,
      locale: category.locale,
      position: category.position,
      portal_id: category.portal_id,
      account_id: category.account_id,
      created_at: category.created_at&.iso8601,
      updated_at: category.updated_at&.iso8601
    }

    # Include articles if loaded
    if include_articles && category.association(:articles).loaded?
      result[:articles] = ArticleSerializer.serialize_collection(category.articles)
    end

    result
  end

  # Serialize collection of Categories
  #
  # @param categories [Array<Category>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized categories
  #
  def serialize_collection(categories, **options)
    return [] unless categories

    categories.map { |category| serialize(category, **options) }
  end
end
