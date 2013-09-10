json = HTTP::MimeType.new 'application/json', :json

json.parse_with do |obj|
  if defined?(JSON) and JSON.respond_to? :parse
    JSON.parse(obj)
  else
    obj
  end
end

json.emit_with do |obj|
  if obj.is_a? String
    obj
  elsif obj.respond_to? :to_json
    obj.to_json
  else
    obj
  end
end
