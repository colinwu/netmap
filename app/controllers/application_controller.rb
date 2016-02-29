# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  protect_from_forgery
  helper :all
  
  $log = Logger.new('log/netmap.log', shift_age = 'monthly')

  require 'snmp'
  $module_list = ['BRIDGE-MIB', 'CISCO-CDP-MIB', 'CISCO-PAGP-MIB', 'CISCO-VLAN-MEMBERSHIP-MIB', 'IF-MIB', 'RFC1213-MIB', 'CISCO-VTP-MIB']
  
  $mib = SNMP::MIB.new
  $module_list.each do |m|
    $mib.load_module(m)
  end

  $roles = [['netgroup',0],['regular user',1]]

  def conditions_by_like(value, *columns)
    columns = self.user_columns if columns.size == 0
    columns = columns[0] if columns[0].kind_of?(Array)
    conditions = columns.map {|c|
      c = c.name if c.kind_of?(ActiveRecord::ConnectionAdapters::Column("'#{c}' like ") + ActiveRecord::Base.connection.quote("%#{value}%"))
    }.join(" OR ")
  end

  def log(msg)
    me = User.find(session[:user_id])
    $log.info("[#{me.name}] #{msg}")
  end

  private

  def authenticate
    unless User.find_by_id(session[:user_id])
      session[:return_to] = request.env['QUERY_STRING']
      redirect_to logins_path
    end
  end

  def authorize
    if session[:user_level] != 0
      redirect_to :controller => 'logins', :action => 'no_priv'
    end
  end
end
