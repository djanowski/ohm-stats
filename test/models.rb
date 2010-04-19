require "ohm"

class Post < Ohm::Model
  attribute :title
  attribute :body

  collection :comments, Comment

  index :title
end

class Comment < Ohm::Model
  attribute :text

  reference :post, Post
end
