Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :webhooks do
    resource :whatsapp, only: [], controller: "whatsapp" do
      get "/", action: :verify, on: :collection
      post "/", action: :receive, on: :collection
    end
    resource :razorpay, only: [], controller: "razorpay" do
      get "/", action: :payment_callback, on: :collection
    end
    resource :delhivery, only: [], controller: "delhivery" do
      post "/", action: :receive, on: :collection
    end
  end

  devise_for :sellers, controllers: {
    sessions: "sellers/sessions",
    registrations: "sellers/registrations",
    passwords: "sellers/passwords"
  }

  root "pages#home"

  authenticate :seller do
    get "dashboard", to: "orders#index", as: :dashboard
    resources :orders, only: [ :index, :new, :create, :show ] do
      collection do
        post :parse
        get :manual
      end
      member do
        post :override_risk
        post :cancel_order
        post :ship
        post :fetch_label
      end
    end
    resource :account, only: [ :show, :edit, :update ], controller: "account" do
      post :retry_delhivery_registration, on: :member
    end
  end
end
