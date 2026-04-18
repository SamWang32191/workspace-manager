#!/usr/bin/env ruby
require 'yaml'

config_path = ARGV.shift or abort 'missing config path'
command = ARGV.shift or abort 'missing command'

config = YAML.load_file(config_path) || {}
profiles = config.fetch('profiles')

case command
when 'list-profiles'
  puts profiles.keys.sort
when 'profile-repos'
  profile = ARGV.shift or abort 'missing profile'
  puts profiles.fetch(profile)
when 'base-repo-dir'
  puts config.fetch('base_repo_dir')
when 'workspace-root'
  puts config.fetch('workspace_root')
else
  abort "unknown command: #{command}"
end
