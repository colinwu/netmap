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
    @building = Building.find :all, :order => 'short_name'
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
      @search_string = "Search string: <code>#{by_building[:label]}</code>"
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
    session[:return_to] = request.env['QUERY_STRING']
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
      @search_string = "Search string: <code>#{by_switch[:ifName]}</code>"
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
    @port = Port.find.where(where).order('label')
    @port.each do |p|
      @adminStatus[p.id] = adm["IF-MIB::ifAdminStatus"+p.ifIndex.to_s].to_i
      @opStatus[p.id] = op["IF-MIB::ifOperStatus"+p.ifIndex.to_s].to_i
    end
    @title = "Result for #{Node.find(by_switch[:node_id]).sysName}"
    session[:return_to] = request.env['QUERY_STRING']
  end

  def by_vlan
    @title = "Search by Vlan Number"
  end

  def find_by_vlan
    adm = Hash.new
    op = Hash.new
    @adminStatus = Hash.new
    @opStatus = Hash.new
    @port = Port.find_all_by_vlan params[:vlan], :order => 'node_id,ifIndex'
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
    session[:return_to] = request.env['QUERY_STRING']
    render :template => 'searches/find_by_switch'
  end

  def platform
    @title = "Search for Switches by Type"
  end

  def find_by_platform
    @title = "Switches matching type #{params[:platform]}"
    @nodes = Node.where(["platform like '?'", '%#{params[:platform]}%']).order('sysName').page(params[:page])
    session[:return_to] = request.env['QUERY_STRING']
    render :template => '/nodes/index'
  end
end
