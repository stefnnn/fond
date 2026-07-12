Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :orders, only: [ :index, :show, :new, :create, :destroy ] do
    member do
      patch :update_status
      post :add_note
    end
  end
  root "orders#index"
end
