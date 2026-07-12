class OrdersController < ApplicationController
  PER_PAGE = 10

  page Orders::IndexPage
  def index(params)
    scope = Order.order(placed_at: :desc)
    scope = scope.where(status: params.status.serialize) if params.status
    scope = scope.where("customer_name LIKE :q OR customer_email LIKE :q", q: "%#{params.query}%") if params.query

    Orders::IndexPage::Props.new(
      orders: scope.offset((params.page - 1) * PER_PAGE).limit(PER_PAGE).map { OrderDTO.from_model(it) },
      total_count: scope.count,
      page: params.page,
      per_page: PER_PAGE,
      status_counts: Order.group(:status).count
    )
  end

  page Orders::ShowPage
  def show(params)
    order = Order.find(params.id)

    Orders::ShowPage::Props.new(
      order: OrderDTO.from_model(order),
      line_items: order.line_items.order(:id).map { LineItemDTO.from_model(it) },
      activity: order.order_events.order(created_at: :desc).map { OrderEventDTOMapper.from_model(it) }
    )
  end
end
