# A very simple demonstration of writing a REST server
# for Simple RPC clients that takes requests over HTTP
# and returns results as JSON structures.

# A rewrite of https://github.com/thinkfr/restmco/ that provides a much cleaner API

# Copyright (C) 2012 Omry Yadan (omry at yadan dot net)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'sinatra'
require 'mcollective'
require 'json'
require 'cgi'

include MCollective::RPC
set :port, 4566

#uid = Etc.getpwnam("nobody").uid
#Process::Sys.setuid(uid)

# Examples :
# get bash package status for two machines with the web class
# The following filters/options are supported:
# -Ffact=value : fact filter
# -Cclass_name : class filter
# -Ihostname   : Identity filter
# -Aagent_name : Agent filter
# -L<n>        : Limit the number of targets to <n>
#
# Examples:
#         http://localhost:4567/mco/find
# Finds all nodes
#
#   htp://localhost:4567/mco/find?-Cweb
# Finds all nodes with the web class
#
#   http://localhost:4567/mco/filemgr/status?file=/etc/hosts&-Ihostname
# Returs the file info for /etc/hosts on the node with the identity 'hostname'
#
# Results are in JSON format

get '/' do
  "MCO Rest server\n"
end

helpers do
  def request_params_repeats
    params = {}
    request.query_string.split('&').each do |pair|
      kv = CGI.unescape(pair).split('=')
      params.merge!({kv[0]=> kv.length > 1 ? kv[1] : nil }) {|key, o, n| o.is_a?(Array) ? o << n : [o,n]}
    end
    params
  end

  def process_args(mc)
    rparams = request_params_repeats
    arguments = {}
    rparams.each_key do |key|
      value = rparams[key]
      if key.match("^-L")
        puts "Applying limit targets -L #{value}"
        mc.limit_targets=key[2,key.length].to_i
      elsif key.match("^-F")
        filter = "#{key[2,key.length]}=#{value}"
        puts "Applying fact filter -F #{filter}"
        mc.fact_filter "#{filter}"
      elsif key.match("^-C")
        filter = "#{key[2,key.length]}"
        puts "Applying class filter -C #{filter}"
        mc.class_filter "#{filter}"
      elsif key.match("^-A")
        filter = "#{key[2,key.length]}"
        puts "Applying agent filter -A #{filter}"
        mc.agent_filter "#{filter}"
      elsif key.match("^-I")
        filter = "#{key[2,key.length]}"
        puts "Applying identity filter -I #{filter}"
        mc.identity_filter "#{filter}"
      else
        arguments[key.to_sym] = value
      end
    end
    arguments
  end
end

get '/mco/find' do
  content_type :json
  mc = rpcclient('rpcutil')
  arguments = process_args(mc)
  JSON.dump(mc.discover())
end

get '/mco/:agent/:action' do
  content_type :json
  agent = params[:agent]
  action = params[:action]
  mc = rpcclient(agent)
  arguments = process_args(mc)
  JSON.dump(mc.send(action,arguments).map{|r| r.results})
end
