class ArpcachesController < ApplicationController
  before_filter :authenticate
  before_filter :authorize, :except => [:index, :nopage]

  def index
    @title = "ARP Cache Entries"
    @order = params[:order]
    if params[:ip].nil? && params[:mac].nil? && params[:router].nil?
      where = 1
    else
      unless params[:router].nil?
        @s_router = params[:router]
        where = "router like '#{@s_router}%'"
      end
      unless params[:mac].nil?
        @s_mac = params[:mac]
        @s_mac.tr!('^0-9a-fA-F','')
        where = "mac like '%#{@s_mac}%'"
      end
      unless params[:ip].nil?
        @s_ip = params[:ip]
        where = "ip like '#{@s_ip}%'"
      end
    end
    @arplist = Arpcache.where(where).select('*,INET_ATON(ip) AS bin_ip').order((params[:order].nil? || params[:order] =~ /^bin_ip/i) ? 'updated_at DESC,bin_ip' : params[:order]).paginate(:page => params[:page])
  end

  def nopage
    @title = "ARP Cache Entries"
    @order = params[:order]
    if params[:ip].nil? && params[:mac].nil? && params[:router].nil?
      where = 1
    else
      unless params[:router].nil?
        @s_router = params[:router]
        where = "router like '#{@s_router}%'"
      end
      unless params[:mac].nil?
        @s_mac = params[:mac]
        where = "mac like '%#{@s_mac}%'"
      end
      unless params[:ip].nil?
        @s_ip = params[:ip]
        where = "ip like '#{@s_ip}%'"
      end
    end
    @arplist = Arpcache.where(where).select('*,INET_ATON(ip) AS bin_ip').order((params[:order].nil? || params[:order] =~ /ip/i) ? 'bin_ip' : params[:order])
  end

  def destroy
    arp = Arpcache.find(params[:id])
    Arpcache.destroy(params[:id])
    me = User.find(session[:user_id])
    log("#{arp.mac}/#{arp.ip} removed")
    if session[:return_to].nil?
      redirect_to :action => 'index'
    else
      redirect_to session[:return_to]
    end
  end
end
