class HttpRouter
  class Path
    attr_reader :route, :param_names
    def initialize(route, path, param_names = [])
      @route, @path, @param_names, @dynamic = route, path, param_names, !param_names.empty?
      duplicate_param_names = param_names.dup.uniq!
      raise AmbiguousVariableException, "You have duplicate variable name present: #{duplicate_param_names.join(', ')}" if duplicate_param_names
      if path.respond_to?(:split)
        regex_parts = path.split(/([:\*][a-zA-Z0-9_]+)/)
        @path_validation_regex, code = '', ''
        regex_parts.each_with_index{ |part, index|
          new_part = case part[0]
          when ?:, ?*
            if index != 0 && regex_parts[index - 1][-1] == ?\\
              @path_validation_regex << Regexp.quote(part)
              code << part
            else
              @path_validation_regex << (route.matches_with[part[1, part.size].to_sym] || '.*?').to_s
              code << "\#{args.shift || (options && options.delete(:#{part[1, part.size]})) || raise(MissingParameterException, \"missing parameter :#{part[1, part.size]}\")}"
            end
          else
            @path_validation_regex << Regexp.quote(part)
            code << part
          end
          new_part
        }
        @path_validation_regex = Regexp.new("^#{@path_validation_regex}$")
        instance_eval "
        def raw_url(args,options)
          \"#{code}\"
        end
        ", __FILE__, __LINE__
      end
    end

    def hashify_params(params)
      @dynamic && params ? param_names.zip(params).inject({}) { |h, (k,v)| h[k] = v; h } : {}
    end

    def url(args, options)
      path = raw_url(args, options)
      raise InvalidRouteException if path !~ @path_validation_regex
      raise TooManyParametersException unless args.empty?
      uri_escape!(path)
      [path, options]
    end

    def original_path
      @path
    end

    private
    def raw_url(args, options)
      raise UngeneratableRouteException
    end

    def uri_escape!(s)
      s.to_s.gsub!(/([^:\/?\[\]\-_~\.!\$&'\(\)\*\+,;=@a-zA-Z0-9]+)/n) { "%#{$1.unpack('H2'*$1.size).join('%').upcase}" }
    end
  end
end