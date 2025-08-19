namespace :swagger do
  desc 'Generate swagger.json (rswag) and convert to swagger.yaml'
  task generate_yaml: 'rswag:specs:swaggerize' do
    require 'json'
    require 'yaml'
    root = Rails.root.join('public', 'api-docs')
    Dir.glob(root.join('**', '*.json')).each do |json_path|
      data = JSON.parse(File.read(json_path))
      yaml_path = json_path.sub(/\.json\z/, '.yaml')
      File.write(yaml_path, data.to_yaml)
      puts "Wrote #{yaml_path}"
    end
  end
end
