class Order < ApplicationRecord
  STATUSES = %w[pending paid shipped cancelled].freeze

  has_many :line_items, dependent: :destroy
  has_many :order_events, dependent: :destroy

  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email" }
  validates :status, inclusion: { in: STATUSES }

  def recalculate_total!
    update!(total_cents: line_items.sum("quantity * unit_price_cents"))
  end
end
