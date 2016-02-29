class LinksController < ApplicationController
  before_filter :authenticate
  before_filter :authorize, :except => [:index]

  def index
    @link = Link.all
  end

  def new
    if params[:id].nil?
      @a = Node.all.order('sysName').collect {|n| [n.sysName, n.id]}
    else
      @a = Node.find(params[:id]).collect {|n| [n.sysName, n.id]}
    end
  end

  def create
    @link = Link.new
    @rlink = Link.new
    nodeA = params[:nodeA]
    nodeB = params[:nodeB]
    devA = Node.find(nodeA[:id])
    devB = Node.find(nodeB[:id])
    flash[:error] = ''
    flash[:notice] = ''
    portA = Port.where("node_id = '#{nodeA[:id]}' and ifName = '#{nodeA[:ifName]}'").first
    if (portA.nil? && devA.commStr != '**UNKNOWN**')
      # When creating a new port have to retrieve it's ifIndex (via snmp).
      # if no ifIndex then it's not a valid port spec.
      portAok = false
      response = devA.snmpwalk('ifName')
      if response.nil?
        flash[:error] += "No result from #{devA.sysName}"
      else
        response.each do |key, val|
          if x[:val] =~ /#{nodeA[:ifName]}/i
            oid = $mib.oid('ifName').to_s
            /#{oid}\.(.+)/.match(key)
            ifIndex = $1
            portA = Port.create(:node_id => nodeA[:id], :ifName => nodeA[:ifName], :ifIndex => ifIndex)
            flash[:notice] += "New port #{devA.sysName}:#{nodeA[:ifName]} added<br />"
            portAok = true
            break
          end
        end
      end
      unless portAok
        flash[:error] += "Port #{nodeA[:ifName]} does not exist on #{devA.sysName}<br \>"
      end
    elsif devA.commStr == '**UNKNOWN**'
      portA = Port.create(:node_id => nodeA[:id], :ifName => nodeA[:ifName])
      flash[:notice] += "New port #{devA.sysName}:#{nodeA[:ifName]} added<br />"
    end

    portB = Port.where("node_id = '#{nodeB[:id]}' and ifName = '#{nodeB[:ifName]}'").first
    if (portB.nil? && devB.commStr != '**UNKNWON**')
      # When creating a new port have to retrieve it's ifIndex (via snmp).
      # if no ifIndex then it's not a valid port spec.
      portBok = false
      response = devB.snmpwalk('ifName')
      if response.nil?
        flash[:error] += "No result from #{devB.sysName}"
      else
        response.each do |key,val|
          if x[:val] =~ /#{nodeB[:ifName]}/i
            oid = $mib.oid('ifName').to_s
            /#{oid}\.(.+)/.match(key)
            ifIndex = $1
            portB = Port.create(:node_id => nodeB[:id], :ifName => nodeB[:ifName], :ifIndex => ifIndex)
            flash[:notice] += "New port #{devB.sysName}:#{nodeB[:ifName]} added<br />"
            portBok = true
            break
          end
        end
      end
      unless portBok
        flash[:error] += "Port #{nodeB[:ifName]} does not exist on #{devB.sysName}<br \>"
      end
    elsif devA.commStr == '**UNKNOWN**'
      portA = Port.create(:node_id => nodeA[:id], :ifName => nodeA[:ifName])
      flash[:notice] += "New port #{devA.sysName}:#{nodeA[:ifName]} added<br />"
    end

    if flash[:error].empty?
      @link.port_a_id = @rlink.port_b_id = portA.id
      @link.port_b_id = @rlink.port_a_id = portB.id
      msg = "Links between #{devA.sysName}:#{portA.ifName} and #{devB.sysName}:#{portB.ifName}"
      if @link.save
        flash[:notice] += "Link created (Port ids #{portA.id} and #{portB.id}<br />"
        msg += " created"
      else
        flash[:error] += "Could not create link<br />"
        msg += " forward link NOT created"
      end
      if @rlink.save
        msg += " and reverse link created"
        flash[:notice] += "Reverse link created<br />"
      else
        msg += " and reverse link NOT created"
        flash[:error] += "Couldn't create Reverse link<br />"
      end
      log(msg)
      unless session[:return_to].empty?
        redirect_to session[:return_to]
      else
        redirect_to :action => '/index'
      end
    else
      log("Links could not be created: #{flash[:error]}")
      render :action => 'new'
    end
  end

  def edit
    @link = Link.find(params[:id])
  end

  def update
    @link = Link.find(params[:id])
    reverse_link = Link.where("port_b_id = '#{@link.port_a_id}' and port_a_id = '#{@link.port_b_id}'").first
    ifName_a = params[:port_a]
    ifName_b = params[:port_b]
    devA = Node.find(params[:nodeA])
    devB = Node.find(params[:nodeB])
    msg = "update of link old:#{@link.port_a.node.sysName}:#{@link.port_a.ifName} <-> #{@link.port_b.node.sysName}:#{@link.port_b.ifName} to new:#{devA.sysName}:#{ifName_a} <-> #{devB.sysName}:#{ifName_b}"
      flash[:error] = ''
    flash[:notice] = ''
    port_a = Port.where("node_id = '#{params[:nodeA]}' and ifName = '#{ifName_a}'").first
    if port_a.nil?
      portAok = false
      response = devA.snmpwalk('ifName')
      if response.nil?
        flash[:error] += "No result from #{devA.sysName}"
        msg += " failed. No SNMP response from #{devA.sysName}."
      else
        response.each do |key,val|
          if val.to_s =~ /#{ifName_a}/i
            oid = $mib.oid('ifName').to_s
            /#{oid}\.(.+)/.match(key)
            ifIndex = $1
            port_a = Port.create(:node_id => params[:nodeA], :ifName => ifName_a, :ifIndex => ifIndex)
            portAok = true
            break
          end
        end
      end
      unless portAok
        flash[:error] += "Port #{ifName_a} does not exist on #{devA.sysName}<br />"
        msg += " failed. Port #{ifName_a} does not exist on #{devA.sysName}"
      end
    end

    port_b = Port.where("node_id = '#{params[:nodeB]}' and ifName = '#{ifName_b}'").first
    if port_b.nil?
      portBok = false
      response = devB.snmpwalk('ifName')
      if response.nil?
        flash[:error] += "No result from #{devB.sysName}"
        msg += " failed. No SNMP response from #{devB.sysName}"
      else
        response.each do |key, val|
          if val.to_s =~ /#{ifName_b}/i
            oid = $mib.oid('ifName').to_s
            /#{oid}\.(.+)/.match(key)
            ifIndex = $1
            port_b = Port.create(:node_id => params[:nodeB], :ifName => ifName_b, :ifIndex => ifIndex)
            portBok = true
            break
          end
        end
      end
      unless portBok
        flash[:error] += "Port #{ifName_b} does not exist on #{devB.sysName}<br />"
        msg += " failed. Port #{ifName_b} does not exist on #{devB.sysName}"
      end
    end
    if flash[:error].empty?
      check_link = Link.where("(port_a_id = '#{port_a.id}' and port_b_id = '#{port_b.id}') or (port_a_id = '#{port_b.id}' and port_b_id = '#{port_a.id}')").first
      if check_link.nil?
        @link.port_a_id = port_a.id
        @link.port_b_id = port_b.id
        @link.save
        reverse_link.port_a_id = port_b.id
        reverse_link.port_b_id = port_a.id
        reverse_link.save
        msg += " succeeded"
        log(msg)
        unless session[:return_to].empty?
          redirect_to session[:return_to]
        else
          redirect_to :controller => 'node'
        end
      else
        flash[:warning] = "New link already exists, change not saved."
        msg += " failed. New link already exists, change not saved."
        log(msg)
        render :action => 'edit'
      end
    else
      log(msg)
      render :action => 'edit'
    end
  end

  def destroy
    link = Link.find params[:id]
    rlink = Link.where("port_a_id = '#{link.port_b_id}' and port_b_id = '#{link.port_a_id}'").first
    if link.destroy
      flash[:notice] = "Link deleted"
      log("Link #{link.port_a.node.sysName}:#{link.port_a.ifName} <-> #{link.port_b.node.sysName}:#{link.port_b.ifName} deleted")
    end
    if !rlink.nil? and rlink.destroy
      flash[:notice] += "Reverse link deleted"
    end
    redirect_to session[:return_to]
  end

  def detect
    remoteIP = Hash.new
    remotePort = Hash.new
    localPort = Hash.new
    remoteCap = Hash.new
    idList = Array.new
    pwlist = ['mac-snmp', 'fhsr22439', 'public', '**UNKNOWN**']

#     byebug
    
    if params[:id].nil?
      flash[:error] = "No node specified."
    else
      flash[:notice] = ''
      flash[:error] = ''
      devA = Node.find(params[:id])
      if devA.commStr == '**UNKNOWN**'
        flash[:error] = 'This device does not have a valid SNMP pw'
      else
        # Retrieve neighbours' IP addresses
        response = devA.snmpwalk('cdpCacheAddress')
        if response.nil?
          flash[:error] += "No result from #{devA.sysName} for 'cdpCacheAddress'<br>"
        else
          response.each do |key,val|
            /cdpCacheAddress\.(.+)/.match(key)
            id = $1
            ip = SNMP::IpAddress.new(val.to_s)
            remoteIP[id] = ip.to_s
          end
        end

        # Retrieve the name of neighbours' interfaces facing us
        response = devA.snmpwalk('cdpCacheDevicePort')
        if response.nil?
          flash[:error] += "No result from #{devA.sysName} for 'cdpCacheDevicePort'<br>"
        else
          response.each do|key,val|
            /cdpCacheDevicePort\.(.+)/.match(key)
            id= $1
            if val =~ /^FastEthernet/
              val.sub!(/stEthernet/,'')
            elsif val =~ /^GigabitEthernet/
              val.sub!(/gabitEthernet/,'')
            else
              val.to_s
            end
            remotePort[id] = val
            # Retrieve the corresponding local interface's ifName
            /^(\d+)\./.match(id)
            ifIndex = $1
            tmp = devA.snmpget("ifName.#{ifIndex}")
            localPort[id] = tmp.to_s
          end
        end

        # for each neighbour
        remoteIP.each_pair do |id,ip|
          # See if it exists in the database
          $log.debug("Find details for #{ip} (id = #{id})")
          devB = Node.find_by_ip ip
          if devB.nil?
            $log.debug("#{ip} not found in db")
            # neighbour doesn't exist in the db. Get its sysName & platform string
            resp = devA.snmpget("cdpCacheDeviceId.#{id}")
            if resp.to_s =~ /\((.+)\)/
              # The remote ID is of the form 'XXXXX(HOSTNAME)'
              r_sysName = $1
            elsif resp.to_s =~ /^([^.]+)/
              # just a text string (not an IP address)
              r_sysName = $1
            end
            $log.debug("#{devA.sysName} thinks it is #{r_sysName}")
            # Now check if a record with the sysName exists
            devB = Node.find_by_sysName r_sysName
            if devB.nil?
              $log.debug("#{r_sysName} not found in db")
              devB = Node.new(:sysName => r_sysName, :ip => ip)
              resp = devA.snmpget("cdpCachePlatform.#{id}")
              $log.debug("#{devA.sysName} thinks #{ip} is a #{resp.to_s}")
              devB.platform = resp.to_s
              # remote device capabilities
              resp = devA.snmpget("cdpCacheCapabilities.#{id}")
              # Only the least significant 8 bits are used in the Capabilities field
              $log.debug("devB cap: " + resp.unpack("c#{resp.length}")[3].to_s)
              devB.capability = resp.unpack("c#{resp.length}")[3]
              # See if the community string is one of the known ones
              $log.debug("Looking for read community string.")
              pwlist.each do |pw|
                devB.commStr = pw
                break if pw == '**UNKNWON**'
                resp = devB.snmpget('RFC1213-MIB::sysName.0').to_s #sysName
                $log.debug("#{ip} is called #{resp.to_s}")
                break unless resp.nil? or resp.empty?
              end
              if devB.commStr != '**UNKNOWN**'
                devB.get_ifindex
              end
              if devB.save
                log("Neighbour device #{devB.sysName} has been added to the database.")
                flash[:notice] += "#{devB.sysName} has been added to the database."
              else
                log("#{devB.sysName} could not be saved to the database.")
                redirect_to :back
              end
            else
              resp = devA.snmpget("cdpCacheCapabilities.#{id}")
              $log.debug("devB cap: " + resp.unpack("c#{resp.length}")[3].to_s)
              # Only the least significant 8 bits are used in the Capabilities field
              devB.capability = resp.unpack("c#{resp.length}")[3]
              devB.save
            end
          end

          # See if the port is already in the database
          portB = Port.where(["node_id = ? and ifName = ?", devB.id, remotePort[id]]).first
          if portB.nil?
            portB = Port.create(:ifName => remotePort[id], :node_id => devB.id)
            flash[:notice] += "Port #{devB.sysName} #{remotePort[id]} has been added to the database.<br>"
          end
          portB.comment = "link to #{devA.sysName}"
          portB.label = '-'
          portB.save

          #create the link record if it doesn't exist already
          portA = Port.where(["node_id = ? and ifName = ?", devA.id, localPort[id]]).first
          if portA.nil?
            portA = Port.create(:ifName => localPort[id], :node_id => devA.id)
            flash[:notice] += "Port #{devA.sysName} #{portA.ifName} has been added to the database.<br>"
          end
          portA.comment = "link to #{devB.sysName}"
          portA.label = '-'
          portA.save

          link = Link.where("port_a_id = '#{portA.id}' and port_b_id = '#{portB.id}'").first
          if link.nil?
            Link.create(:port_a_id => portA.id, :port_b_id => portB.id)
          end
          link = Link.where("port_a_id = '#{portB.id}' and port_b_id = '#{portA.id}'").first
          if link.nil?
            Link.create(:port_a_id => portB.id, :port_b_id => portA.id)
          end
        end
      end
    end
    log(flash[:notice])
    redirect_to show_links_node_path(devA)
  end # of detect

end
