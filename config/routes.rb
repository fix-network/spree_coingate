Spree::Core::Engine.routes.draw do

  get '/spree_coingate/redirect', to: 'coingate#redirect', as: :spree_coingate_redirect
  post '/spree_coingate/callback', to: 'coingate#callback', as: :spree_coingate_callback
  get '/spree_coingate/cancel', to: 'coingate#cancel', as: :spree_coingate_cancel
  get '/spree_coingate/success', to: 'coingate#success', as: :spree_coingate_success

end
