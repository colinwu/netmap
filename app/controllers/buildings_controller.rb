class BuildingsController < ApplicationController

  before_filter :authenticate
  before_filter :authorize, :except => [:index, :show_nodes, :show_jacks, :show_ports]

#   in_place_edit_for :port, :label
#   in_place_edit_for :port, :comment
#   in_place_edit_for :port, :vlan

  def index
    @building = Building.all.order('long_name ASC')
  end

  def new
    @building = Building.new
  end

  def create
    @building = Building.new(building_params)
    if @building.save
      log("building '#{@building.long_name}' added")
      flash[:notice] = "New building added"
      redirect_to :action => 'index'
    else
      render :action => 'new'
    end
  end

  def edit
    @building = Building.find(params[:id])
  end

  def update
    @building = Building.find(params[:id])
    if @building.update_attributes(building_params)
      flash[:notice] = "Update successful"
      if (session[:return_to].empty?)
        redirect_to :action => 'index'
      else
        redirect_to session[:return_to]
      end
    else
      render :action => 'edit'
    end
  end

  def destroy
    @building = Building.find(params[:id])
    long_name = @building.long_name
    if (@building.destroy)
      log("building '#{@building.long_name}' removed")
      flash[:notice] = long_name + " removed"
    end
    redirect_to :action => 'index'
  end

  def show_nodes
    @building = Building.find(params[:id])
    @nodes = @building.nodes.find :all, :group => 'sysName'
    @title = "Switches in " + @building.long_name
  end

  def show_jacks
    @building = Building.find params[:id]
    @order = params[:order]
    @jacks = @building.ports.all.order((params[:order].nil? || params[:order] =~ /ip/i) ? 'label' : params[:order])
    @title = "Jacks in " + @building.long_name
  end

  def jackscsv
    @building = Building.find params[:id]
    @order = params[:order]
    @jacks = @building.ports.all.order((params[:order].nil? || params[:order] =~ /ip/i) ? 'label' : params[:order])
    @title = "Jacks in " + @building.long_name
  end

  def show_ports
    @ports = Array.new
    @adminStatus = Hash.new
    @opStatus = Hash.new
    @building = Building.find params[:id]
    @order = params[:order]
    @nodes = @building.nodes.all.group('sysName')
    @nodes.each do |n|
      myports = n.ports.where("ifName not like 'VL%' and ifName not like 'Nu%'").order(:ifIndex)
      @ports.concat(myports)
      if n.commStr != '**UNKNOWN**'
        begin
          n.snmpwalk('IF-MIB::ifAdminStatus').each do |oid, val|
            /(\d+)$/.match(oid)
            pid = n.ports.find_by_ifIndex($1).id
            @adminStatus[pid] = val.to_i
          end
          n.snmpwalk('IF-MIB::ifOperStatus').each do |oid, val|
            /(\d+)$/.match(oid)
            pid = n.ports.find_by_ifIndex($1).id
            @opStatus[pid] = val.to_i
          end
        rescue
          # Not able to get port status via SNMP - maybe the switch is down.
          n.ports.each do |p|
            @adminStatus[p.id] = 0
            @opStatus[p.id] = 0
          end
        end
      else
        myports.each do |p|
          @adminStatus[p.id] = 0
          @opStatus[p.id] = 0
        end
      end
    end
#    @ports.flatten!
    @title = "Ports in #{@building.long_name}"
  end

  def portscsv
    @ports = Array.new
    @building = Building.find params[:id]
    @nodes = @building.nodes.all.group('sysName')
    @nodes.each do |n|
      @ports << n.ports.where("ifName not like 'VL%' and ifName not like 'Nu%'").order(:ifIndex)
    end
    @title = "Ports in #{@building.long_name}"
  end

  private

  def building_params
    params.require(:building).permit(:long_name, :short_name, :bldg_number)
  end
end