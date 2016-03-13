Rails.application.routes.draw do
  
  resources :nodes do
    member do
      get 'show_links'
      get 'show_jacks'
    end
  end
  
  resources :links do
    member do
      get 'detect'
    end
  end
  
  resources :arpcaches
  
  resources :buildings do
    member do
      get 'show_nodes'
      get 'show_ports'
      get 'show_jacks'
    end
  end
  
  resources :events do
    member do
      get 'toggle'
    end
  end
  
  resources :ports do
    member do
      get 'detect'
      get 'delete_nonexistent'
      get 'toggle_admin'
      get 'stats'
      get 'edit_vlan'
      post 'update_vlan'
    end
  end
  
  resources :recycles
  
  resources :searches do
    collection do
      get 'by_building'
      get 'find_by_building'
      get 'by_switch'
      get 'find_by_switch'
      get 'by_vlan'
      get 'find_by_vlan'
      get 'platform'
      get 'find_by_platform'
      get 'tracker'
      post 'find_ip_mac'
    end
  end
  
  resources :logins do
    member do
      delete 'delete_user'
      get 'edit_user'
    end
    collection do
      post 'login'
      get 'logout'
      get 'no_priv'
      get 'list_users'
      post 'add_user'
    end
  end
  
  root :to => 'logins#index'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
