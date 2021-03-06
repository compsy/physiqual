Physiqual::Engine.routes.draw do
  resources :exports, only: [:index]
  get 'exports/providers/:provider/data_sources/:data_source', :to => 'exports#raw'

  get 'auth/:provider/authorize', :to => 'sessions#authorize', as: 'authorize'
  get 'auth/:provider/callback',  :to => 'sessions#create', as: 'callback'
  get 'auth/failure',             :to => 'sessions#failure', as: 'failure'

  if Rails.env.development?
    get 'test', to: 'test_login#index'
    post 'test', to: 'test_login#create'
  end
end
