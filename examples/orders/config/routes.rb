Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :orders, only: [ :index, :show ]
  root "orders#index"
end
