class SearchesController < ApplicationController

  before_filter :authenticate
#   in_place_edit_for :port, :label
#   in_place_edit_for :port, :comment

  def index
    @title = 'Search'
  end

  # Building and, optionally, label
  def by_building
    @title = "Search by Building"
    @building = Building.all.order('short_name')
  end

  def trial
    @port = Port.find params[:id]
  end

  def find_by_building
    @adminStatus = Hash.new
    @opStatus = Hash.new
    by_building = params[:by_building]
    where = "building_id = '#{by_building[:building_id].to_s}'"
    unless by_building[:label].nil?
      @search_string = "Search string: #{by_building[:label]}"
      tmpSearchStr = by_building[:label]
      where += " and label like "
      head = '%'
      tail = '%'
      if (tmpSearchStr =~ /^\^/)
        head = ''
      end
      if (tmpSearchStr =~ /\$$/)
        tail = ''
      end
      tmpSearchStr.tr!('*','%')
      tmpSearchStr.sub!(/^\^/,'')
      tmpSearchStr.sub!(/\$$/,'')
      where += "'" + head + "#{tmpSearchStr}" + tail + "'"
    end
    @port = Port.where(where).order('label')
    @port.each do |p|
      @adminStatus[p.id] = p.snmpget('IF-MIB::ifAdminStatus')
      @opStatus[p.id] = p.snmpget('IF-MIB::ifOperStatus')
    end
    @title = "Search Result for #{Building.find(by_building[:building_id]).long_name}"
    session[:return_to] = request.env['ORIGINAL_FULLPATH']
  end

  def by_switch
    @title = "Search by Switch"
    @node = Node.all.order('sysName')
  end

  def find_by_switch
    @adminStatus = Hash.new
    @opStatus = Hash.new
    by_switch = params[:by_switch]
    where = "node_id = '#{by_switch[:node_id].to_s}'"
    n = Node.find(by_switch[:node_id])
    adm = n.snmpwalk('IF-MIB::ifAdminStatus')
    op = n.snmpwalk('IF-MIB::ifOperStatus')
    unless by_switch[:ifName].nil?
      @search_string = "Search string: #{by_switch[:ifName]}"
      tmpSearchStr = by_switch[:ifName]
      where += " and ifName like "
      head = '%'
      tail = '%'
      if (tmpSearchStr =~ /^\^/)
        head = ''
      end
      if (tmpSearchStr =~ /\$$/)
        tail = ''
      end
      tmpSearchStr.tr!('*','%')
      tmpSearchStr.sub!(/^\^/,'')
      tmpSearchStr.sub!(/\$$/,'')
      where += "'" + head + "#{tmpSearchStr}" + tail + "'"
    end
    @port = Port.where(where).order('label')
    @port.each do |p|
      @adminStatus[p.id] = adm["IF-MIB::ifAdminStatus"+p.ifIndex.to_s].to_i
      @opStatus[p.id] = op["IF-MIB::ifOperStatus"+p.ifIndex.to_s].to_i
    end
    @title = "Result for #{Node.find(by_switch[:node_id]).sysName}"
    session[:return_to] = request.env['ORIGINAL_FULLPATH']
  end

  def by_vlan
    @title = "Search by Vlan Number"
  end

  def find_by_vlan
    adm = Hash.new
    op = Hash.new
    @adminStatus = Hash.new
    @opStatus = Hash.new
    @port = Port.where(["vlan = ?",params[:vlan]]).order('node_id,ifIndex')
    nodes = @port.collect {|p| p.node}.uniq
    nodes.each do |n|
      adm[n.id] = n.snmpwalk('IF-MIB::ifAdminStatus')
      op[n.id] = n.snmpwalk('IF-MIB::ifOperStatus')
    end
    @port.each do |p|
      @adminStatus[p.id] = adm[p.node_id]['IF-MIB::ifAdminStatus'+p.ifIndex.to_s].to_i
      @opStatus[p.id] = op[p.node_id]['IF-MIB::ifOperStatus'+p.ifIndex.to_s].to_i
    end
    @title = "Results for vlan "+params[:vlan]
    session[:return_to] = request.env['ORIGINAL_FULLPATH']
    render :template => 'searches/find_by_switch'
  end

  def platform
    @title = "Search for Switches by Type"
  end

  def find_by_platform
    @title = "Switches matching type #{params[:platform]}"
    @nodes = Node.where(["platform regexp ?", params[:platform]]).order('sysName').page(params[:page])
    session[:return_to] = request.env['ORIGINAL_FULLPATH']
    render :template => '/nodes/index'
  end
  
  def tracker
    # This just shows the form
    @title = "Track an IP or MAC address"
  end
  
  # This method does the actual tracking
  def find_ip_mac
    flash[:error] = ''
    flash[:notice] = ''
    @title = "Tracker Result"
    @search = params[:search]
    @target = {:ip_str => '', :mac_str => '', :ifIndex => 0}
    @nodeList = []
    seedrtr = nil
    net = nil
    beenThere = []
    
    routers = Node.where('(capability & 1) = 1 and commStr <> "**UNKNOWN**"')
    
    if not @search[:ip].empty?
      # If IP is not empty see if it's valid
      begin
        ip = NetAddr::CIDR.create(@search[:ip])
        # if it is valid then find the corresponding MAC address
        @target[:ip_str] = @search[:ip]
        if @search[:trust] == '1'
          a = Arpcache.where(["ip = ?", @target[:ip_str]]).first
          unless a.nil?
            @target[:mac_str] = a.mac
            @target[:ifIndex] = a.ifIndex
          end
        else
          routers.each do |rtr|
            rtr.get_arp.each do |arp|
              if arp[:ip] == @target[:ip_str]
                @target[:mac_str] = arp[:mac]
                @target[:ifIndex] = arp[:ifIndex]
                break
              end
            end
          end
        end
        if @target[:mac_str].empty?
          $log.info("Could not find MAC address for #{@target[:ip_str]}")
          flash[:error] = "Could not find MAC address for #{@target[:ip_str]}"
        end
      rescue
        # not valid, set it to nil
        ip = nil
        $log.info("#{@search[:ip]} is not a valid IP address.")
        flash[:error] = "#{@search[:ip]} is not a valid IP address."
      end
    end
    
    # if the entered IP is not valid then look at the entered MAC address
    if ip.nil? and not @search[:mac].empty?
      # no valid IP and entered MAC is not empty so see if it's valid
      mac = @search[:mac].gsub(/[^0-9a-fA-F]/,'')
      if mac =~ /^[0-9a-fA-F]{12,12}$/
        @target[:mac_str] = mac
        if @search[:trust] == '1'
          # got a mac address, find the ip
          a = Arpcache.where(["mac = ?", @target[:mac_str]]).first
          unless a.nil?
            @target[:ip_str] = a[:ip]
            @target[:ifIndex] = a[:ifIndex]
          end
        else
          routers.each do |rtr|
            rtr.get_arp.each do |arp|
              if arp[:mac] == @target[:mac_str]
                @target[:ip_str] = arp[:ip]
                @target[:ifIndex] = arp[:ifIndex]
                break
              end
            end
          end
        end
        if @target[:ip_str].empty?
          $log.info("Could not find an IP address for #{mac}")
          flash[:error] = "Could not find an IP address for #{mac}"
        end
      else
        $log.info("#{mac} is not a valid MAC address.")
        flash[:error] = "#{mac} is not a valid MAC address."
      end
    elsif (ip.nil? and @search[:mac].empty?)
      $log.info("No valid IP or MAC address entered.")
      flash[:error] = "No valid IP or MAC address entered"
    end
    
    if (not @target[:ip_str].empty? and not @target[:mac_str].empty?)
      # At this point both ip_str and mac_str should contain valid addresses. We need
      # both: the IP to figure out which router the network/vlan is directly connected to
      # and the MAC to figure out which switch port it's connected to
      
      $log.debug("Target: ip = #{@target[:ip_str]}, mac = #{@target[:mac_str]}, if = #{@target[:ifIndex]}, vlan = #{@target[:vlan]}")
      
      catch :findNet do
        routers.each do |rtr|
          sortedRoutes = rtr.get_routes.sort_by do |r|
            maskArr = r[:mask].split('.')
            binMask = maskArr[0].to_i*256**3 + maskArr[1].to_i*256**2 + maskArr[2].to_i*256 + maskArr[3].to_i
          end
          sortedRoutes.reverse!.each do |rt|
            if rt[:type] == 3 # 3 = local net
              net = NetAddr::CIDR.create("#{rt[:net]} #{rt[:mask]}")
              if net.contains?(@target[:ip_str])
                seedrtr = rtr
                throw :findNet
              end
            end
          end # sortedRoutes.each
        end # routers.each
        # if we get to this point then no directly connected net was found on any of the routers
        $log.info("No directly connected network found for #{@target[:ip_str]}")
        flash[:error] = "No directly connected network found for #{@target[:ip_str]}"
      end #catch
      
      unless seedrtr.nil?
        tmp = seedrtr.findPhysInt(@target) # returns [ifIndex, vlan]
        unless (tmp[0].nil? or tmp[1].nil?)
          @target[:vlan] = tmp[1]
          rtrIfIndex = tmp[0]
          seedPort = seedrtr.ports.where("ifIndex = #{rtrIfIndex}").first
          $log.debug("Target: ip = #{@target[:ip_str]}, mac = #{@target[:mac_str]}")
          $log.debug("Device: #{seedrtr.sysName}, interface " + seedPort.ifName)
          
          @nodeList.push({:node => seedrtr, :port => seedPort})
          neighbour = seedrtr.findNeighbour(rtrIfIndex)
          
          $log.debug("Neighbour found: #{neighbour.sysName}")
          
          while not neighbour.nil?
            unless neighbour.commStr == '**UNKNOWN**'
              port = neighbour.findCAM(@target)
              
              $log.debug("Target found on interface #{port.ifName} on #{neighbour.sysName}")
              
              @nodeList.push({:node => neighbour, :port => port})
              neighbour = neighbour.findNeighbour(port.ifIndex)
            else
              neighbour = nil
            end
          end # while not neighbour.nil?
        else # unless seedPort.nil?
          $log.info("#{@target[:mac_str]} does not appear on any port on #{seedrtr.sysName}")
          flash[:error] = "#{@target[:mac_str]} does not appear on any port on #{seedrtr.sysName}"
        end
      end
    else # unless seedrtr.nil?
      $log.info("#{@target[:ip_str]} (#{@target[:mac_str]}) not found on any router.")
      flash[:error] = "#{@target[:ip_str]} (#{@target[:mac_str]}) not found on any router."
    end
  end # def find_ip_mac
end
