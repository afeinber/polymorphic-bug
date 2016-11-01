begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"
  gem "rails", github: "rails/rails"
  gem "sqlite3"
  gem "database_cleaner"
  gem "pry"
end

require "active_record"
require "minitest/autorun"
require "logger"
require "database_cleaner"
require "pry"

DatabaseCleaner.strategy = :truncation

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table "cards", force: true do |t|
    t.string   "cardable_type"
    t.integer  "cardable_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.index ["cardable_type", "cardable_id"], name: "index_cards_on_cardable_type_and_cardable_id", using: :btree
  end

  create_table "decks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "hands", force: :cascade do |t|
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end
end

class Card < ActiveRecord::Base
  belongs_to :cardable, polymorphic: true
end

class Deck < ActiveRecord::Base
  has_many :cards, as: :cardable

  def pop
    last_card = self.cards.last
    self.cards = self.cards - [last_card]
    last_card
  end
end

class Hand < ActiveRecord::Base
  belongs_to :round
  has_many :cards, as: :cardable
end

class BugTest < Minitest::Test
  def test_with_id_one
    DatabaseCleaner.clean

    deck = Deck.new
    deck.cards << Card.new
    deck.cards << Card.new
    deck.save!

    hand_1 = Hand.new(cards: [
      deck.pop
    ])
    hand_2 = Hand.new(cards: [
      deck.pop
    ])

    hand_1.save!
    hand_2.save!

    # ID is 2. It works.
    assert_equal 1, hand_2.reload.cards.size
    # ID is 1. Not working. Actual value here is 0.
    assert_equal 1, hand_1.reload.cards.size
  end

  def test_with_id_one_thousand
    DatabaseCleaner.clean

    deck = Deck.new
    deck.cards << Card.new
    deck.cards << Card.new
    deck.save!

    # set the starting ID to 1000
    hand_1 = Hand.new(id: 1000, cards: [
      deck.pop
    ])
    hand_2 = Hand.new(cards: [
      deck.pop
    ])

    hand_1.save!
    hand_2.save!

    # ID is 1001. It works.
    assert_equal 1, hand_2.reload.cards.size
    # ID is 1000. Also works.
    assert_equal 1, hand_1.reload.cards.size
  end
end
