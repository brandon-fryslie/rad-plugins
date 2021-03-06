#!/usr/bin/env ruby

require File.expand_path('../docker-support', __FILE__)

# This script cleans up exited containers and <none> images

def clean_exited_containers
  format_string = '{{.ID}}\|{{.Names}}\|{{.Status}}'
  containers = `docker ps -a --format #{format_string} | tail -n +1`.lines.map do |line|
    image = line.split('|')
    {
      :sha => image[0].strip,
      :name => image[1].strip,
      :status => image[2].strip
    }
  end

  exited_containers = containers.select { |image| image[:status] == 'Created' || /Exited/.match(image[:status]) }

  puts "Found #{exited_containers.length.to_s.yellow} exited container(s)"

  exited_containers.each do |image|
    puts "Removing container #{image[:name].cyan} with ID #{image[:sha].cyan}"
    `docker rm -fv #{image[:sha]}`
  end
end

def clean_none_images
  images = DockerSupport.get_untagged_images
  puts "Found #{images.length.to_s.yellow} <none> images"
  images.each do |image|
    DockerSupport.all_hosts do |docker_host|
      puts "Removing image #{image[:repo]} with tag #{image[:tag]} on #{docker_host}"
      DockerSupport.command docker_host, "docker rmi #{image[:sha]}"
    end
  end
end

clean_exited_containers
clean_none_images

puts "Done!".green
