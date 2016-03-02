class RecyclesController < ApplicationController
  before_filter :authenticate
  require 'resolv'

  def index
    @title = "Find IP Addresses to Recycle"
    @candidates = Array.new()
    @order = params[:order]
    @numUsed = 0;

    unless params[:net].nil?
      @net = params[:net]
      (1..254).each do |host|
        temp = Hash.new()
        ip = "#{@net}.#{host}"
        hostnames = Array.new()
        begin
          h = Resolv.getname(ip)
        rescue
          #      puts "Resolver error: #{$!}"
        end
        if not h.nil?
          @numUsed = @numUsed + 1
          hostnames << h
          recent = Arpcache.where("updated_on > date_sub(now(), INTERVAL 1 YEAR) and ip = ?", ip).first
          if recent.nil? #not been seen in the past year
            candidate = Arpcache.where("updated_on < date_sub(now(), INTERVAL 1 YEAR) and ip = ?",ip).order('updated_on').first
            if candidate.nil?  # not in arpcache table
              temp[:ip] = ip
              temp[:mac] = "N/A"
              temp[:name] = hostnames[0]
              temp[:updated_on] = "Before 2008"
            else
              temp[:ip] = ip
              temp[:mac] = candidate.mac
              temp[:name] = hostnames[0]
              temp[:updated_on] = candidate.updated_on
            end
            @candidates << temp
          end
        end
      end
      puts @candidates.inspect
    end
  end

  def show
  end

end
