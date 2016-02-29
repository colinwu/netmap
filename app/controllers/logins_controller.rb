class LoginsController < ApplicationController
  before_filter :authenticate, :except => [:login, :index, :no_priv, :logout]
  before_filter :authorize, :except => [:login, :index, :no_priv, :logout]

  # Functions that do not require authentication or authorization

  def index
    render :action => 'index', :layout => 'admin'
  end

  def no_priv
  end

  def login
    session[:user_id] = nil
    if request.post?
      user = User.authenticate(params[:name], params[:password])
      if user
        session[:user_id] = user.id
        session[:user_level] = user.level
        log("#{user.name} logged in")
        redirect_to (session[:return_to] || {:action => 'index', :controller => '/'})
      else
        flash[:notice] = "Invalid user/password combination"
        logger.warn(Time.now.to_s + ": Failed login: #{params[:name]}/#{params[:password]}")
      end
    end
  end

  def logout
    user = User.find(session[:user_id])
    log("#{user[:name]} logged out")
    session[:user_id] = nil
    session[:return_to] = nil
    session[:user_level] = nil
    redirect_to :action => 'index', :controller => '/'
  end

  # Privileged fucnctions: must be authenticated and authorized to perform

  def new
    @user = User.new
  end

  def add_user
    @user = User.new(params[:user])
    if request.post? and @user.save
      flash[:notice] = "User #{@user.name} created"
      # @user = User.new
      log("#{@user.name} added")
      redirect_to :action => 'list_users'
    else
      render :action => 'add_user'
    end
  end

  def edit_user
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if (params[:user][:password].length == 0)
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end
    if @user.update_attributes(params[:user])
      me = User.find(session[:user_id])
      logger.info(Time.now.to_s + ": #{@user.name} updated by #{me[:name]}")
      flash[:notice] = "User #{@user.name} updated"
      redirect_to :action => 'list_users'
    else
      render :action => 'edit_user'
    end

  end

  def delete_user
    id = params[:id]
    if id && user = User.find(id)
      begin
        user.safe_delete
        log("#{@user.name} deleted")
        flash[:notice] = "User #{user.name} deleted"
      rescue Exception => e
        flash[:notice] = e.message
      end
    end
    redirect_to :action => 'list_users'
  end

  def list_users
    @all_users = User.all.order(:name)
  end
end
