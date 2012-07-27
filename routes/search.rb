module Optopus
  class App

    def elasticsearch_escape(string)
      if string.include?('*')
        string.gsub(/[\{\}\[\]\(\):]/) { |s| "\\#{s}" }
      else
        "\"#{string}\""
      end
    end

    def make_valid_query_string(string)
      query_string = Array.new
      string.split.each do |query_part|
        if query_part.match(/(hostname|switch|macaddress|productname|facts\..*):(.*)/)
          query_string << "#{$1}:#{elasticsearch_escape($2)}"
        else
          query_string << elasticsearch_escape(query_part)
        end
      end
      query_string.join(' ')
    end

    get '/search' do
      validate_param_presence 'query'
      query_string = make_valid_query_string(params['query'])
      node_results = Optopus::Node.search(:size => 2000) do
        query { string query_string, :default_operator => 'AND' }
      end
      appliance_results = Optopus::Appliance.search(:size => 2000) do
        query { string query_string, :default_operator => 'AND' }
      end
      @search_query = params['query']
      @results = Array.new
      @results << { :type => :node, :results => node_results.sort { |a,b| a.hostname <=> b.hostname } }
      @results << { :type => :appliance, :results => appliance_results }
      erb :search_results
    end
  end
end
