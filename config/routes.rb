Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :webhooks do
    resource :whatsapp, only: [], controller: "whatsapp" do
      get "/", action: :verify, on: :collection
      post "/", action: :receive, on: :collection
    end
    resource :razorpay, only: [], controller: "razorpay" do
      get "/", action: :payment_callback, on: :collection
    end
  end

  devise_for :sellers, **{
    controllers: {
      sessions: "sellers/sessions",
      registrations: "sellers/registrations",
      passwords: "sellers/passwords"
    }
  }

  root "pages#home"

  get "/terms", to: "pages#terms", as: :terms
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/refund", to: "pages#refund", as: :refund
  get "/cookies", to: "pages#cookies", as: :cookies
  get "/shipping-policy", to: "pages#shipping_policy", as: :shipping_policy

  authenticate :seller do
    get "dashboard", to: "orders#index", as: :dashboard
    resources :orders, only: [ :index, :new, :create, :show, :update ] do
      collection do
        post :parse
        get :manual
      end
      member do
        post :override_risk
        post :cancel_order
      end
    end
    resources :products, except: [:show]
    resources :buyers, only: [:index]
    resource :whatsapp, only: [:show], controller: "whatsapp"
    post "whatsapp/embedded_signup_complete", to: "whatsapp#embedded_signup_complete", as: :whatsapp_embedded_signup_complete
    resource :account, only: [ :show, :edit, :update ], controller: "account"
  end
end
