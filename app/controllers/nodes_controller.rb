class NodesController < ApplicationController
 before_filter :authenticate
 before_filter :authorize, :except => [:index, :show_jacks, :show_links]

#  in_place_edit_for :port, :label
#  in_place_edit_for :port, :comment
#  in_place_edit_for :port, :vlan

  def index
    @title = "List Switches and Routers"
    @order = params[:order]
    if params[:sysname].nil? && params[:ip].nil? && params[:platform].nil? && params[:commstr].nil?
      where = 1
    else
      unless params[:ip].nil?
        @s_ip = params[:ip]
        where = "ip regexp '#{@s_ip}'"
      end
      unless params[:sysname].nil?
        @s_sysname = params[:sysname]
        where = "sysname regexp '#{@s_sysname}'"
      end
      unless params[:platform].nil?
        @s_platform = params[:platform]
        where = "platform regexp '%#{@s_platform}'"
      end
      unless params[:commstr].nil? or session[:user_id].nil?
        @s_commstr = params[:commstr]
        where = "commStr regexp '#{@s_commstr}'"
      end
    end
    @nodes = Node.where(where).select('*,INET_ATON(ip) AS bin_ip').order(params[:order].nil? ? 'sysName' : params[:order]).paginate(:page => params[:page])
  end

  def new
    @title = "Add New Device"
    if session[:user_level] == 0
      @building = Building.all.order('long_name').collect do |b|
        [b.long_name, b.id]
      end
      @node = Node.new
      @node.commStr = '**UNKNOWN**'
    else
      redirect_to :action => 'no_priv', :controller => 'logins'
    end
  end

  def create
    @node = Node.new(node_params)
    if (@node.save)
      if (@node.commStr != '**UNKNOWN**')
        @node.get_ifindex
        @node.ports.each do |p|
          p.building_id = params[:port][:building_id]
          p.save
        end
        @node.get_platform
        @node.save
      end
      flash[:notice] = "New switch added"
      log("New switch added")
      redirect_to show_links_node_path(@node)
    else
      if session[:user_level] == 0
        @building = Building.all.order('long_name').collect do |b|
          [b.long_name, b.id]
        end
      end
      render :action => 'new'
    end
  end

  def edit
    @node = Node.find(params[:id])
    @building = Building.all.order('short_name').collect do |b|
      ["#{b.short_name} - #{b.long_name}", b.id]
    end
    @title = "Editing #{@node.sysName}"
  end

  def update
    @node = Node.find(params[:id])
    if (@node.update_attributes(node_params))
      if @node.commStr != '**UNKNOWN**'
        @node.get_ifindex
        unless params[:port][:building_id].blank?
          @node.ports.each do |p|
            p.building_id = params[:port][:building_id]
            p.save
          end
        end
        @node.get_platform
        @node.save
      end
      flash[:notice] = "Update successful"
      unless session[:return_to].empty?
        redirect_to session[:return_to]
      else
        redirect_to :action => 'index'
      end
    else
      render :action => 'edit'
    end
  end

  def destroy
    @node = Node.find(params[:id])
    @ports = Port.where("node_id = '#{@node.id}'")
    @ports.each do |p|
      @links = p.links
      if not @links.nil?
        @links.each do |l|
          rl = Link.where("port_a_id = '#{l.port_b_id}'").first
          rl.destroy if not rl.nil?
          l.destroy
        end
      end
      p.destroy
    end
    if (@node.destroy)
      flash[:notice] = "Device #{@node.sysName} removed"
    end
    log("#{@node.sysName} and all associated ports deleted.")
    redirect_to :back
#     if (session[:return_to].nil?)
#       redirect_to :action => 'index'
#     else
#       redirect_to session[:return_to]
#     end
  end

  def show_links
    @node = Node.find params[:id]
    @port = Port.where(["node_id = ?",params[:id]]).order('ifIndex')
  end

  def show_jacks
    @adminStatus = Hash.new
    @opStatus = Hash.new
    @node = Node.find(params[:id])
    @ports = @node.ports.all.order('ifIndex')
    if @node.commStr != '**UNKNOWN**'
      begin
        @node.snmpwalk('IF-MIB::ifAdminStatus').each do |oid, val|
          oid.match(/\.(\d+)$/)
          pid = @node.ports.find_by_ifIndex($1).id
          @adminStatus[pid] = val.to_i
        end
        @node.snmpwalk('IF-MIB::ifOperStatus').each do |oid, val|
          oid.match(/\.(\d+)$/)
          pid = @node.ports.find_by_ifIndex($1).id
          @opStatus[pid] = val.to_i
        end
      rescue
        @node.ports.each do |p|
          @adminStatus[p.id] =  0
          @opStatus[p.id] = 0
        end
      end
    else
      @ports.each do |p|
        @adminStatus[p.id] = 0
        @opStatus[p.id] = 0
      end
    end
  end

  def find_mac_address
    tmp_array = Array.new
    # Find all vlans on the switch
    @node = Node.find(params[:id])
    mac_addr = params[:raw_mac].tr('^0-9a-fA-F','')
    mac_addr.unpack('a2a2a2a2a2a2').each do |h|
      tmp_array << h.hex
    end
    mac_str = tmp_array.join('.')

    @node.snmpwalk('vtpVlanName').each do |oid,name|
      oid =~ /\.(\d+)$/
      vlan = $1.to_i
      unless (vlan == 1 or vlan == 1002 or vlan == 1003 or vlan == 1004 or vlan == 1005)
        pw = @node.commStr+'@'+vlan.to_s
        fdPort = @node.snmpget('dot1dTpFdbPort.'+mac_str,pw)
        if (fdPort != SNMP::NoSuchInstance and !fdPort.nil?)
          port = @node.snmpget('dot1dBasePortIfIndex.'+fdPort.to_s,pw).to_s
          type = @node.snmpget('IF-MIB::ifType.'+port).to_s
          if (type == '53')
            @node.snmpwalk('pagpGroupIfIndex').each do |oid,vif|
              if (vif == port)
                oid =~ /\.(\d+)$/
                physif = $1
                vlanStr = @node.snmpget('IF-MIB::ifName.'+physif,pw)
                if (vlanStr =~ /^v.+(\d+)$/)
                  @portName = $1
                  @portIfIndex = physif.to_i
                end
                break
              end
            end
          else
            @port = @node.ports.find_by_ifIndex(port)
          end
          redirect_to :controller => 'ports', :action => 'stats', :id => @port
          break
        end
      end
    end
    @title = "MAC address #{params[:raw_mac]} not found on this device"
  end
  
  private
  
  def node_params
    params.require(:node).permit(:sysName, :ip, :commStr, :writeStr, :platform, :capability)
  end
  
end
