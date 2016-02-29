class EventsController < ApplicationController
  before_filter :authenticate
  before_filter :authorize

  def index
    @title = 'All Port Events'
    @events = Event.all.page(params[:page])
  end
  
  # the update action expects the port object's id and a status flag to be
  # passed as
  # parameters. The status flag is either 1 (enable) or 2 (disable), and
  # indicates the ports new Admin status.
  def toggle
    @port = Port.find params[:id]
    @status = params[:new_status].to_i
    
#     byebug
    
    case @status
    when 1 # cuerently disabled
      # Look for an event for the port (switch IP, ifName) that doesn't have
      # the WhenEnabled and WhoEnabled fields filled.
      @events = Event.where("port_id = ? and whenEnabled is NULL and whoEnabled is NULL", @port.id)
      if @events.nil?
        flash[:notice] = "#{@port.node.ip}:#{@port.ifName} is not in PortAdmin's Events database"
      else
        @events.each do |e|
          e.whenEnabled = Time.now
          e.whoEnabled = User.find(session[:user_id]).name
          e.save
        end
      end
    when 2 #currently enabled
      # Create a new event
      @event = Event.new
      @event.port_id = @port.id
      @event.whoDisabled = User.find(session[:user_id]).name
      @event.whenDisabled = Time.now
      @event.comment = "Disabled via Netmap;"
      unless @port.building_id.nil?
        @event.comment += "Jack: #{@port.label} Bldg: #{@port.building.short_name}"
      end
      @event.save
    else
      flash[:error] = "Don't know how to handle status = #{@status}"
    end
    redirect_to :back
  end
end
