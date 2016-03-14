class PortsController < ApplicationController
  before_filter :authenticate
  before_filter :authorize, :except => :index

#   in_place_edit_for :port, :ifName
  # in_place_edit_for :port, :vlan
#   in_place_edit_for :port, :comment
#   in_place_edit_for :port, :label

  def index
    @title = 'Ports and Jacks'
    @node = Node.all.order('sysName')
    @building = Building.all.order('long_name').collect do |b|
      [b.id, b.long_name]
    end
  end

  def new
    @port = Port.new
    @building = Building.all.order('long_name').collect do |b|
      [b.long_name, b.id]
    end
  end

  def create
    @port = Port.create(port_params)
    if @port.nil?
      flash[:error] = 'Error creating port ' + @port.node.sysName + ':' + @port.ifName
      render :action => 'new'
    else
      flash[:notice] = 'New port created'
      unless session[:return_to].empty?
        redirect_to session[:return_to]
      else
        redirect_to :action => 'index'
      end
    end
  end

  def edit
    unless session[:user_level] == 0
      flash[:error] = "Access denied. Update not permitted."
      redirect_to session[:return_to]
    else
      @port = Port.find(params[:id])
      @building = Building.all.order('long_name').collect do |b|
        [b.long_name, b.id]
      end
      if @port.building.nil?
        @building_id = 0
      else
        @building_id = @port.building_id
      end
      @vlanOptions = Array.new
      @port.node.snmpwalk('CISCO-VTP-MIB::vtpVlanName').each do |oid,name|
        oid =~ /\.(\d+)$/
        vlan = $1.to_i
#         unless vlan == 1 or vlan == 1002 or vlan == 1003 or vlan == 1004 or vlan == 1005
          @vlanOptions << ["#{vlan} - #{name}", vlan]
#         end
      end
    end
  end

  def update
    unless session[:user_level] == 0
      flash[:error] = "Access denied. Update not permitted."
      redirect_to session[:return_to]
    else
      @port = Port.find(params[:id])
      if @port.vlan != params[:port][:vlan].to_i
        if @port.snmpset('vmVlan',params[:port][:vlan].to_i).nil?
          params[:port].delete(:vlan)
          flash[:error] = $smmpError
        end
      end
      if @port.comment != params[:port][:comment]
        if @port.snmpset('ifAlias',params[:port][:comment]).nil?
          params[:port].delete(:comment)
          flash[:error] = $snmpError
        end
      end
      respond_to do |format|
        if @port.update_attributes(port_params)
          format.html {redirect_to((session[:return_to] || ports_path), :notice => "Update successful") }
          format.json {respond_with_bip(@port)}
        else
          format.html {render :action => 'edit'}
          format.json {respond_with_bip(@port)}
        end
      end
    end
  end

  def edit_vlan
    unless session[:user_level] == 0
      flash[:error] = "Access denied. Update not permitted."
    else
      @port = Port.find(params[:id])
      @title = "Change Vlan Assignment for #{@port.node.sysName} #{@port.ifName}"
      # make sure the port is not a trunk
      temp = @port.snmpget('vmVlan').to_s
      if temp == SNMP::NoSuchInstance
        flash[:error] = "This port is a trunk. You can not assign a vlan to it."
      else
        @vlanOptions = Array.new
        @port.node.snmpwalk('CISCO-VTP-MIB::vtpVlanName').each do |oid,name|
          oid =~ /\.(\d+)$/
          vlan = $1.to_i
#           unless vlan == 1 or vlan == 1002 or vlan == 1003 or vlan == 1004 or vlan == 1005
            @vlanOptions << ["#{vlan} - #{name}", vlan]
#           end
        end
      end
    end
  end

  def update_vlan
    unless session[:user_level] == 0
      flash[:error] = "Access denied. Update not permitted."
    else
      @port = Port.find(params[:id])
      temp = @port.snmpget('vmVlan')
      if temp == SNMP::NoSuchInstance
        flash[:error] = "This port is a trunk. You can not assign a vlan to it."
      else
        @port.vlan = params[:port][:vlan].to_i
        if @port.snmpset('vmVlan', @port.vlan).nil?
          flash[:error] = $snmpError
        else
          @port.save
          flash[:notice] = "Port reconfigured"
        end
      end
    end
    redirect_to session[:return_to]
  end

  def destroy
    unless session[:user_level] == 0
      flash[:error] = "Access denied. Update not permitted."
    else
      @port = Port.find(params[:id])
      flash[:notice] = ''
      # find links that this port is a part of
      link = Link.where(["port_b_id = ? or port_a_id = ?", @port.id, @port.id])
      if not link.nil?
        link.each { |l| l.destroy }
        flash[:notice] += "Links involving #{@port.ifName} removed<br>\n"
      end
      if @port.destroy
        flash[:notice] += "Port removed<br>\n"
      end
    end
    unless session[:return_to].empty?
      redirect_to session[:return_to]
    else
      redirect_to :action => 'index'
    end
  end

  def delete_nonexistent
    unless session[:user_level] == 0
      flash[:error] = "Access denied. Insufficient privileges."
    else
      ifList = Array.new
      if params[:id].nil?
        flash[:error] = 'No node specified.'
      else
        flash[:notice] = flash[:error] = ''
        dev = Node.find params[:id]
        if dev.commStr == '**UNKNOWN**'
          flash[:error] += "This device does not have a valid snmp pw<br>\n"
        else
          dev.snmpwalk('IF-MIB::ifName').each do |key,val|
            ifList << val.to_s
          end
          dev.ports.find( :all ).each do |p|
            unless ifList.include?(p.ifName)
              # First destroy the links and reverse links
              link = Link.where(["port_a_id = ? or port_b_id = ",p.id,p.id])
              if not link.nil?
                link.each { |l| l.destroy }
                flash[:notice] += "Links involving #{p.ifName} removed.<br>\n"
              end
              # then destroy the port record
              if p.destroy
                flash[:notice] += "#{p.ifName} removed<br>\n"
              else
                flash[:error] += "#{p.ifName} could not be removed<br>\n"
              end
            end
          end
        end
      end
    end
    unless session[:return_to].empty?
      redirect_to session[:return_to]
    else
      redirect_to :action => 'index'
    end
  end

  # Detect ports and populate (or update) records with ifName, ifIndex, and vlan data
  def detect
    if params[:id].nil?
      flash[:error] = "No node specified."
    else
      flash[:notice] = ''
      flash[:error] = ''
      dev = Node.find params[:id]
      if dev.commStr == '**UNKNOWN**'
        flash[:error] += "This node does not have a valid snmp community string"
      else
        vlanlist = dev.snmpwalk('vmVlan')
        descList = dev.snmpwalk('ifAlias')
        resp = dev.snmpwalk('ifName')
        resp.each do |key,val|
          ifName = val.to_s
          ifIndex = (/\.(\d+)$/.match(key))[1].to_i
          if vlanlist.has_key?("CISCO-VLAN-MEMBERSHIP-MIB::vmVlan.#{ifIndex}")
            vlan = vlanlist["CISCO-VLAN-MEMBERSHIP-MIB::vmVlan.#{ifIndex}"].to_s
          else
            vlan = 0
          end
          ifAlias = descList["IF-MIB::ifAlias.#{ifIndex}"]
          port = Port.where(["node_id=? and ifName=?",dev.id,ifName]).first
          if port.nil?
            port = Port.create(:ifName => ifName, :node_id => dev.id, :ifIndex => ifIndex, :vlan => vlan, :comment => ifAlias)
          else
            if port.comment.nil? or port.comment.empty? or port.comment == '-'
              port.update_attributes(:ifIndex => ifIndex, :vlan => vlan, :comment => ifAlias)
            else
              port.update_attributes(:ifIndex => ifIndex, :vlan => vlan)
            end
          end
        end
      end
    end
    unless session[:return_to].empty?
      redirect_to session[:return_to]
    else
      redirect_to :action => 'index'
    end
  end

  # Retrieve some stats from a specific port: Op and Admin status, octet in and out stats,
  # error stats and bridge forwarding table entries
  def stats
    if params[:id].nil?
      flash[:error] = "No node specified."
    else
      @port = Port.find params[:id]
      macs = String.new
      @portStatus = Hash.new
      n = @port.node
      ifIndex = @port.ifIndex
      vlan = @port.snmpget('vmVlan')
      if vlan != SNMP::NoSuchInstance
        vList = [vlan.to_s]
        @port[:vlan] = vlan.to_s
      else
        vList = n.vlans.keys
        @port[:vlan] = 0
      end
      @port.save
      @portStatus[:admStatus] = @port.snmpget('IF-MIB::ifAdminStatus').to_i
      @portStatus[:oprStatus] = @port.snmpget('IF-MIB::ifOperStatus').to_i
            
      if @portStatus[:oprStatus] == 1
        pagpGroupIfIndex = n.snmpwalk('pagpGroupIfIndex')
        ifTypeList = n.snmpwalk('RFC1213-MIB::ifType')
        vList.each do |v|
          vpw = "#{n.commStr}@#{v}"
          basePortIndexList = n.snmpwalk('dot1dBasePortIfIndex',vpw)
          resp = n.snmpwalk('dot1dTpFdbPort',vpw)
          unless resp.nil?
            resp.each do |key,val|
              index = basePortIndexList["BRIDGE-MIB::dot1dBasePortIfIndex.#{val}"].to_i
              if ifTypeList["RFC1213-MIB::ifType.#{index}"].to_i == 53
                pagpGroupIfIndex.each do |key2,val2|
                  if val2.to_i == index
                    /\.(\d+)$/.match(key2)
                    index = $1.to_i
                  end
                end
              end
              if index == ifIndex
                /(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)$/.match(key)
                macAddr = sprintf('%02x:%02x:%02x:%02x:%02x:%02x',$1,$2,$3,$4,$5,$6)
                macs += v + ' - ' + macAddr + '<br>'
              end
            end
          end
        end
      end
      @portStatus[:inOctets] = @port.snmpget('IF-MIB::ifInOctets').to_i
      @portStatus[:outOctets] = @port.snmpget('IF-MIB::ifOutOctets').to_i
      @portStatus[:inErrors] = @port.snmpget('IF-MIB::ifInErrors').to_i
      @portStatus[:outErrors] = @port.snmpget('IF-MIB::ifOutErrors').to_i
      @portStatus[:macAddrList] = macs
      @title = "#{n.sysName} #{@port.ifName} Status"
      @events = @port.events
    end
  end

  def toggle_admin
    if params[:id].nil?
      flash[:error] = "No node specified."
    else
      @port = Port.find params[:id]
      current_status = @port.node.snmpget("IF-MIB::ifAdminStatus.#{@port.ifIndex}")
      unless current_status.nil?
        new_status =  case current_status.to_i
                      when 1 then 2
                      when 2 then 1
                      else nil
                      end
      end
      @port.node.snmpset("IF-MIB::ifAdminStatus.#{@port.ifIndex}", new_status)
      unless $snmpError.nil?
        flash[:error] = $snmpError
      end
    end
    redirect_to :controller => 'events', :action => 'toggle', :id => @port.id, :new_status => new_status
#     redirect_to toggle_event_path(@port), :new_status => new_status
  end

  private
  
  def port_params
    params.require(:port).permit(:ifName, :node_id, :building_id, :vlan, :label, :comment, :ifIndex)
  end
end
