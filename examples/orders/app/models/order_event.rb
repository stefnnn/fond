class OrderEvent < ApplicationRecord
  KINDS = %w[status_change note].freeze

  belongs_to :order

  validates :kind, inclusion: { in: KINDS }
end
